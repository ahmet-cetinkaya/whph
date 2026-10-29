import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/infrastructure/shared/features/sync/lan_sync_server.dart';

/// Desktop platform adapter of the LAN server (PB-6): the server listens
/// only in server mode. In client or disabled mode nothing listens on the
/// sync port, so a connection attempt is refused.
class DesktopLanSyncAdapter {
  final LanSyncServer _server;

  DesktopLanSyncAdapter(this._server);

  bool get isServerActive => _server.isRunning;

  int get connectionCount => _server.activeConnectionCount;

  /// Applies the desktop sync [mode]. Returns whether the server runs
  /// afterwards when the mode asks for it, `true` otherwise.
  Future<bool> applyMode(DesktopSyncMode mode) async {
    if (mode == DesktopSyncMode.server) return _server.start();
    await _server.stop();
    return true;
  }
}
