import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';

/// Android platform adapter of the LAN server: the user starts and stops the
/// server mode; the adapter forwards to the shared server.
class AndroidLanSyncAdapter {
  final LanSyncServer _server;

  AndroidLanSyncAdapter(this._server);

  bool get isServerMode => _server.isRunning;

  Future<bool> startAsServer() => _server.start();

  Future<void> stopServer() => _server.stop();
}
