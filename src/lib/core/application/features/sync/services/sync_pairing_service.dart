import 'dart:async';
import 'dart:typed_data';

import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_wire.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

const String _component = 'SyncPairingService';

/// Longest wait for the user to compare codes or confirm a group switch.
const Duration pairingConfirmationTimeout = Duration(minutes: 2);

/// One pairing in progress: the transport to close on cancel and the
/// decisions the user still owes.
class _PairingRun {
  final SyncPairingRole role;
  ISyncTransport? transport;
  final Completer<bool> codeDecision = Completer<bool>();
  final Completer<bool> groupDecision = Completer<bool>();
  bool cancelled = false;

  _PairingRun(this.role);

  void cancel() {
    cancelled = true;
    if (!codeDecision.isCompleted) codeDecision.complete(false);
    if (!groupDecision.isCompleted) groupDecision.complete(false);
    unawaited(transport?.close());
  }
}

/// The commit-reveal state machine of either role behind one interface (the
/// package's two classes share a private base).
class _SasDriver {
  final SasState Function() state;
  final String? Function() code;
  final bool Function() isConfirmed;
  final bool Function() isAborted;
  final List<SasMessage> Function(SasMessage message) receive;
  final List<SasMessage> Function() confirm;
  final List<SasMessage> Function() reject;

  /// The first messages the role sends on its own (the responder's commit).
  final List<SasMessage> Function() start;

  _SasDriver.responder(SasResponder sas)
      : state = (() => sas.state),
        code = (() => sas.code),
        isConfirmed = (() => sas.isConfirmed),
        isAborted = (() => sas.isAborted),
        receive = sas.receive,
        confirm = sas.confirm,
        reject = sas.reject,
        start = sas.start;

  _SasDriver.initiator(SasInitiator sas)
      : state = (() => sas.state),
        code = (() => sas.code),
        isConfirmed = (() => sas.isConfirmed),
        isAborted = (() => sas.isAborted),
        receive = sas.receive,
        confirm = sas.confirm,
        reject = sas.reject,
        start = (() => const []);
}

/// Pairing of this device with another (FR-024, FR-025, D7): the inviter side
/// answers on the LAN server, the joiner side connects. QR pairing uses
/// `Noise_XXpsk3` keyed by a one-time token; LAN-scan and manual-address
/// pairing use `Noise_XX` and a commit-reveal code both users compare. Both
/// end in the same exchange: the inviter hands over the group keys, the joiner
/// returns its origin registration.
///
/// One pairing runs at a time. [status] and [statusStream] report its state;
/// the commands return the next state that needs the user or ends the pairing.
class SyncPairingService {
  final SyncMembershipService _membershipService;
  final ISyncPeerConnector _connector;
  final ISyncPeerStatusStore _statusStore;
  final INetworkInterfaceService _networkInterfaces;
  final ISyncUpgradeService _upgradeService;
  final String _platform;
  final int _port;
  final DateTime Function() _now;
  final Duration _confirmationTimeout;
  final StreamController<SyncPairingStatus> _statusController = StreamController<SyncPairingStatus>.broadcast();

  SyncPairingStatus _status = SyncPairingStatus.idle;
  PairingToken? _token;
  _PairingRun? _run;

  SyncPairingService({
    required SyncMembershipService membershipService,
    required ISyncPeerConnector connector,
    required ISyncPeerStatusStore statusStore,
    required INetworkInterfaceService networkInterfaces,
    required ISyncUpgradeService upgradeService,
    required String platform,
    int port = syncLanPort,
    DateTime Function()? now,
    Duration confirmationTimeout = pairingConfirmationTimeout,
  })  : _membershipService = membershipService,
        _connector = connector,
        _statusStore = statusStore,
        _networkInterfaces = networkInterfaces,
        _upgradeService = upgradeService,
        _platform = platform,
        _port = port,
        _now = now ?? DateTime.now,
        _confirmationTimeout = confirmationTimeout;

  SyncPairingStatus get status => _status;

  Stream<SyncPairingStatus> get statusStream => _statusController.stream;

  // -- commands --------------------------------------------------------------------------

