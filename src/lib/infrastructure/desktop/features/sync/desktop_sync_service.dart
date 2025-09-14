import 'dart:async';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_settings.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_server_sync_service.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_client_sync_service.dart';

/// Enhanced desktop sync service with mode switching capabilities
class DesktopSyncService extends SyncService {
  Timer? _periodicTimer;
  static const Duration _syncInterval = Duration(minutes: 30);

  DesktopSyncMode _currentMode = DesktopSyncMode.server;
  DesktopSyncSettings _settings = const DesktopSyncSettings();

  DesktopServerSyncService? _serverService;
  DesktopClientSyncService? _clientService;

  final IDeviceIdService _deviceIdService;

  DesktopSyncService(super.mediator, this._deviceIdService);

  /// Get current sync mode
  DesktopSyncMode get currentMode => _currentMode;

  /// Get current settings
  DesktopSyncSettings get settings => _settings;

  /// Check if connected as client
  bool get isConnectedAsClient => _clientService?.isConnectedToServer ?? false;

  /// Check if server is active
  bool get isServerActive => _serverService?.isServerMode ?? false;

  /// Get server connection count
  int get serverConnectionCount => _serverService?.activeConnectionCount ?? 0;

  /// Get client connection info
  Map<String, dynamic>? get clientConnectionInfo => _clientService?.connectedServerInfo;

  /// Update sync settings
  Future<void> updateSettings(DesktopSyncSettings newSettings) async {
    _settings = newSettings;

    // If mode changed, switch to new mode
    if (_currentMode != newSettings.preferredMode) {
      await switchToMode(newSettings.preferredMode);
    }
  }

  /// Switch to server mode
  Future<void> switchToServerMode() async {
    await switchToMode(DesktopSyncMode.server);
  }

  /// Switch to client mode with server connection
  Future<void> switchToClientMode(String serverAddress, int serverPort) async {
    // Update settings with server connection info
    _settings = _settings.copyWith(
      preferredMode: DesktopSyncMode.client,
      lastServerAddress: serverAddress,
      lastServerPort: serverPort,
    );

    await switchToMode(DesktopSyncMode.client);
  }

  /// Switch to specified sync mode
  Future<void> switchToMode(DesktopSyncMode mode) async {
    if (_currentMode == mode) {
      Logger.debug('Already in ${mode.name} mode');
      return;
    }

    Logger.info('🔄 Switching desktop sync from ${_currentMode.name} to ${mode.name} mode');

    // Stop current mode
    await _stopCurrentMode();

    _currentMode = mode;

    // Start new mode
    await _startCurrentMode();

    Logger.info('✅ Successfully switched to ${mode.name} mode');
  }

  Future<void> _stopCurrentMode() async {
    // Stop periodic sync
    _periodicTimer?.cancel();
    _periodicTimer = null;

    // Stop server service
    if (_serverService != null) {
      await _serverService!.stopServer();
      _serverService = null;
    }

    // Stop client service
    if (_clientService != null) {
      await _clientService!.disconnectFromServer();
      _clientService = null;
    }
  }

  Future<void> _startCurrentMode() async {
    switch (_currentMode) {
      case DesktopSyncMode.server:
        await _startServerMode();
        break;
      case DesktopSyncMode.client:
        await _startClientMode();
        break;
      case DesktopSyncMode.disabled:
        Logger.info('Sync is disabled');
        break;
    }
  }

  Future<void> _startServerMode() async {
    Logger.debug('Starting desktop server mode');

    _serverService = DesktopServerSyncService(mediator, _deviceIdService);

    // Try to start as server
    final serverStarted = await _serverService!.startAsServer();
    if (!serverStarted) {
      Logger.warning('Failed to start server, falling back to periodic sync only');
    }

    // Start periodic sync
    await _startPeriodicSync();
  }

  Future<void> _startClientMode() async {
    Logger.debug('Starting desktop client mode');

    _clientService = DesktopClientSyncService(mediator, _deviceIdService);

    // Try to connect to server if settings available
    if (_settings.hasValidClientSettings && _settings.autoReconnectToServer) {
      final connected = await _clientService!.connectToServer(
        _settings.lastServerAddress!,
        _settings.lastServerPort!,
      );

      if (!connected) {
        Logger.warning('Failed to connect to server: ${_settings.lastServerAddress}:${_settings.lastServerPort}');
        // Could implement retry logic here based on settings
      }
    } else {
      Logger.info('Client mode started, but no server connection configured');
    }
  }

  Future<void> _startPeriodicSync() async {
    Logger.debug('Starting desktop periodic sync (30 minutes)');

    // Run initial sync
    await runSync();

    // Start periodic sync
    _periodicTimer = Timer.periodic(_syncInterval, (timer) async {
      try {
        Logger.debug('Running periodic sync at ${DateTime.now()}');
        await runSync();
      } catch (e) {
        Logger.error('Periodic sync failed: $e');
      }
    });

    Logger.debug('Started desktop periodic sync with interval: ${_syncInterval.inMinutes} minutes');
  }

  @override
  Future<void> startSync() async {
    await _startCurrentMode();
  }

  @override
  void stopSync() {
    _stopCurrentMode();
  }

  @override
  void dispose() {
    _stopCurrentMode();
    super.dispose();
  }
}
