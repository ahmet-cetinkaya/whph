// T23 acceptance 5 (FR-025, Scenario 2.5) and the pairing flows of the
// application layer over real devices: a QR token has one successful use and
// 5 minutes; a failed attempt does not burn it; code pairing needs both
// users; leaving a group needs a confirmation.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_pairing_models.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pairing_service.dart';
import 'package:whph/infrastructure/persistence/features/sync/repositories/drift_sync_peer_status_store.dart';

import 'sync_app_test_support.dart';
import 'sync_security_test_support.dart';

const Duration _insideExpiry = Duration(minutes: 4, seconds: 59);
const Duration _pastExpiry = Duration(minutes: 5, seconds: 1);
const int _codeDigits = 6;

class _LoopbackNetwork extends Fake implements INetworkInterfaceService {
  @override
  Future<List<String>> getPreferredIPAddresses() async => [loopbackAddress];
}

/// One side of a pairing: a device, its pairing service and its clock.
class _Side {
  final SecurityDevice device;
  final SyncPairingService service;
  final LoopbackConnector connector;

  _Side(this.device, this.service, this.connector);

  static _Side of(SecurityDevice device, DateTime Function() now) {
    final connector = LoopbackConnector();
    return _Side(
      device,
      SyncPairingService(
        membershipService: device.service,
        connector: connector,
        statusStore: DriftSyncPeerStatusStore(device.database.db),
        networkInterfaces: _LoopbackNetwork(),
        upgradeService: DoneUpgradeService(),
        platform: 'linux',
        now: now,
      ),
      connector,
    );
  }

  /// The side that connects reaches [answering] through the loopback.
  void connectTo(_Side answering) {
    connector.responder = (transport) => answering.service.respond(transport, loopbackAddress);
  }
}

