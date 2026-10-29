import 'package:whph_sync_core/whph_sync_core.dart';

/// What a device tells anyone who asks, before authentication: it exists and
/// speaks this protocol. Nothing else is disclosed (D7, D10).
class SyncPresence {
  final String memberId;
  final String deviceName;
  final String platform;
  final String appVersion;
  final int protocolVersion;

  const SyncPresence({
    required this.memberId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
    required this.protocolVersion,
  });
}

/// The application side of the LAN server: it answers incoming sessions and
/// pairing handshakes and describes this device. The transport layer owns
/// the socket and closes it after each call.
abstract interface class ISyncSessionHost {
  Future<SyncPresence> presence();

  /// Runs the responder side of a sync session.
  Future<SessionResult> respond(ISyncTransport transport, String source);

  /// Runs the initiator side of a sync session towards [peerMemberId].
  Future<SessionResult> initiate(ISyncTransport transport, String peerMemberId);

  /// Runs the responder side of a pairing connection.
  Future<void> pair(ISyncTransport transport, String source);
}