  /// Shows a new invitation: a 128-bit token valid for 5 minutes and one
  /// successful use. A previous invitation stops working.
  Future<PairingInvitation> createInvitation() async {
    await _requireReady();
    _token?.destroy();
    final token = PairingToken.generate(now: _now());
    _token = token;
    final identity = _membershipService.membership.identity;
    final invitation = PairingInvitation(
      memberId: identity.memberId,
      addresses: await _networkInterfaces.getPreferredIPAddresses(),
      port: _port,
      fingerprint: x25519Fingerprint(identity.x25519Pub),
      token: token.exportForQr(),
      expiresAt: token.expiresAt,
    );
    _emit(const SyncPairingStatus(phase: SyncPairingPhase.waitingForScan, role: SyncPairingRole.inviter));
    return invitation;
  }

  /// Joiner: pairs with the device that shows [invitation].
  Future<SyncPairingStatus> pairFromInvitation(PairingInvitation invitation) =>
      _begin(SyncPairingRole.joiner, (run) => _joinWithInvitation(run, invitation));

  /// Joiner: pairs with the device at [address] after both users compared a
  /// code.
  Future<SyncPairingStatus> startPairingWithAddress(String address, {int? port}) =>
      _begin(SyncPairingRole.joiner, (run) => _joinWithCode(run, address, port ?? _port));

  /// Both roles: the user saw the same code on both screens.
  Future<SyncPairingStatus> confirmCode() => _decide((run) => run.codeDecision.complete(true));

  /// Joiner: the user agrees to leave the current group.
  Future<SyncPairingStatus> confirmGroupSwitch() => _decide((run) => run.groupDecision.complete(true));

  /// Ends the pairing in progress and stops showing the invitation.
  void cancel() {
    final run = _run;
    if (run != null) {
      run.cancel();
      return;
    }
    if (_token == null) return;
    _destroyToken();
    _emit(SyncPairingStatus.idle);
  }

  // -- inviter side (called by the LAN server) -------------------------------------------

  /// Answers one incoming pairing connection. Never throws; a failed
  /// connection leaves a failed [status] only after the peer passed
  /// authentication.
  Future<void> respond(ISyncTransport transport, String source) async {
    try {
      final mode = (await transport.receive().timeout(pairingStepTimeout)).firstOrNull;
      if (mode == pairingModeQr) return await _respondQr(transport, source);
      if (mode == pairingModeSas) return await _respondSas(transport, source);
    } on Object catch (error) {
      Logger.debug('pairing connection ended: ${error.runtimeType}', component: _component);
    }
  }

  Future<void> _respondQr(ISyncTransport transport, String source) async {
    final token = _token;
    final refusal = await _refusalStatus(token);
    if (refusal != pairingStatusOk) return transport.send(Uint8List.fromList([refusal]));
    await transport.send(Uint8List.fromList([pairingStatusOk]));
    final handshake = await token!.startResponderHandshake(staticKey: _staticKey, now: _now());
    if (handshake == null) return;
    final session = await _finishResponderHandshake(handshake, transport);
    if (session == null) return;
    if (token.consume(handshake, _now()) != PairingConsumeResult.consumed) return session.close();
    _destroyToken();
    await _runResponder(session, transport, source, withCode: false);
  }

  /// Code pairing is accepted only while an invitation is shown, which is
  /// the user opening the pairing screen on this device.
  Future<void> _respondSas(ISyncTransport transport, String source) async {
    final answer = await _sasStatus();
    await transport.send(Uint8List.fromList([answer]));
    if (answer != pairingStatusOk) return;
    final handshake = await NoiseHandshake.xx(initiator: false, staticKey: _staticKey, acceptRemoteStatic: (_) => true);
    final session = await _finishResponderHandshake(handshake, transport);
    if (session != null) await _runResponder(session, transport, source, withCode: true);
  }

  Future<int> _sasStatus() async {
    if (_run != null) return pairingStatusBusy;
    return _refusalStatus(_token);
  }

  Future<int> _refusalStatus(PairingToken? token) async {
    if (token == null || !token.isUsable(_now())) return pairingStatusExpiredOrUsed;
    return await _isUpgradeDone() ? pairingStatusOk : pairingStatusPreparing;
  }

  /// Reads message 1, writes message 2, reads message 3. A failed handshake
  /// (a wrong PSK among them) returns `null` and burns nothing.
  Future<NoiseSession?> _finishResponderHandshake(NoiseHandshake handshake, ISyncTransport transport) async {
    try {
      await handshake.readMessage(await transport.receive().timeout(pairingStepTimeout));
      await transport.send(await handshake.writeMessage());
      await handshake.readMessage(await transport.receive().timeout(pairingStepTimeout));
      return handshake.split();
    } on Object {
      handshake.close();
      return null;
    }
  }

