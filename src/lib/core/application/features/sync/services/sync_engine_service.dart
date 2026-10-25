import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runner.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_connector.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_state_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_upgrade_service.dart';
import 'package:whph/core/application/features/sync/services/sync_membership_service.dart';
import 'package:whph/core/application/features/sync/services/sync_result_classifier.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

const String _component = 'SyncEngineService';

/// Runs the sync engine against the peers of the group (FR-008, PB-3): one
/// session per peer, sequentially, and records each outcome as the peer's
/// status (FR-016). Sessions to different peers never overlap, so a manual
/// "sync now" and the periodic run cannot start two sessions with one peer.
class SyncEngineService implements ISyncRunner {
  final SyncMembershipService _membershipService;
  final ISyncPeerStatusStore _statusStore;
  final ISyncPeerStateStore _peerStateStore;
  final ISyncPeerConnector _connector;
  final ISyncSessionHost _host;
  final ISyncUpgradeService _upgradeService;
  final AsyncSessionDevice _device;
  final int _port;
  final DateTime Function() _now;
  Future<void> _queue = Future.value();

  SyncEngineService({
    required SyncMembershipService membershipService,
    required ISyncPeerStatusStore statusStore,
    required ISyncPeerStateStore peerStateStore,
    required ISyncPeerConnector connector,
    required ISyncSessionHost host,
    required ISyncUpgradeService upgradeService,
    required AsyncSessionDevice device,
    required int port,
    DateTime Function()? now,
  })  : _membershipService = membershipService,
        _statusStore = statusStore,
        _peerStateStore = peerStateStore,
        _connector = connector,
        _host = host,
        _upgradeService = upgradeService,
        _device = device,
        _port = port,
        _now = now ?? DateTime.now;

  /// FR-017: some item of [memberId] failed to apply in 3 consecutive sessions.
  bool itemsCannotBeApplied(String memberId) => _device.peerState(memberId).itemsCannotBeApplied;

  /// Syncs with every peer of the group.
  @override
  Future<SyncRunReport> syncAll() => _exclusive(() async {
        final peers = await _peerIds();
        if (peers == null) return const SyncRunReport(skipped: true);
        return SyncRunReport(peers: [for (final peer in peers) await _syncPeer(peer)]);
      });

  /// Syncs with [memberId] only.
  @override
  Future<SyncRunReport> syncPeer(String memberId) => _exclusive(() async {
        final peers = await _peerIds();
        if (peers == null || !peers.contains(memberId)) return const SyncRunReport(skipped: true);
        return SyncRunReport(peers: [await _syncPeer(memberId)]);
      });

  /// The peers to sync with, or `null` when no sync may run now.
  Future<List<String>?> _peerIds() async {
    if (!(await _upgradeService.getProgress()).isDone) return null;
    if (!_membershipService.hasIdentity || !await _membershipService.isPaired()) return null;
    final view = await _membershipService.currentView();
    return [
      for (final member in view.activeMembers)
        if (member.memberId != view.memberId && !view.peersNeedingRepairing.contains(member.memberId)) member.memberId,
    ];
  }

  Future<SyncPeerReport> _syncPeer(String memberId) async {
    final before = (await _statusStore.read(memberId))?.lastResult;
    await _statusStore.setResult(memberId, null);
    final result = await _runSession(memberId);
    final category = classifySessionResult(result);
    final keptByEngine = await _keptCategory(memberId);
    await _record(memberId, result, category, before, keptByEngine);
    final shown = keptByEngine ?? (leavesStatusUnchanged(result) ? before : category);
    return SyncPeerReport(
      memberId: memberId,
      result: result,
      category: shown,
      itemsCannotBeApplied: itemsCannotBeApplied(memberId),
    );
  }

  /// The category the session itself left on the peer (a duplicated identity
  /// found while applying), which a later result must not overwrite.
  Future<SyncResultCategory?> _keptCategory(String memberId) async {
    final current = (await _statusStore.read(memberId))?.lastResult;
    return current == SyncResultCategory.duplicatedIdentity ? current : null;
  }

  Future<void> _record(
    String memberId,
    SessionResult result,
    SyncResultCategory? category,
    SyncResultCategory? before,
    SyncResultCategory? keptByEngine,
  ) async {
    if (result.isComplete) await _statusStore.recordSuccess(memberId, _now());
    if (keptByEngine != null) return;
    await _statusStore.setResult(memberId, leavesStatusUnchanged(result) ? before : category);
  }

  /// Tries the stored addresses of the peer until one answers.
  Future<SessionResult> _runSession(String memberId) async {
    final addresses = await _peerStateStore.addressesOf(memberId);
    SessionResult last = SessionFailed(SessionStats(), memberId, SessionFailure.notReachable);
    for (final address in addresses) {
      last = await _runSessionAt(address, memberId);
      if (!_isUnreachable(last)) return last;
    }
    return last;
  }

  bool _isUnreachable(SessionResult result) =>
      result is SessionFailed && result.category == SessionFailure.notReachable;

  Future<SessionResult> _runSessionAt(String address, String memberId) async {
    final ISyncTransport transport;
    try {
      transport = await _connector.connect(address, port: _port);
    } on Object catch (error) {
      Logger.debug('connect failed: ${error.runtimeType}', component: _component);
      return SessionFailed(SessionStats(), memberId, SessionFailure.notReachable);
    }
    try {
      return await _host.initiate(transport, memberId);
    } on Object catch (error) {
      Logger.warning('session ended with ${error.runtimeType}', component: _component);
      return SessionFailed(SessionStats(), memberId, SessionFailure.internal, error: error);
    } finally {
      await transport.close();
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }
}