void main() {
  late Directory scratch;
  late DateTime clock;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('sync-pairing-');
    clock = DateTime.utc(2026, 1, 1);
  });
  tearDown(() => scratch.delete(recursive: true));

  Future<_Side> newSide(String name) async {
    final device = await SecurityDevice.open(name, scratch);
    addTearDown(device.close);
    return _Side.of(device, () => clock);
  }

  Future<(_Side, _Side)> twoSides() async {
    final inviter = await newSide('inviter');
    final joiner = await newSide('joiner');
    joiner.connectTo(inviter);
    return (inviter, joiner);
  }

  Future<void> expectPaired(_Side inviter, _Side joiner) async {
    expect(await inviter.device.service.isPaired(), isTrue);
    expect(await joiner.device.service.isPaired(), isTrue);
    expect(joiner.device.membership.groupId, inviter.device.membership.groupId);
    expect(inviter.device.membership.members.keys, contains(joiner.device.memberId));
    expect(await inviter.device.peerStates.addressesOf(joiner.device.memberId), [loopbackAddress]);
    expect(await joiner.device.peerStates.addressesOf(inviter.device.memberId), [loopbackAddress]);
  }

  group('QR pairing (FR-024, FR-025)', () {
    test('a scan pairs both devices and stores the addresses', () async {
      final (inviter, joiner) = await twoSides();
      final invitation = await inviter.service.createInvitation();

      final status = await joiner.service.pairFromInvitation(PairingInvitation.decode(invitation.encode()));

      expect(status.phase, SyncPairingPhase.completed, reason: '${status.errorCode}');
      await expectPaired(inviter, joiner);
      expect(inviter.service.status.phase, SyncPairingPhase.completed);
    });

    test('second successful-handshake attempt fails with pairing_code_expired_or_used', () async {
      final (inviter, joiner) = await twoSides();
      final second = await newSide('second');
      second.connectTo(inviter);
      final invitation = await inviter.service.createInvitation();
      expect((await joiner.service.pairFromInvitation(invitation)).phase, SyncPairingPhase.completed);

      final status = await second.service.pairFromInvitation(invitation);

      expect(status.phase, SyncPairingPhase.failed);
      expect(status.errorCode, SyncPairingErrorCode.codeExpiredOrUsed);
      expect(await second.device.service.isPaired(), isFalse);
    });

    test('at 5:01 the token is expired', () async {
      final (inviter, joiner) = await twoSides();
      final invitation = await inviter.service.createInvitation();
      clock = clock.add(_pastExpiry);

      final status = await joiner.service.pairFromInvitation(invitation);

      expect(status.errorCode, SyncPairingErrorCode.codeExpiredOrUsed);
      expect(await joiner.device.service.isPaired(), isFalse);
    });

    test('at 4:59 the token still works', () async {
      final (inviter, joiner) = await twoSides();
      final invitation = await inviter.service.createInvitation();
      clock = clock.add(_insideExpiry);

      final status = await joiner.service.pairFromInvitation(invitation);

      expect(status.phase, SyncPairingPhase.completed, reason: '${status.errorCode}');
      await expectPaired(inviter, joiner);
    });

    test('a wrong-PSK attempt at 1:00 does not prevent a correct scan at 2:00', () async {
      final (inviter, joiner) = await twoSides();
      final attacker = await newSide('attacker');
      attacker.connectTo(inviter);
      final invitation = await inviter.service.createInvitation();
      clock = clock.add(const Duration(minutes: 1));
      final wrongToken = PairingInvitation(
        memberId: invitation.memberId,
        addresses: invitation.addresses,
        port: invitation.port,
        fingerprint: invitation.fingerprint,
        token: List<int>.filled(invitation.token.length, 7),
        expiresAt: invitation.expiresAt,
      );

      final failed = await attacker.service.pairFromInvitation(wrongToken);
      expect(failed.phase, SyncPairingPhase.failed);
      expect(await inviter.device.service.isPaired(), isFalse);

      clock = clock.add(const Duration(minutes: 1));
      final status = await joiner.service.pairFromInvitation(invitation);

      expect(status.phase, SyncPairingPhase.completed, reason: '${status.errorCode}');
      await expectPaired(inviter, joiner);
    });

    test('a scanner that expects another static key is refused', () async {
      final (inviter, joiner) = await twoSides();
      final invitation = await inviter.service.createInvitation();
      final impostor = PairingInvitation(
        memberId: invitation.memberId,
        addresses: invitation.addresses,
        port: invitation.port,
        fingerprint: List<int>.filled(invitation.fingerprint.length, 1),
        token: invitation.token,
        expiresAt: invitation.expiresAt,
      );

      final status = await joiner.service.pairFromInvitation(impostor);

      expect(status.phase, SyncPairingPhase.failed);
      expect(await joiner.device.service.isPaired(), isFalse);
    });

    test('a malformed scanned text is rejected before any connection', () {
      expect(() => PairingInvitation.decode('not a pairing code'), throwsFormatException);
    });
  });

  group('pairing with a code both users compare (FR-024)', () {
    test('both screens show the same 6 digits and pairing finishes after both confirm', () async {
      final (inviter, joiner) = await twoSides();
      await inviter.service.createInvitation();

      final joinerStatus = await joiner.service.startPairingWithAddress(loopbackAddress);

      expect(joinerStatus.phase, SyncPairingPhase.comparingCodes, reason: '${joinerStatus.errorCode}');
      expect(joinerStatus.code, matches(RegExp('^\\d{$_codeDigits}\$')));
      await _eventually(() => inviter.service.status.phase == SyncPairingPhase.comparingCodes);
      expect(inviter.service.status.code, joinerStatus.code);

      final joinerDone = joiner.service.confirmCode();
      final inviterDone = inviter.service.confirmCode();

      expect((await joinerDone).phase, SyncPairingPhase.completed);
      expect((await inviterDone).phase, SyncPairingPhase.completed);
      await expectPaired(inviter, joiner);
    });

    test('cancel on one screen aborts both', () async {
      final (inviter, joiner) = await twoSides();
      await inviter.service.createInvitation();
      await joiner.service.startPairingWithAddress(loopbackAddress);
      await _eventually(() => inviter.service.status.phase == SyncPairingPhase.comparingCodes);

      final joinerDone = joiner.service.confirmCode();
      inviter.service.cancel();

      expect((await joinerDone).phase, SyncPairingPhase.failed);
      await _eventually(() => inviter.service.status.isTerminal);
      expect(await inviter.device.service.isPaired(), isFalse);
      expect(await joiner.device.service.isPaired(), isFalse);
    });

    test('a device that shows no invitation does not accept code pairing', () async {
      final (_, joiner) = await twoSides();

      final status = await joiner.service.startPairingWithAddress(loopbackAddress);

      expect(status.phase, SyncPairingPhase.failed);
      expect(status.errorCode, SyncPairingErrorCode.codeExpiredOrUsed);
    });
  });

  group('leaving a group (NB-1)', () {
    test('joining another group needs the confirmation of the user', () async {
      final (inviter, joiner) = await twoSides();
      final other = await newSide('other');
      await pairDevices(joiner.device, other.device);
      final oldGroup = joiner.device.membership.groupId;
      final invitation = await inviter.service.createInvitation();

      final asked = await joiner.service.pairFromInvitation(invitation);
      expect(asked.phase, SyncPairingPhase.awaitingGroupSwitch);
      expect(joiner.device.membership.groupId, oldGroup, reason: 'nothing changes before the answer');

      final done = await joiner.service.confirmGroupSwitch();

      expect(done.phase, SyncPairingPhase.completed, reason: '${done.errorCode}');
      expect(joiner.device.membership.groupId, inviter.device.membership.groupId);
      expect(joiner.device.membership.groupId, isNot(oldGroup));
    });

    test('declining leaves the group and the inviter untouched', () async {
      final (inviter, joiner) = await twoSides();
      final other = await newSide('other');
      await pairDevices(joiner.device, other.device);
      final oldGroup = joiner.device.membership.groupId;
      final invitation = await inviter.service.createInvitation();
      await joiner.service.pairFromInvitation(invitation);

      joiner.service.cancel();
      await _eventually(() => joiner.service.status.isTerminal);

      expect(joiner.service.status.errorCode, SyncPairingErrorCode.groupSwitchDeclined);
      expect(joiner.device.membership.groupId, oldGroup);
      expect(inviter.device.membership.members.keys, isNot(contains(joiner.device.memberId)));
    });
  });

  test('pairing refuses while the upgrade job has not finished', () async {
    final inviter = await newSide('inviter');
    final preparing = SyncPairingService(
      membershipService: inviter.device.service,
      connector: LoopbackConnector(),
      statusStore: DriftSyncPeerStatusStore(inviter.device.database.db),
      networkInterfaces: _LoopbackNetwork(),
      upgradeService: _PreparingUpgradeService(),
      platform: 'linux',
    );

    await expectLater(
      preparing.createInvitation(),
      throwsA(isA<SyncPairingException>().having((e) => e.code, 'code', SyncPairingErrorCode.preparing)),
    );
  });

  test('the category codes are not localized and have no clock category (U10)', () {
    expect(SyncResultCategory.values.map((c) => c.code), everyElement(matches(RegExp(r'^[a-z_]+$'))));
    expect(SyncResultCategory.values.map((c) => c.name.toLowerCase()), everyElement(isNot(contains('clock'))));
    expect(SyncPairingErrorCode.codeExpiredOrUsed, 'pairing_code_expired_or_used');
  });
}

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not reached in time');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _PreparingUpgradeService extends DoneUpgradeService {
  @override
  Future<SyncUpgradeProgress> getProgress() async => const SyncUpgradeProgress(phase: SyncUpgradePhase.reauthor);
}