  Future<void> _runResponder(NoiseSession session, ISyncTransport transport, String source,
      {required bool withCode}) async {
    final run = _PairingRun(SyncPairingRole.inviter)..transport = transport;
    if (_run != null) return session.close();
    _run = run;
    final channel = PairingChannel(transport, session);
    await _execute(run, () async {
      _emit(const SyncPairingStatus(phase: SyncPairingPhase.exchanging, role: SyncPairingRole.inviter));
      if (withCode) await _compareCodes(run, channel, _SasDriver.responder(SasResponder(channel.handshakeHash)));
      await _inviterExchange(run, channel, source);
    }, channel: channel);
  }

  Future<void> _inviterExchange(_PairingRun run, PairingChannel channel, String source) async {
    final own = _membershipService.membership;
    await channel.sendMap(typed('hello', {
      'member': own.memberId,
      'name': own.identity.name,
      'platform': _platform,
      'group': own.groupId?.hex,
    }));
    final join = await channel.receiveMap('join');
    final joiner = MemberEntry.decode(bytesOfHex(join['entry'] as String));
    _requireJoinerBoundToChannel(joiner, channel, own.memberId);
    _emit(SyncPairingStatus(
      phase: SyncPairingPhase.exchanging,
      role: run.role,
      peerName: joiner.name,
      peerMemberId: joiner.memberId,
    ));
    final handover = await _membershipService.prepareHandover(joiner);
    try {
      await channel.sendMap(encodeHandover(handover));
    } finally {
      handover.destroy();
    }
    final registration = decodeRegistration(await channel.receiveMap('registration'));
    if (!_sameBytes(registration.memberPub, joiner.ed25519Pub)) {
      throw const SyncPairingException(SyncPairingErrorCode.refused);
    }
    await _membershipService.completePairing(registration);
    await channel.sendMap(typed('done'));
    _destroyToken();
    await _rememberPeer(joiner.memberId, [source], join['platform'] as String?);
    _emit(SyncPairingStatus(
      phase: SyncPairingPhase.completed,
      role: run.role,
      peerName: joiner.name,
      peerMemberId: joiner.memberId,
    ));
  }

  void _requireJoinerBoundToChannel(MemberEntry joiner, PairingChannel channel, String ownMemberId) {
    final boundToChannel = _sameBytes(joiner.x25519Pub, channel.remoteStatic);
    if (!boundToChannel || joiner.memberId == ownMemberId) {
      throw const SyncPairingException(SyncPairingErrorCode.refused);
    }
  }

  // -- joiner side -------------------------------------------------------------------------

  Future<void> _joinWithInvitation(_PairingRun run, PairingInvitation invitation) async {
    final transport = await _connectAny(run, invitation.addresses, invitation.port);
    await _requireModeAccepted(transport, pairingModeQr);
    final handshake = await NoiseHandshake.xxPsk3(
      initiator: true,
      staticKey: _staticKey,
      psk: derivePairingPsk(invitation.token),
      expectedResponderFingerprint: invitation.fingerprint,
    );
    final session = await _runInitiatorHandshake(handshake, transport);
    await _joinerExchange(run, PairingChannel(transport, session), invitation.addresses);
  }

  Future<void> _joinWithCode(_PairingRun run, String address, int port) async {
    final transport = await _connectAny(run, [address], port);
    await _requireModeAccepted(transport, pairingModeSas);
    final handshake = await NoiseHandshake.xx(initiator: true, staticKey: _staticKey, acceptRemoteStatic: (_) => true);
    final channel = PairingChannel(transport, await _runInitiatorHandshake(handshake, transport));
    await _compareCodes(run, channel, _SasDriver.initiator(SasInitiator(channel.handshakeHash)));
    await _joinerExchange(run, channel, [address]);
  }

  Future<ISyncTransport> _connectAny(_PairingRun run, List<String> addresses, int port) async {
    for (final address in addresses) {
      try {
        final transport = await _connector.connect(address, port: port, forPairing: true);
        run.transport = transport;
        return transport;
      } on Object catch (error) {
        Logger.debug('pairing connect failed: ${error.runtimeType}', component: _component);
      }
    }
    throw const SyncPairingException(SyncPairingErrorCode.unreachable);
  }

