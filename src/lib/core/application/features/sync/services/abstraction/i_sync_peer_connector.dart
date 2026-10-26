import 'package:whph_sync_core/whph_sync_core.dart';

/// Opens a transport to a peer on the LAN. Throws when the peer is not
/// reachable or refuses the connection.
abstract interface class ISyncPeerConnector {
  Future<ISyncTransport> connect(String address, {required int port, bool forPairing = false});
}

/// The LAN server the app runs for incoming sessions (PB-6: the desktop
/// toggle and the Android server mode start and stop it).
abstract interface class ISyncServerControl {
  bool get isRunning;

  /// Returns `false` when the port cannot be bound.
  Future<bool> start();

  Future<void> stop();
}
