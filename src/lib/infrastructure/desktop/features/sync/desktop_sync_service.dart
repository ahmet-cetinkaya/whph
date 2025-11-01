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

  DesktopSyncMode _currentMode = DesktopSyncMode.server;
  DesktopSyncSettings _settings = const DesktopSyncSettings();

  DesktopServerSyncService? _serverService;
  DesktopClientSyncService? _clientService;

  final IDeviceIdService _deviceIdService;

  // State guards to prevent concurrent operations
  bool _isModeSwitching = false;

  DesktopSyncService(super.mediator, this._deviceIdService) {
    // Validate and recover from any interrupted sync state at construction
    _validateAndRecoverSyncState();
  }

  /// Validates and recovers from any interrupted sync state from previous app instances
  /// This prevents crashes caused by leftover sync operations
  void _validateAndRecoverSyncState() {
    Logger.debug('🔍 Validating and recovering sync state...');

    try {
      // Check if we're in an inconsistent state
      if (_isModeSwitching) {
        Logger.warning('⚠️ Desktop sync service was in mode-switching state at startup - this indicates a crash');
        _isModeSwitching = false; // Reset the flag
        Logger.info('🔧 Reset mode-switching flag to prevent deadlocks');
      }

      // Validate that internal state is consistent
      final hasServerService = _serverService != null;
      final hasClientService = _clientService != null;

      if (_currentMode == DesktopSyncMode.server && !hasServerService) {
        Logger.warning('⚠️ Inconsistent state: server mode but no server service - resetting');
        _currentMode = DesktopSyncMode.disabled;
      } else if (_currentMode == DesktopSyncMode.client && !hasClientService) {
        Logger.warning('⚠️ Inconsistent state: client mode but no client service - resetting');
        _currentMode = DesktopSyncMode.disabled;
      }

      // Log current state for debugging
      Logger.debug('📊 Sync service state at startup:');
      Logger.debug('   Current mode: ${_currentMode.name}');
      Logger.debug('   Server service: ${hasServerService ? "exists" : "null"}');
      Logger.debug('   Client service: ${hasClientService ? "exists" : "null"}');
      Logger.debug('   Is mode switching: $_isModeSwitching');

      Logger.info('✅ Sync state validation and recovery completed');
    } catch (e) {
      Logger.error('❌ Error during sync state recovery: $e');
      // Force safe state if recovery fails
      _currentMode = DesktopSyncMode.disabled;
      _isModeSwitching = false;
      Logger.info('🔧 Forced safe state due to recovery error');
    }
  }

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
    // Prevent concurrent mode switches
    if (_isModeSwitching) {
      Logger.warning('⚠️ Mode switch already in progress, ignoring request');
      return;
    }

    if (_currentMode == mode) {
      Logger.debug('Already in ${mode.name} mode');
      return;
    }

    // Additional safety check: validate current state before switching
    if (!_isCurrentStateValid()) {
      Logger.warning('⚠️ Current sync state is invalid, forcing cleanup before mode switch');
      await _forceCleanupAndReset();
    }

    _isModeSwitching = true;

    try {
      Logger.info('🔄 Switching desktop sync from ${_currentMode.name} to ${mode.name} mode');

      // Stop current mode with explicit cleanup and timeout protection
      await _stopCurrentModeWithTimeout();

      _currentMode = mode;

      // Start new mode with error recovery
      await _startCurrentModeWithRecovery();

      Logger.info('✅ Successfully switched to ${mode.name} mode');
    } catch (e) {
      Logger.error('❌ Error during mode switch: $e');

      // Recovery: try to get back to a safe state
      Logger.warning('🔧 Attempting recovery after mode switch error...');
      await _recoverFromModeSwitchError();

      // Re-throw the error so the caller knows the switch failed
      rethrow;
    } finally {
      _isModeSwitching = false;
    }
  }

  /// Validates that the current sync state is consistent
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

  /// Forces cleanup and reset to a safe state
  Future<void> _forceCleanupAndReset() async {
    Logger.info('🔧 Forcing cleanup and reset of sync service...');

    try {
      // Stop everything aggressively
      await _stopCurrentModeAggressive();

      // Reset state
      _currentMode = DesktopSyncMode.disabled;
      _isModeSwitching = false;

      Logger.info('✅ Forced cleanup and reset completed');
    } catch (e) {
      Logger.error('❌ Error during forced cleanup: $e');
      // Ensure we're in a safe state even if cleanup fails
      _currentMode = DesktopSyncMode.disabled;
      _isModeSwitching = false;
    }
  }

  /// Stops current mode with timeout protection
  Future<void> _stopCurrentModeWithTimeout() async {
    try {
      await _stopCurrentMode().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Logger.warning('⚠️ Mode stop operation timed out, forcing aggressive cleanup');
          return _stopCurrentModeAggressive();
        },
      );
    } catch (e) {
      Logger.warning('⚠️ Error stopping current mode, forcing aggressive cleanup: $e');
      await _stopCurrentModeAggressive();
    }
  }

  /// Aggressively stops current mode with error tolerance
  Future<void> _stopCurrentModeAggressive() async {
    Logger.debug('🛑 Performing aggressive mode stop...');

    // Stop periodic timer
    _periodicTimer?.cancel();
    _periodicTimer = null;

    // Stop server service with error tolerance
    if (_serverService != null) {
      try {
        await _serverService!.stopServer();
      } catch (e) {
        Logger.warning('⚠️ Error stopping server service (ignoring): $e');
      } finally {
        _serverService?.dispose();
        _serverService = null;
      }
    }

    // Stop client service with error tolerance
    if (_clientService != null) {
      try {
        await _clientService!.disconnectFromServer();
      } catch (e) {
        Logger.warning('⚠️ Error disconnecting client service (ignoring): $e');
      } finally {
        _clientService?.dispose();
        _clientService = null;
      }
    }

    Logger.debug('✅ Aggressive mode stop completed');
  }

  /// Starts current mode with error recovery
  Future<void> _startCurrentModeWithRecovery() async {
    try {
      await _startCurrentMode().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          Logger.warning('⚠️ Mode start operation timed out');
          throw TimeoutException('Mode start operation timed out', const Duration(seconds: 15));
        },
      );
    } catch (e) {
      Logger.error('❌ Error starting current mode: $e');

      // Try to recover by stopping and cleaning up
      await _stopCurrentModeAggressive();
      _currentMode = DesktopSyncMode.disabled;

      // Re-throw the error
      rethrow;
    }
  }

  /// Recovers from a mode switch error
  Future<void> _recoverFromModeSwitchError() async {
    Logger.info('🔧 Recovering from mode switch error...');

    try {
      // Force cleanup to get back to a known good state
      await _stopCurrentModeAggressive();

      // Reset to disabled mode
      _currentMode = DesktopSyncMode.disabled;

      Logger.info('✅ Recovery completed, sync service is now in disabled mode');
    } catch (e) {
      Logger.error('❌ Error during recovery: $e');
      // Last resort: ensure we're in disabled mode even if cleanup fails
      _currentMode = DesktopSyncMode.disabled;
    }
  }

  Future<void> _stopCurrentMode() async {
    Logger.debug('🛑 Stopping current sync mode: ${_currentMode.name}');

    // Stop periodic sync
    _periodicTimer?.cancel();
    _periodicTimer = null;

    // Stop server service with proper cleanup
    if (_serverService != null) {
      try {
        Logger.debug('🛑 Stopping server service...');
        await _serverService!.stopServer();
        Logger.debug('✅ Server service stopped');
      } catch (e) {
        Logger.error('❌ Error stopping server service: $e');
      } finally {
        _serverService?.dispose();
        _serverService = null;
      }
    }

    // Stop client service with proper cleanup
    if (_clientService != null) {
      try {
        Logger.debug('🛑 Disconnecting client service...');
        await _clientService!.disconnectFromServer();
        Logger.debug('✅ Client service disconnected');
      } catch (e) {
        Logger.error('❌ Error disconnecting client service: $e');
      } finally {
        _clientService?.dispose();
        _clientService = null;
      }
    }

    Logger.debug('✅ Current mode stopped and cleaned up');
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
      Logger.error('Failed to start server - server mode requires successful server startup');
      throw Exception('Failed to start desktop server');
    }

    // Server mode should be passive - no periodic sync needed
    // Servers only respond to sync requests from clients
    Logger.info('✅ Desktop server mode started - waiting for client connections');
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

  @override
  Future<void> startSync() async {
    await _startCurrentMode();
  }

  @override
  void stopSync() {
    // Run the async cleanup in a background task
    // Note: This means the caller can't wait for cleanup to complete
    _stopCurrentMode();
  }

  @override
  void dispose() {
    Logger.debug('🗑️ Disposing DesktopSyncService');
    try {
      _stopCurrentMode();
    } catch (e) {
      Logger.error('❌ Error during disposal cleanup: $e');
    }
    super.dispose();
  }

  /// Check if the service is currently switching modes
  bool get isModeSwitching => _isModeSwitching;
}