  Future<void> _requireModeAccepted(ISyncTransport transport, int mode) async {
    await transport.send(Uint8List.fromList([mode]));
    final answer = (await transport.receive().timeout(pairingStepTimeout)).firstOrNull;
    switch (answer) {
      case pairingStatusOk:
        return;
      case pairingStatusExpiredOrUsed:
        throw const SyncPairingException(SyncPairingErrorCode.codeExpiredOrUsed);
      case pairingStatusPreparing:
        throw const SyncPairingException(SyncPairingErrorCode.preparing);
      default:
        throw const SyncPairingException(SyncPairingErrorCode.refused);
    }
  }

  Future<NoiseSession> _runInitiatorHandshake(NoiseHandshake handshake, ISyncTransport transport) async {
    try {
      await transport.send(await handshake.writeMessage());
      await handshake.readMessage(await transport.receive().timeout(pairingStepTimeout));
      await transport.send(await handshake.writeMessage());
      return handshake.split();
    } on Object {
      handshake.close();
      rethrow;
    }
  }

  Future<void> _joinerExchange(_PairingRun run, PairingChannel channel, List<String> addresses) async {
    final hello = await channel.receiveMap('hello');
    final peerMemberId = hello['member'] as String;
    final peerName = hello['name'] as String;
    final inviterGroup = hello['group'] == null ? null : GroupId.fromHex(hello['group'] as String);
    final needsSwitch = _membershipService.requiresGroupSwitchConfirmation(inviterGroup);
    _emit(SyncPairingStatus(
      phase: needsSwitch ? SyncPairingPhase.awaitingGroupSwitch : SyncPairingPhase.exchanging,
      role: run.role,
      peerName: peerName,
      peerMemberId: peerMemberId,
    ));
    if (needsSwitch) await _requireDecision(run.groupDecision, channel);
    final own = _membershipService.membership.identity;
    await channel
        .sendMap(typed('join', {'entry': hexOf(own.entry(addedBy: peerMemberId).encode()), 'platform': _platform}));
    final handover = decodeHandover(await channel.receiveMap('handover'));
    final registration = await _acceptHandover(handover, needsSwitch);
    await channel.sendMap(encodeRegistration(registration));
    await channel.receiveMap('done');
    await _rememberPeer(peerMemberId, addresses, hello['platform'] as String?);
    _emit(SyncPairingStatus(
      phase: SyncPairingPhase.completed,
      role: run.role,
      peerName: peerName,
      peerMemberId: peerMemberId,
    ));
  }

  Future<OriginRegistration> _acceptHandover(PairingHandover handover, bool confirmedGroupSwitch) async {
    try {
      return await _membershipService.acceptHandover(handover, confirmGroupSwitch: confirmedGroupSwitch);
    } finally {
      handover.destroy();
    }
  }

  // -- code comparison -------------------------------------------------------------------

  /// Drives the commit-reveal exchange until both screens can show the code,
  /// waits for the local user, then waits for the peer's confirmation.
  Future<void> _compareCodes(_PairingRun run, PairingChannel channel, _SasDriver sas) async {
    await _sendAll(channel, sas.start());
    while (sas.state() != SasState.comparing) {
      await _sendAll(channel, sas.receive(SasMessage.decode(await channel.receiveBytes())));
      _failWhenAborted(sas);
    }
    _emit(SyncPairingStatus(phase: SyncPairingPhase.comparingCodes, role: run.role, code: sas.code()));
    final accepted = await _awaitDecision(run.codeDecision);
    if (!accepted) {
      await _tellPeerQuietly(() => _sendAll(channel, sas.reject()));
      throw const SyncPairingException(SyncPairingErrorCode.cancelled);
    }
    await _sendAll(channel, sas.confirm());
    while (!sas.isConfirmed()) {
      await _sendAll(channel, sas.receive(SasMessage.decode(await channel.receiveBytes())));
      _failWhenAborted(sas);
    }
  }

  void _failWhenAborted(_SasDriver sas) {
    if (sas.isAborted()) throw const SyncPairingException(SyncPairingErrorCode.codesDiffer);
  }

