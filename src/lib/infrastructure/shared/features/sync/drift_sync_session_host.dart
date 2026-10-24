import 'package:whph/core/application/features/sync/services/abstraction/i_sync_session_host.dart';
import 'package:whph/infrastructure/shared/features/sync/drift_async_session_device.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

/// Runs a QR pairing handshake on [transport] (the responder side).
typedef SyncPairingHandler = Future<void> Function(
    ISyncTransport transport, String source);

/// The [ISyncSessionHost] of the app: answers incoming sessions with the async
/// session engine over the Drift-backed [DriftAsyncSessionDevice], and starts
/// outgoing ones for the LAN client (T22e).
class DriftSyncSessionHost implements ISyncSessionHost {
  final DriftAsyncSessionDevice device;
  final String platform;
  final String appVersion;
  final SessionHooks hooks;
  final SyncPairingHandler? onPair;

  const DriftSyncSessionHost({
    required this.device,
    required this.platform,
    required this.appVersion,
    this.hooks = const SessionHooks(),
    this.onPair,
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
  Future<SessionResult> respond(ISyncTransport transport, String source) =>
      AsyncSyncSession(device, transport, initiator: false, hooks: hooks).run();

  /// Runs the initiator side towards [peerMemberId] on an open transport.
  Future<SessionResult> initiate(
          ISyncTransport transport, String peerMemberId) =>
      AsyncSyncSession(device, transport,
              initiator: true, expectedPeer: peerMemberId, hooks: hooks)
          .run();

  @override
  Future<void> pair(ISyncTransport transport, String source) async {
    await onPair?.call(transport, source);
  }
}
