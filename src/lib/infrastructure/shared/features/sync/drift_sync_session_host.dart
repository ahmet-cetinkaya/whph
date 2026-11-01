import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_peer_status_store.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/core/application/features/sync/services/sync_progress_tracker.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_async_session_device.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// Runs a QR pairing handshake on [transport] (the responder side).
typedef SyncPairingHandler = Future<void> Function(ISyncTransport transport, String source);

/// The [ISyncSessionHost] of the app: answers incoming sessions with the async
/// session engine over the Drift-backed [DriftAsyncSessionDevice], and starts
/// outgoing ones for the LAN client (T22e).
class DriftSyncSessionHost implements ISyncSessionHost {
  final DriftAsyncSessionDevice device;
  final String platform;
  final String appVersion;
  final SessionHooks hooks;
  final SyncPairingHandler? onPair;

  /// Where the responder records the last success of the peer, as the engine does for the sessions it starts.
  final ISyncPeerStatusStore? statusStore;
  final DateTime Function() now;

  /// Told how far the sessions of this device have come, those it starts and those it answers.
  final SyncProgressTracker? progress;

  const DriftSyncSessionHost({
    required this.device,
    required this.platform,
    required this.appVersion,
    this.hooks = const SessionHooks(),
    this.onPair,
    this.statusStore,
    this.now = DateTime.now,
    this.progress,
  });

  @override
  Future<SyncPresence> presence() async => SyncPresence(
        memberId: device.memberId,
        deviceName: device.name,
        platform: platform,
        appVersion: appVersion,
        protocolVersion: syncProtocolVersion,
      );

  @override
  Future<SessionResult> respond(ISyncTransport transport, String source) async {
    // The peer is only known after the handshake, so the progress callback asks the session for it.
    late final AsyncSyncSession session;
    session = AsyncSyncSession(
      device,
      transport,
      initiator: false,
      hooks: hooks,
      onProgress: (processed, total) {
        final peerMemberId = session.peerMemberId;
        if (peerMemberId != null) progress?.report(peerMemberId, processed, total);
      },
    );
    try {
      final result = await session.run();
      await _recordPeerSuccessSafely(result);
      return result;
    } finally {
      final peerMemberId = session.peerMemberId;
      if (peerMemberId != null) progress?.end(peerMemberId);
    }
  }

  Future<void> _recordPeerSuccessSafely(SessionResult result) async {
    try {
      await _recordPeerSuccess(result);
    } catch (error, stackTrace) {
      // The session already completed; a status-store failure must not fail it.
      Logger.error('Could not record the peer status after a completed session', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _recordPeerSuccess(SessionResult result) async {
    final peerMemberId = result.peerMemberId;
    if (!result.isComplete || peerMemberId == null) return;
    final store = statusStore;
    if (store == null) return;
    await store.recordSuccess(peerMemberId, now());
    await _clearStaleUnreachable(store, peerMemberId);
  }

  /// A finished session proves the peer is reachable, so an earlier failed attempt of this device must not keep
  /// saying otherwise; any other stored result stays because the session alone does not resolve it.
  Future<void> _clearStaleUnreachable(ISyncPeerStatusStore store, String peerMemberId) async {
    final lastResult = (await store.read(peerMemberId))?.lastResult;
    if (lastResult == SyncResultCategory.notReachable) await store.setResult(peerMemberId, null);
  }

  @override
  Future<SessionResult> initiate(ISyncTransport transport, String peerMemberId) => AsyncSyncSession(
        device,
        transport,
        initiator: true,
        expectedPeer: peerMemberId,
        hooks: hooks,
        onProgress: (processed, total) => progress?.report(peerMemberId, processed, total),
      ).run();

  @override
  Future<void> pair(ISyncTransport transport, String source) async {
    await onPair?.call(transport, source);
  }
}