  Future<void> _sendAll(PairingChannel channel, List<SasMessage> messages) async {
    for (final message in messages) {
      await channel.sendBytes(message.encode());
    }
  }

  Future<bool> _awaitDecision(Completer<bool> decision) =>
      decision.future.timeout(_confirmationTimeout, onTimeout: () => false);

  Future<void> _requireDecision(Completer<bool> decision, PairingChannel channel) async {
    if (await _awaitDecision(decision)) return;
    await _tellPeerQuietly(channel.sendAbort);
    throw const SyncPairingException(SyncPairingErrorCode.groupSwitchDeclined);
  }

  // -- run lifecycle ---------------------------------------------------------------------

  Future<SyncPairingStatus> _begin(SyncPairingRole role, Future<void> Function(_PairingRun run) body) async {
    await _requireReady();
    if (_run != null) throw const SyncPairingException(SyncPairingErrorCode.refused);
    final run = _PairingRun(role);
    _run = run;
    final settled = _nextSettledStatus();
    _emit(SyncPairingStatus(phase: SyncPairingPhase.connecting, role: role));
    unawaited(_execute(run, () => body(run)));
    return settled;
  }

  Future<SyncPairingStatus> _decide(void Function(_PairingRun run) decision) async {
    final run = _run;
    if (run == null) throw const SyncPairingException(SyncPairingErrorCode.noActivePairing);
    final settled = _nextSettledStatus();
    decision(run);
    return await settled;
  }

  /// Runs [body], reports its failure as a failed status and always frees the
  /// run.
  Future<void> _execute(_PairingRun run, Future<void> Function() body, {PairingChannel? channel}) async {
    try {
      await body();
    } on Object catch (error) {
      await _reportFailure(run, error, channel);
    } finally {
      _run = null;
      channel?.close();
      await run.transport?.close();
    }
  }

  Future<void> _reportFailure(_PairingRun run, Object error, PairingChannel? channel) async {
    final code = _errorCodeOf(error, run);
    Logger.debug('pairing failed: $code', component: _component);
    await _tellPeer(channel, code);
    _emit(SyncPairingStatus(
      phase: SyncPairingPhase.failed,
      role: run.role,
      peerName: _status.peerName,
      peerMemberId: _status.peerMemberId,
      errorCode: code,
    ));
  }

  Future<void> _tellPeer(PairingChannel? channel, String code) async {
    if (channel != null) await _tellPeerQuietly(() => channel.sendError(code));
  }

  /// Sends a last message to the peer; a peer that is gone is not an error
  /// because the pairing ends either way.
  Future<void> _tellPeerQuietly(Future<void> Function() send) async {
    try {
      await send();
    } on Object {
      // The peer is gone; nothing to tell.
    }
  }

  String _errorCodeOf(Object error, _PairingRun run) => switch (error) {
        SyncPairingException(:final code) => code,
        _ when run.cancelled => SyncPairingErrorCode.cancelled,
        SyncMembershipException() => SyncPairingErrorCode.refused,
        TimeoutException() || TransportClosedException() => SyncPairingErrorCode.unreachable,
        _ => SyncPairingErrorCode.refused,
      };

  Future<SyncPairingStatus> _nextSettledStatus() => _statusController.stream.firstWhere(_isSettled);

  bool _isSettled(SyncPairingStatus status) =>
      status.isTerminal ||
      status.phase == SyncPairingPhase.comparingCodes ||
      status.phase == SyncPairingPhase.awaitingGroupSwitch;

  void _emit(SyncPairingStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void _destroyToken() {
    _token?.destroy();
    _token = null;
  }

  // -- shared ----------------------------------------------------------------------------

  X25519KeyPair get _staticKey => _membershipService.membership.identity.x25519;

  Future<bool> _isUpgradeDone() async => (await _upgradeService.getProgress()).isDone;

  Future<void> _requireReady() async {
    if (!_membershipService.hasIdentity) throw const SyncPairingException(SyncPairingErrorCode.refused);
    if (!await _isUpgradeDone()) throw const SyncPairingException(SyncPairingErrorCode.preparing);
  }

  Future<void> _rememberPeer(String memberId, List<String> addresses, String? platform) async {
    await _statusStore.saveAddresses(memberId, addresses);
    if (platform != null) await _statusStore.savePlatform(memberId, platform);
  }

  bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
