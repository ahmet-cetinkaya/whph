import 'dart:async';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/features/sync/services/sync_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_settings.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_server_sync_service.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_client_sync_service.dart';

/// Enhanced desktop sync service with mode switching capabilities
class DesktopSyncService extends SyncService {
  Timer? _periodicTimer;

  DesktopSyncMode _currentMode = DesktopSyncMode.server;
  DesktopSyncSettings _settings = const DesktopSyncSettings();

  DesktopServerSyncService? _serverService;
  DesktopClientSyncService? _clientService;

  final IDeviceIdService _deviceIdService;

  bool _isModeSwitching = false;

  DesktopSyncService(super.mediator, this._deviceIdService) {
    _validateAndRecoverSyncState();
  }

  void _validateAndRecoverSyncState() {
    try {
      if (_isModeSwitching) {
        Logger.warning('Desktop sync service was in mode-switching state at startup - this indicates a crash',
            component: 'DesktopSyncService');
        _isModeSwitching = false;
        Logger.info('Reset mode-switching flag to prevent deadlocks', component: 'DesktopSyncService');
      }

      final hasServerService = _serverService != null;
      final hasClientService = _clientService != null;

      if (_currentMode == DesktopSyncMode.server && !hasServerService) {
        Logger.warning('Inconsistent state: server mode but no server service - resetting',
            component: 'DesktopSyncService');
        _currentMode = DesktopSyncMode.disabled;
      } else if (_currentMode == DesktopSyncMode.client && !hasClientService) {
        Logger.warning('Inconsistent state: client mode but no client service - resetting',
            component: 'DesktopSyncService');
        _currentMode = DesktopSyncMode.disabled;
      }

      Logger.info(
          'Sync service initialized: mode=${_currentMode.name}, services=server:$hasServerService,client:$hasClientService',
          component: 'DesktopSyncService');
      Logger.info('Sync state validation and recovery completed', component: 'DesktopSyncService');
    } catch (e) {
      Logger.error('Error during sync state recovery: $e');
      _currentMode = DesktopSyncMode.disabled;
      _isModeSwitching = false;
      Logger.info('Forced safe state due to recovery error', component: 'DesktopSyncService');
    }
  }

  DesktopSyncMode get currentMode => _currentMode;

  DesktopSyncSettings get settings => _settings;

  bool get isConnectedAsClient => _clientService?.isConnectedToServer ?? false;

  bool get isServerActive => _serverService?.isServerMode ?? false;

  int get serverConnectionCount => _serverService?.activeConnectionCount ?? 0;

  Map<String, dynamic>? get clientConnectionInfo => _clientService?.connectedServerInfo;

  Future<void> updateSettings(DesktopSyncSettings newSettings) async {
    _settings = newSettings;

    if (_currentMode != newSettings.preferredMode) {
      await switchToMode(newSettings.preferredMode);
    }
  }

  Future<void> switchToServerMode() async {
    await switchToMode(DesktopSyncMode.server);
  }

  Future<void> switchToClientMode(String serverAddress, int serverPort) async {
    _settings = _settings.copyWith(
      preferredMode: DesktopSyncMode.client,
      lastServerAddress: serverAddress,
      lastServerPort: serverPort,
    );

    await switchToMode(DesktopSyncMode.client);
  }

  Future<void> switchToMode(DesktopSyncMode mode) async {
    if (_isModeSwitching) {
      Logger.warning('Mode switch already in progress, ignoring request');
      return;
    }

    if (_currentMode == mode) {
      return; // Already in requested mode
    }

    if (!_isCurrentStateValid()) {
      Logger.warning('Current sync state is invalid, forcing cleanup before mode switch');
      await _forceCleanupAndReset();
    }

    _isModeSwitching = true;

    try {
      Logger.info('Switching desktop sync from ${_currentMode.name} to ${mode.name} mode');

      await _stopCurrentModeWithTimeout();

      _currentMode = mode;

      await _startCurrentModeWithRecovery();

      Logger.info('Successfully switched to ${mode.name} mode');
    } catch (e) {
      Logger.error('Error during mode switch: $e');

      Logger.warning('Attempting recovery after mode switch error...');
      await _recoverFromModeSwitchError();

      rethrow;
    } finally {
      _isModeSwitching = false;
    }
  }

  bool _isCurrentStateValid() {
    switch (_currentMode) {
      case DesktopSyncMode.server:
        return _serverService != null && _serverService!.isServerMode;
      case DesktopSyncMode.client:
        return _clientService != null;
      case DesktopSyncMode.disabled:
        return _serverService == null && _clientService == null;
    }
  }

  Future<void> _forceCleanupAndReset() async {
    Logger.info('Forcing cleanup and reset of sync service...');

    try {
      await _stopCurrentModeAggressive();

      _currentMode = DesktopSyncMode.disabled;
      _isModeSwitching = false;

      Logger.info('Forced cleanup and reset completed');
    } catch (e) {
      Logger.error('Error during forced cleanup: $e');
      _currentMode = DesktopSyncMode.disabled;
      _isModeSwitching = false;
    }
  }

  Future<void> _stopCurrentModeWithTimeout() async {
    try {
      await _stopCurrentMode().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.warning('Mode stop operation timed out, forcing aggressive cleanup');
          return _stopCurrentModeAggressive();
        },
      );
    } catch (e) {
      Logger.warning('Error stopping current mode, forcing aggressive cleanup: $e');
      await _stopCurrentModeAggressive();
    }
  }

  Future<void> _stopCurrentModeAggressive() async {
    Logger.info('Performing aggressive sync mode stop', component: 'DesktopSyncService');

    _periodicTimer?.cancel();
    _periodicTimer = null;

    if (_serverService != null) {
      try {
        await _serverService!.stopServer();
      } catch (e) {
        Logger.warning('Error stopping server service (ignoring): $e');
      } finally {
        _serverService?.dispose();
        _serverService = null;
      }
    }

    if (_clientService != null) {
      try {
        await _clientService!.disconnectFromServer();
      } catch (e) {
        Logger.warning('Error disconnecting client service (ignoring): $e');
      } finally {
        _clientService?.dispose();
        _clientService = null;
      }
    }

    Logger.debug('Aggressive mode stop completed');
  }

  Future<void> _startCurrentModeWithRecovery() async {
    try {
      await _startCurrentMode().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          Logger.warning('Mode start operation timed out');
          throw TimeoutException('Mode start operation timed out', const Duration(seconds: 15));
        },
      );
    } catch (e) {
      Logger.error('Error starting current mode: $e');

      await _stopCurrentModeAggressive();
      _currentMode = DesktopSyncMode.disabled;

      rethrow;
    }
  }

  Future<void> _recoverFromModeSwitchError() async {
    Logger.info('Recovering from mode switch error...');

    try {
      await _stopCurrentModeAggressive();

      _currentMode = DesktopSyncMode.disabled;

      Logger.info('Recovery completed, sync service is now in disabled mode');
    } catch (e) {
      Logger.error('Error during recovery: $e');
      _currentMode = DesktopSyncMode.disabled;
    }
  }

  Future<void> _stopCurrentMode() async {
    Logger.debug('Stopping current sync mode: ${_currentMode.name}');

    _periodicTimer?.cancel();
    _periodicTimer = null;

    if (_serverService != null) {
      try {
        Logger.debug('Stopping server service...');
        await _serverService!.stopServer();
        Logger.debug('Server service stopped');
      } catch (e) {
        Logger.error('Error stopping server service: $e');
      } finally {
        _serverService?.dispose();
        _serverService = null;
      }
    }

    if (_clientService != null) {
      try {
        Logger.debug('Disconnecting client service...');
        await _clientService!.disconnectFromServer();
        Logger.debug('Client service disconnected');
      } catch (e) {
        Logger.error('Error disconnecting client service: $e');
      } finally {
        _clientService?.dispose();
        _clientService = null;
      }
    }

    Logger.debug('Current mode stopped and cleaned up');
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

    final serverStarted = await _serverService!.startAsServer();
    if (!serverStarted) {
      Logger.error('Failed to start server - server mode requires successful server startup');
      throw Exception('Failed to start desktop server');
    }

    Logger.info('Desktop server mode started - waiting for client connections');
  }

  Future<void> _startClientMode() async {
    Logger.debug('Starting desktop client mode');

    _clientService = DesktopClientSyncService(mediator, _deviceIdService);

    if (_settings.hasValidClientSettings && _settings.autoReconnectToServer) {
      final connected = await _clientService!.connectToServer(
        _settings.lastServerAddress!,
        _settings.lastServerPort!,
      );

      if (!connected) {
        Logger.warning('Failed to connect to server: ${_settings.lastServerAddress}:${_settings.lastServerPort}');
      }
    } else {
      Logger.info('Client mode started, but no server connection configured');
    }
  }

  @override
  Future<void> startSync() async {
    await _startCurrentMode();
  }

  @override
  void stopSync() {
    // Runs async; caller cannot wait for completion
    _stopCurrentMode();
  }

  @override
  void dispose() {
    Logger.debug('Disposing DesktopSyncService');
    try {
      _stopCurrentMode();
    } catch (e) {
      Logger.error('Error during disposal cleanup: $e');
    }
    super.dispose();
  }

  bool get isModeSwitching => _isModeSwitching;
}
