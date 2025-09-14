import 'dart:io';
import 'dart:async';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_connect_info_button.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/features/sync/components/firewall_permission_card.dart';
import 'package:whph/presentation/ui/features/sync/pages/add_sync_device_page.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_sync_service.dart';
import 'package:whph/presentation/ui/features/sync/components/manual_connection_dialog.dart';

class SyncDevicesPage extends StatefulWidget {
  static const route = '/sync-devices';

  const SyncDevicesPage({super.key});

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  static const String _serverModeSettingKey = 'sync_server_mode_enabled';
  static const String _desktopSyncModeSettingKey = 'desktop_sync_mode';
  static const String _desktopServerAddressSettingKey = 'desktop_server_address';
  static const String _desktopServerPortSettingKey = 'desktop_server_port';

  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _settingRepository = container.resolve<ISettingRepository>();
  late final ISyncService _syncService;
  AndroidServerSyncService? _serverSyncService;

  // Server sync event tracking
  StreamSubscription<dynamic>? _serverSyncEventSubscription;

  // Server sync timeout tracking
  Timer? _serverSyncTimeoutTimer;
  DateTime? _lastSyncActivityTime;

  GetListSyncDevicesQueryResponse? list;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;
  SyncStatus _currentSyncStatus = const SyncStatus(state: SyncState.idle);
  bool _isServerMode = false;
  late AnimationController _syncIconAnimationController;
  late AnimationController _syncButtonAnimationController;

  // Server mode specific sync tracking
  // _isServerSyncActive: true only during actual sync activities (not just when server is running)
  bool _isServerSyncActive = false;
  Timer? _syncStatusDebounceTimer;
  SyncState? _lastProcessedState;

  // Desktop sync mode management
  DesktopSyncService? _desktopSyncService;
  DesktopSyncMode _desktopSyncMode = DesktopSyncMode.server;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // CRITICAL: Use the same sync service instance from container
    // This ensures we listen to the same stream that's being updated
    _syncService = container.resolve<ISyncService>();
    Logger.info('📡 SyncDevicesPage: Resolved sync service: ${_syncService.runtimeType}');

    if (Platform.isAndroid) {
      _serverSyncService = container.resolve<AndroidServerSyncService>();
      Logger.info('📡 SyncDevicesPage: Resolved server sync service: ${_serverSyncService.runtimeType}');

      // Check if they are the same instance
      if (_syncService == _serverSyncService) {
        Logger.info('📡 SyncDevicesPage: ✅ Same instance - sync status will work');
      } else {
        Logger.warning('📡 SyncDevicesPage: ❌ Different instances - sync status may not work!');
        Logger.info('📡 SyncDevicesPage: _syncService = $_syncService');
        Logger.info('📡 SyncDevicesPage: _serverSyncService = $_serverSyncService');
      }
    }

    // Initialize desktop sync service for enhanced mode switching
    if (PlatformUtils.isDesktop) {
      _desktopSyncService = _syncService as DesktopSyncService;
      _desktopSyncMode = _desktopSyncService!.currentMode;
      _isServerMode = _desktopSyncMode == DesktopSyncMode.server;
      Logger.info('🖥️ Desktop sync mode initialized: $_desktopSyncMode, serverMode: $_isServerMode');
    } else if (Platform.isAndroid) {
      Logger.info('📱 Android platform detected - will check server mode in _loadServerModePreference');
    }

    // Initialize sync icon animation controller
    _syncIconAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    // Initialize sync button animation controller
    _syncButtonAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _setupSyncStatusListener();
    _setupServerSyncStatusListener(); // Additional listener for Android server
    _loadServerModePreference();
    _loadDesktopSyncModePreference();
    refresh();
  }

  /// Load server mode preference and sync UI state
  Future<void> _loadServerModePreference() async {
    if (!Platform.isAndroid || _serverSyncService == null) return;

    try {
      // Check if server is already running (started by platform initialization)
      final isServerRunning = _serverSyncService!.isServerMode;
      Logger.info('📱 Android server mode check: isServerRunning=$isServerRunning');

      if (isServerRunning && mounted) {
        setState(() {
          _isServerMode = true;
        });
        Logger.info('📱 Server mode already running from platform initialization - UI updated to server mode');
      } else {
        // Fallback: check preference and start if needed
        final setting = await _settingRepository.getByKey(_serverModeSettingKey);
        final shouldStartServer = setting?.getValue<bool>() ?? false;
        Logger.info('📱 Server mode preference check: shouldStartServer=$shouldStartServer');

        if (shouldStartServer) {
          Logger.info('🔄 Auto-starting server mode from saved preference');
          await _startServerModeFromPreference();
        }
      }
    } catch (e) {
      Logger.error('Failed to load server mode preference: $e');
    }
  }

  /// Start server mode without UI notifications (for auto-start)
  Future<void> _startServerModeFromPreference() async {
    if (_serverSyncService == null) return;

    try {
      final success = await _serverSyncService!.startAsServer();

      if (success && mounted) {
        setState(() {
          _isServerMode = true;
        });
        Logger.info('✅ Server mode auto-started successfully');
      } else {
        Logger.warning('❌ Failed to auto-start server mode');
      }
    } catch (e) {
      Logger.error('Error auto-starting server mode: $e');
    }
  }

  void _setupSyncStatusListener() {
    Logger.debug('🔧 Setting up sync status listener for ${_isServerMode ? "server" : "client"} mode');

    _syncStatusSubscription = _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        _currentSyncStatus = status;
        Logger.info(
            '📡 Sync status received: ${status.state} (manual: ${status.isManual}) - serverMode: $_isServerMode, syncActive: $_isServerSyncActive');

        // Update last sync activity time ONLY for actual sync events in server mode
        if (_isServerMode && status.state == SyncState.syncing) {
          _lastSyncActivityTime = DateTime.now();
          Logger.info('📡 Server sync event (${status.state}) - resetting inactivity timer');
        } else if (_isServerMode && status.state == SyncState.idle) {
          Logger.info('📡 Server idle event received - sync activity ended');
        }

        if (_isServerMode) {
          Logger.info('📡 Processing in SERVER MODE - calling debounce handler');
          _handleServerModeSyncStatusWithDebounce(status);
        } else {
          Logger.info('📡 Processing in CLIENT MODE - updating UI directly');
          // For client mode, always update UI for any sync status change
          setState(() {});
          _handleSyncStatusChange(status);
        }
      } else {
        Logger.warning('📡 Sync status received but widget not mounted - ignoring');
      }
    });

    // Setup server sync monitoring for Android
    if (Platform.isAndroid && _serverSyncService != null) {
      _setupServerSyncMonitoring();
    }

    Logger.debug('✅ Sync status listener setup completed');
  }

  void _setupServerSyncStatusListener() {
    if (!Platform.isAndroid || _serverSyncService == null) return;

    Logger.info('🔧 Setting up additional Android server sync status listener');

    // Listen to server sync service's own sync status stream if it's different from main service
    if (_serverSyncService != _syncService) {
      Logger.info('📡 Server sync service is different from main sync service - setting up additional listener');

      _serverSyncEventSubscription = _serverSyncService!.syncStatusStream.listen((status) {
        if (mounted) {
          Logger.info(
              '📡 Server sync status received from AndroidServerSyncService: ${status.state} (manual: ${status.isManual})');

          // Forward to main sync service to ensure UI gets updated
          _syncService.updateSyncStatus(status);
        }
      });
    } else {
      Logger.info('📡 Server sync service is same as main sync service - no additional listener needed');
    }
  }

  void _handleServerModeSyncStatusWithDebounce(SyncStatus status) {
    // Cancel any existing debounce timer
    _syncStatusDebounceTimer?.cancel();

    Logger.info(
        '📡 Server mode sync status update: ${status.state} (manual: ${status.isManual}, serverMode: $_isServerMode, active: $_isServerSyncActive)');

    // Handle syncing state immediately - this is the critical path for starting animation
    if (status.state == SyncState.syncing) {
      Logger.info('🔄 SYNCING state detected in server mode');
      if (!_isServerSyncActive) {
        Logger.info('🔄 Starting server sync animation - was not active before');
        _isServerSyncActive = true;
        _syncIconAnimationController.repeat();
        setState(() {});
        Logger.info('🔄 Server sync animation started - real sync activity detected');
      } else {
        Logger.info('🔄 Server sync animation already active - continuing');
      }
      // Reset inactivity timer only on actual sync events
      _lastSyncActivityTime = DateTime.now();

      // For syncing state, don't update lastProcessedState yet to allow continuous updates
      // but still debounce to prevent excessive setState calls
      _syncStatusDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted && status.state == SyncState.syncing) {
          _lastProcessedState = status.state;
        }
      });
      return;
    }

    // For non-syncing states, use debouncing to prevent UI flicker
    if (status.state != _lastProcessedState) {
      Logger.info('📡 Non-syncing state (${status.state}) - scheduling debounced processing');
      _syncStatusDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _processServerSyncStatusChange(status);
        }
      });
    } else {
      Logger.info('📡 Same state as last processed (${status.state}) - ignoring');
    }
  }

  void _processServerSyncStatusChange(SyncStatus status) {
    final previousState = _lastProcessedState;
    _lastProcessedState = status.state;

    Logger.info(
        '📡 Processing server sync status change: $previousState → ${status.state} (serverMode: $_isServerMode, active: $_isServerSyncActive)');

    switch (status.state) {
      case SyncState.syncing:
        // Already handled immediately in the debounce handler
        break;

      case SyncState.idle:
        if (_isServerSyncActive) {
          _isServerSyncActive = false;
          _syncIconAnimationController.stop();
          _syncIconAnimationController.reset();
          setState(() {});
          Logger.info('✅ Server sync animation stopped - sync activity ended ($previousState → ${status.state})');
          refresh(); // Refresh device list
        }
        break;

      case SyncState.completed:
      case SyncState.error:
        // For server mode, treat completion and error as end of sync
        if (_isServerSyncActive) {
          _isServerSyncActive = false;
          _syncIconAnimationController.stop();
          _syncIconAnimationController.reset();
          setState(() {});

          if (status.state == SyncState.completed) {
            Logger.info('✅ Server sync completed successfully ($previousState → ${status.state})');
            refresh(); // Refresh device list
          } else {
            Logger.info('❌ Server sync error occurred ($previousState → ${status.state})');
          }
        }
        break;
    }
  }

  void _handleSyncStatusChange(SyncStatus status) {
    // Client mode handling - handle ALL sync types for UI consistency
    Logger.debug('🔄 Client sync status change: ${status.state} (manual: ${status.isManual})');

    switch (status.state) {
      case SyncState.syncing:
        // Start sync button animation for ANY sync (manual, background, pairing, etc.)
        if (!_syncButtonAnimationController.isAnimating) {
          _syncButtonAnimationController.repeat();
          Logger.debug('🔄 Client sync button animation started (manual: ${status.isManual})');
        }

        // Show overlay notification ONLY for manual syncs in client mode
        if (status.isManual) {
          OverlayNotificationHelper.showLoading(
            context: context,
            message: _translationService.translate(SyncTranslationKeys.syncInProgress),
            duration: const Duration(seconds: 30),
          );
        }
        break;

      case SyncState.completed:
      case SyncState.error:
      case SyncState.idle:
        // Stop sync button animation for ANY sync completion
        if (_syncButtonAnimationController.isAnimating) {
          _syncButtonAnimationController.stop();
          _syncButtonAnimationController.reset();
          Logger.debug('✅ Client sync button animation stopped (${status.state}, manual: ${status.isManual})');
        }

        // Handle notifications ONLY for manual syncs
        if (status.isManual) {
          OverlayNotificationHelper.hideNotification();

          if (status.state == SyncState.completed) {
            OverlayNotificationHelper.showSuccess(
              context: context,
              message: _translationService.translate(SyncTranslationKeys.syncCompleted),
              duration: const Duration(seconds: 3),
            );
          } else if (status.state == SyncState.error) {
            OverlayNotificationHelper.showError(
              context: context,
              message: _translationService.translate(SyncTranslationKeys.syncDevicesError),
              duration: const Duration(seconds: 3),
            );
          }
        }

        // Refresh device list on ANY sync completion
        if (status.state == SyncState.completed) {
          Future.delayed(const Duration(milliseconds: 100), () {
            refresh();
          });
        }
        break;
    }
  }

  void _setupServerSyncMonitoring() {
    if (_serverSyncService == null) return;

    Logger.info('🔧 Setting up Android server sync monitoring - animation only on real sync activity');

    // Monitor server status and sync activity timeout
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final isServerRunning = _serverSyncService!.isServerMode;

        if (isServerRunning && _isServerMode) {
          // Server is running - only check for sync activity timeout, don't start animation just because server is ready
          if (_isServerSyncActive && _lastSyncActivityTime != null) {
            final now = DateTime.now();
            final inactivityTimeout = const Duration(seconds: 30); // Timeout after sync events

            // Check for full inactivity timeout (30s after last sync activity)
            if (now.difference(_lastSyncActivityTime!) > inactivityTimeout) {
              Logger.info(
                  '🛑 Server sync timeout - no activity for ${inactivityTimeout.inSeconds}s, stopping animation');
              _handleServerSyncStop();
            }
          }
        } else {
          // Server not running or not in server mode - stop animation
          if (_isServerSyncActive) {
            Logger.info('🛑 Stopping server sync animation - server not active');
            _handleServerSyncStop();
          }
        }
      } catch (e) {
        Logger.debug('Server monitoring error: $e');
      }
    });

    // Don't start animation automatically when server starts - wait for actual sync activity
    Logger.info('✅ Android server sync monitoring active - animation starts only on real sync events');
  }

  void _handleServerSyncStop() {
    _isServerSyncActive = false;
    _lastSyncActivityTime = null;

    if (_syncIconAnimationController.isAnimating) {
      _syncIconAnimationController.stop();
      _syncIconAnimationController.reset();
    }

    if (mounted) {
      setState(() {});
    }

    // Cancel timeout timer
    _serverSyncTimeoutTimer?.cancel();
    _serverSyncTimeoutTimer = null;

    // Emit idle status
    _syncService.updateSyncStatus(const SyncStatus(state: SyncState.idle, isManual: false));

    Logger.info('🛑 Server sync animation stopped - sync activity ended');
  }

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    _serverSyncEventSubscription?.cancel();
    _syncStatusDebounceTimer?.cancel();
    _serverSyncTimeoutTimer?.cancel();
    _syncIconAnimationController.dispose();
    _syncButtonAnimationController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    await _getDevices(pageIndex: 0, pageSize: 10);
  }

  Future<void> _getDevices({required int pageIndex, required int pageSize}) async {
    await AsyncErrorHandler.execute<GetListSyncDevicesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.loadDevicesError),
      operation: () async {
        final query = GetListSyncDevicesQuery(pageIndex: pageIndex, pageSize: pageSize);
        return await _mediator.send<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse>(query);
      },
      onSuccess: (response) {
        if (mounted) {
          setState(() {
            list = response;
          });
        }
      },
    );
  }

  Future<void> _sync() async {
    // Only allow sync in client mode
    if (_isServerMode) {
      Logger.warning('Sync cannot be initiated in server mode');
      return;
    }

    if (_currentSyncStatus.isSyncing) return;

    try {
      // Simulate device-specific sync progress for UI feedback
      _simulateDeviceSpecificSync();

      // Use the centralized sync service for manual sync trigger
      await _syncService.runSync(isManual: true);
    } catch (e) {
      Logger.error('Manual sync failed: $e');
    }
  }

  void _simulateDeviceSpecificSync() {
    if (list == null || list!.items.isEmpty) return;

    int currentDeviceIndex = 0;

    // Start with first device
    if (list!.items.isNotEmpty) {
      _syncService.updateSyncStatus(_currentSyncStatus.copyWith(
        currentDeviceId: list!.items[0].id,
      ));
    }

    // Simulate individual device sync progress
    Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_currentSyncStatus.isSyncing) {
        timer.cancel();
        return;
      }

      currentDeviceIndex++;
      if (currentDeviceIndex < list!.items.length) {
        final device = list!.items[currentDeviceIndex];
        _syncService.updateSyncStatus(_currentSyncStatus.copyWith(
          currentDeviceId: device.id,
        ));
      } else {
        // Clear current device when sync is completing
        _syncService.updateSyncStatus(_currentSyncStatus.copyWith(
          currentDeviceId: null,
        ));
        timer.cancel();
      }
    });
  }

  Future<void> _removeDevice(String id) async {
    await AsyncErrorHandler.execute<void>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.removeDeviceError),
      operation: () async {
        final command = DeleteSyncDeviceCommand(id: id);
        await _mediator.send<DeleteSyncDeviceCommand, void>(command);
        return;
      },
      onSuccess: (_) {
        if (mounted) {
          setState(() {
            list!.items.removeWhere((item) => item.id == id);
          });
        }
      },
    );
  }

  Future<void> _toggleServerMode() async {
    if (!Platform.isAndroid || _serverSyncService == null) return;

    try {
      if (_isServerMode) {
        // Stop server mode
        Logger.info('🛑 Stopping mobile sync server mode...');
        await _serverSyncService!.stopServer();

        // Save preference: server mode disabled
        await _saveServerModePreference(false);

        setState(() {
          _isServerMode = false;
        });

        if (mounted) {
          OverlayNotificationHelper.showInfo(
            context: context,
            message: _translationService.translate(SyncTranslationKeys.serverModeStopped),
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // Start server mode
        Logger.info('🚀 Starting mobile sync server mode...');

        if (mounted) {
          OverlayNotificationHelper.showLoading(
            context: context,
            message: _translationService.translate(SyncTranslationKeys.serverModeStarting),
            duration: const Duration(seconds: 10),
          );
        }

        final success = await _serverSyncService!.startAsServer();

        if (mounted) {
          OverlayNotificationHelper.hideNotification();

          if (success) {
            // Save preference: server mode enabled
            await _saveServerModePreference(true);

            setState(() {
              _isServerMode = true;
            });

            if (mounted) {
              OverlayNotificationHelper.showSuccess(
                context: context,
                message: _translationService.translate(SyncTranslationKeys.serverModeActive),
                duration: const Duration(seconds: 4),
              );
            }
          } else {
            OverlayNotificationHelper.showError(
              context: context,
              message: _translationService.translate(SyncTranslationKeys.serverModeStartFailed),
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
    } catch (e) {
      Logger.error('Error toggling server mode: $e');
      if (mounted) {
        OverlayNotificationHelper.hideNotification();
        OverlayNotificationHelper.showError(
          context: context,
          message: '${_translationService.translate(SyncTranslationKeys.serverModeError)}: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  /// Save server mode preference to settings
  Future<void> _saveServerModePreference(bool enabled) async {
    try {
      final command = SaveSettingCommand(
        key: _serverModeSettingKey,
        value: enabled.toString(),
        valueType: SettingValueType.bool,
      );

      await _mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(command);
      Logger.debug('📝 Server mode preference saved: $enabled');
    } catch (e) {
      Logger.error('Failed to save server mode preference: $e');
    }
  }

  /// Show the Add Sync Device page using ResponsiveDialogHelper
  Future<void> _showAddDevicePage() async {
    final result = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.large,
      child: AddSyncDevicePage(
        onDeviceAdded: () {
          Logger.info('Device added from AddSyncDevicePage - refreshing device list');
          // Refresh device list to show the new device
          if (mounted) {
            refresh();
          }
        },
      ),
    );

    if (result == true && mounted) {
      Logger.info('AddSyncDevicePage completed successfully - performing final refresh');
      // Additional refresh to ensure the list is up to date
      await refresh();
    }
  }

  Widget _buildSyncStatusIndicator() {
    return AnimatedBuilder(
      animation: _syncIconAnimationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _syncIconAnimationController.value * 2 * 3.14159,
          child: child,
        );
      },
      child: Icon(
        Icons.sync,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Use a standard Scaffold instead of ResponsiveScaffoldLayout
    // This makes the page more compatible when displayed in dialogs/bottom sheets
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(_translationService.translate(SyncTranslationKeys.pageTitle)),
        actions: [
          // Sync status indicator - only show in server mode during actual sync activity
          if (_isServerMode && _isServerSyncActive) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildSyncStatusIndicator(),
            ),
          ] else if (_isServerMode) ...[
            // Debug: Show when server mode is active but sync is not active
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                Icons.wifi_tethering,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
          ],

          // Sync button - behavior depends on mode
          // Client mode: clickable sync button with animation during sync
          // Server mode: non-clickable icon that only shows animation during actual sync activity
          if (!_isServerMode && (list?.items.isNotEmpty ?? false))
            IconButton(
              onPressed: _currentSyncStatus.isSyncing ? null : _sync,
              icon: _currentSyncStatus.isSyncing
                  ? AnimatedBuilder(
                      animation: _syncButtonAnimationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _syncButtonAnimationController.value * 2 * 3.14159,
                          child: const Icon(Icons.sync),
                        );
                      },
                    )
                  : const Icon(Icons.sync),
              color: _currentSyncStatus.isSyncing
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                  : Theme.of(context).colorScheme.primary,
              tooltip: _currentSyncStatus.isSyncing
                  ? _translationService.translate(SyncTranslationKeys.syncInProgress)
                  : _translationService.translate(SyncTranslationKeys.syncTooltip),
            ),

          // Add Device button - only show when not in server mode
          if (!_isServerMode)
            IconButton(
              onPressed: _showAddDevicePage,
              icon: const Icon(Icons.add),
              color: Theme.of(context).colorScheme.primary,
              tooltip: _translationService.translate(SyncTranslationKeys.addDeviceTooltip),
            ),

          // Connection Info Button - show only when in server mode
          if (_isServerMode) SyncConnectInfoButton(),

          // Kebab menu containing help, and mobile sync controls
          KebabMenu(
            helpTitleKey: SharedTranslationKeys.helpTooltip,
            helpMarkdownContentKey: SyncTranslationKeys.helpContent,
            additionalMenuItems: [
              // Mobile sync mode toggle (only on Android)
              if (Platform.isAndroid)
                PopupMenuItem<String>(
                  value: 'toggle_server',
                  child: Row(
                    children: [
                      Icon(_isServerMode ? Icons.stop : Icons.wifi_tethering,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(_isServerMode
                          ? _translationService.translate(SyncTranslationKeys.serverModeStopMenu)
                          : _translationService.translate(SyncTranslationKeys.serverModeStartMenu)),
                    ],
                  ),
                ),
              // Desktop sync mode toggle (only on Desktop) - matches mobile pattern
              if (PlatformUtils.isDesktop)
                PopupMenuItem<String>(
                  value: 'toggle_client',
                  child: Row(
                    children: [
                      Icon(_desktopSyncMode == DesktopSyncMode.client ? Icons.stop : Icons.wifi_tethering,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(_desktopSyncMode == DesktopSyncMode.client
                          ? _translationService.translate(SyncTranslationKeys.desktopSyncModeStopMenu)
                          : _translationService.translate(SyncTranslationKeys.desktopSyncModeStartMenu)),
                    ],
                  ),
                ),
            ],
            onMenuItemSelected: (value) {
              switch (value) {
                case 'toggle_server':
                  // Toggle server mode
                  _toggleServerMode();
                  break;
                case 'toggle_client':
                  // Toggle desktop sync mode
                  _toggleDesktopSyncMode();
                  break;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Firewall permission card (desktop only)
          const FirewallPermissionCard(),

          // Device list content
          Expanded(
            child: list == null || list!.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(0),
                    child: IconOverlay(
                      icon: Icons.devices_other,
                      message: _translationService.translate(SyncTranslationKeys.noDevicesFound),
                    ),
                  )
                : ListView.separated(
                    itemCount: list!.items.length,
                    padding: EdgeInsets.all(AppTheme.sizeSmall),
                    itemBuilder: (context, index) {
                      return SyncDeviceListItemWidget(
                        key: ValueKey(list!.items[index].id),
                        item: list!.items[index],
                        onRemove: _removeDevice,
                        isBeingSynced:
                            _currentSyncStatus.isSyncing && _currentSyncStatus.currentDeviceId == list!.items[index].id,
                      );
                    },
                    separatorBuilder: (context, index) => const SizedBox(height: AppTheme.sizeSmall),
                  ),
          ),
        ],
      ),
    );
  }

  /// Toggle desktop sync mode between server (default) and client mode - like mobile toggle
  Future<void> _toggleDesktopSyncMode() async {
    if (!PlatformUtils.isDesktop || _desktopSyncService == null) return;

    try {
      if (_desktopSyncMode == DesktopSyncMode.client) {
        // Stop client mode - switch back to server mode (default)
        Logger.info('🛑 Stopping desktop client mode...');

        await _desktopSyncService!.switchToMode(DesktopSyncMode.server);

        // Save server mode preference
        await _saveDesktopSyncModePreference(DesktopSyncMode.server);

        setState(() {
          _desktopSyncMode = DesktopSyncMode.server;
          _isServerMode = true;
        });

        if (mounted) {
          OverlayNotificationHelper.showInfo(
            context: context,
            message: _translationService.translate(SyncTranslationKeys.desktopClientModeStopped),
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // Start client mode - try to connect to saved server or default
        Logger.info('🚀 Starting desktop client mode...');

        if (mounted) {
          OverlayNotificationHelper.showLoading(
            context: context,
            message: _translationService.translate(SyncTranslationKeys.desktopClientModeStarting),
            duration: const Duration(seconds: 5),
          );
        }

        // Load saved server settings - required for client mode
        String? serverAddress;
        int serverPort = 44040;

        try {
          final addressSetting = await _settingRepository.getByKey(_desktopServerAddressSettingKey);
          final portSetting = await _settingRepository.getByKey(_desktopServerPortSettingKey);

          if (addressSetting != null && portSetting != null) {
            serverAddress = addressSetting.value;
            serverPort = int.tryParse(portSetting.value) ?? 44040;
          }
        } catch (e) {
          Logger.warning('Could not load saved server settings: $e');
        }

        // If no saved server settings, show manual connection dialog to configure server
        if (serverAddress == null || serverAddress.isEmpty) {
          if (mounted) {
            OverlayNotificationHelper.hideNotification();

            // Show manual connection dialog instead of just an error
            final shouldConnect = await _showManualConnectionDialog();
            if (!shouldConnect) {
              if (mounted) {
                OverlayNotificationHelper.showInfo(
                  context: context,
                  message: _translationService.translate(SyncTranslationKeys.cancel), // Use existing translation
                  duration: const Duration(seconds: 3),
                );
              }
              return;
            }

            // If connection was successful, get the newly saved settings
            try {
              final addressSetting = await _settingRepository.getByKey(_desktopServerAddressSettingKey);
              final portSetting = await _settingRepository.getByKey(_desktopServerPortSettingKey);

              if (addressSetting != null && portSetting != null) {
                serverAddress = addressSetting.value;
                serverPort = int.tryParse(portSetting.value) ?? 44040;
              } else {
                if (mounted) {
                  OverlayNotificationHelper.showError(
                    context: context,
                    message: _translationService.translate(SyncTranslationKeys.noServerConfiguredError),
                    duration: const Duration(seconds: 5),
                  );
                }
                return;
              }
            } catch (e) {
              Logger.error('Failed to load server settings after configuration: $e');
              return;
            }
          } else {
            return;
          }
        }

        await _desktopSyncService!.switchToClientMode(serverAddress, serverPort);

        // Save client mode preference
        await _saveDesktopSyncModePreference(DesktopSyncMode.client,
            serverAddress: serverAddress, serverPort: serverPort);

        setState(() {
          _desktopSyncMode = DesktopSyncMode.client;
          _isServerMode = false;
        });

        if (mounted) {
          OverlayNotificationHelper.hideNotification();
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: _translationService.translate(SyncTranslationKeys.desktopClientModeStarted),
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      Logger.error('Failed to toggle desktop sync mode: $e');

      // Hide loading and show error
      if (mounted) {
        OverlayNotificationHelper.hideNotification();
        OverlayNotificationHelper.showError(
          context: context,
          message: 'Failed to switch sync mode: $e',
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  /// Load desktop sync mode preference from settings
  Future<void> _loadDesktopSyncModePreference() async {
    if (!PlatformUtils.isDesktop || _desktopSyncService == null) return;

    try {
      // Load sync mode preference
      final syncModeSetting = await _settingRepository.getByKey(_desktopSyncModeSettingKey);
      if (syncModeSetting != null) {
        final modeValue = syncModeSetting.value;
        final mode = DesktopSyncMode.values.firstWhere(
          (m) => m.name == modeValue,
          orElse: () => DesktopSyncMode.server,
        );

        // Load server connection settings if in client mode
        if (mode == DesktopSyncMode.client) {
          final addressSetting = await _settingRepository.getByKey(_desktopServerAddressSettingKey);
          final portSetting = await _settingRepository.getByKey(_desktopServerPortSettingKey);

          if (addressSetting != null && portSetting != null) {
            final address = addressSetting.value;
            final port = int.tryParse(portSetting.value) ?? 44040;

            // Switch to client mode with saved server info
            await _desktopSyncService!.switchToClientMode(address, port);
          }
        } else {
          // Switch to server mode
          await _desktopSyncService!.switchToMode(mode);
        }

        setState(() {
          _desktopSyncMode = mode;
          _isServerMode = mode == DesktopSyncMode.server;
        });
      }
    } catch (e) {
      Logger.error('Failed to load desktop sync mode preference: $e');
    }
  }

  /// Show manual connection dialog for configuring desktop client mode
  Future<bool> _showManualConnectionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManualConnectionDialog(
        onConnect: (deviceInfo) async {
          // Save the connection details to settings for desktop client mode
          try {
            await _mediator.send(SaveSettingCommand(
              key: _desktopServerAddressSettingKey,
              value: deviceInfo.ipAddress,
              valueType: SettingValueType.string,
            ));

            await _mediator.send(SaveSettingCommand(
              key: _desktopServerPortSettingKey,
              value: deviceInfo.port.toString(),
              valueType: SettingValueType.int,
            ));

            Logger.info('✅ Saved server connection details: ${deviceInfo.ipAddress}:${deviceInfo.port}');
          } catch (e) {
            Logger.error('Failed to save connection details: $e');
          }
        },
        onCancel: () {
          Logger.info('Manual connection dialog cancelled');
        },
      ),
    );

    return result == true;
  }

  /// Save desktop sync mode preference to settings
  Future<void> _saveDesktopSyncModePreference(DesktopSyncMode mode, {String? serverAddress, int? serverPort}) async {
    if (!PlatformUtils.isDesktop) return;

    try {
      // Save sync mode
      await _mediator.send(SaveSettingCommand(
        key: _desktopSyncModeSettingKey,
        value: mode.name,
        valueType: SettingValueType.string,
      ));

      // Save server connection info if in client mode
      if (mode == DesktopSyncMode.client && serverAddress != null && serverPort != null) {
        await _mediator.send(SaveSettingCommand(
          key: _desktopServerAddressSettingKey,
          value: serverAddress,
          valueType: SettingValueType.string,
        ));

        await _mediator.send(SaveSettingCommand(
          key: _desktopServerPortSettingKey,
          value: serverPort.toString(),
          valueType: SettingValueType.int,
        ));
      }
    } catch (e) {
      Logger.error('Failed to save desktop sync mode preference: $e');
    }
  }
}

class SyncDeviceListItemWidget extends StatefulWidget {
  final SyncDeviceListItem item;
  final void Function(String) onRemove;
  final bool isBeingSynced;

  const SyncDeviceListItemWidget({
    super.key,
    required this.item,
    required this.onRemove,
    this.isBeingSynced = false,
  });

  @override
  State<SyncDeviceListItemWidget> createState() => _SyncDeviceListItemWidgetState();
}

class _SyncDeviceListItemWidgetState extends State<SyncDeviceListItemWidget> with TickerProviderStateMixin {
  final _translationService = container.resolve<ITranslationService>();
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(SyncDeviceListItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBeingSynced && !oldWidget.isBeingSynced) {
      _rotationController.repeat();
    } else if (!widget.isBeingSynced && oldWidget.isBeingSynced) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _getFirstDeviceName() {
    // Extract first device name from the existing name format
    if (widget.item.name != null) {
      final name = widget.item.name!;
      // Handle all formats: "A - B", "A ↔ B", and "A > B"
      if (name.contains(' - ')) {
        final parts = name.split(' - ');
        return parts.isNotEmpty ? parts[0].trim() : _translationService.translate(SyncTranslationKeys.unnamedDevice);
      } else if (name.contains(' ↔ ')) {
        final parts = name.split(' ↔ ');
        return parts.isNotEmpty ? parts[0].trim() : _translationService.translate(SyncTranslationKeys.unnamedDevice);
      } else if (name.contains(' > ')) {
        final parts = name.split(' > ');
        return parts.isNotEmpty ? parts[0].trim() : _translationService.translate(SyncTranslationKeys.unnamedDevice);
      }
      // If no separator found, return the whole name
      return name;
    }
    return _translationService.translate(SyncTranslationKeys.unnamedDevice);
  }

  String _getPartnerDeviceName() {
    const String unknownDeviceName = '?';
    // Extract partner device name from the existing name format
    if (widget.item.name != null) {
      final name = widget.item.name!;
      // Handle all formats: "A - B", "A ↔ B", and "A > B"
      if (name.contains(' - ')) {
        final parts = name.split(' - ');
        return parts.length > 1 ? parts[1].trim() : unknownDeviceName;
      } else if (name.contains(' ↔ ')) {
        final parts = name.split(' ↔ ');
        return parts.length > 1 ? parts[1].trim() : unknownDeviceName;
      } else if (name.contains(' > ')) {
        final parts = name.split(' > ');
        return parts.length > 1 ? parts[1].trim() : unknownDeviceName;
      }
      // If no separator found, assume it's a single device name
      return unknownDeviceName;
    }
    return unknownDeviceName;
  }

  Widget _buildDeviceInfoRow() {
    // Enhanced device info to show connection details
    final fromIP = widget.item.fromIP;
    final toIP = widget.item.toIP;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sync_alt, size: AppTheme.iconSizeSmall, color: Theme.of(context).primaryColor),
            SizedBox(width: AppTheme.sizeXSmall),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  '$fromIP ↔ $toIP',
                  style: AppTheme.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Show additional connection info if available
        if (fromIP.contains(',') || toIP.contains(',')) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.network_check,
                  size: AppTheme.iconSizeXSmall,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
              SizedBox(width: AppTheme.sizeXSmall),
              Expanded(
                child: Text(
                  'Multi-interface connection',
                  style: AppTheme.labelXSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Stack(
        children: [
          ListTile(
            title: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.titleMedium,
                children: [
                  TextSpan(text: _getFirstDeviceName()),
                  TextSpan(
                    text: ' - ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: _getPartnerDeviceName()),
                ],
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unified device info display
                _buildDeviceInfoRow(),
                SizedBox(height: AppTheme.sizeXSmall),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: AppTheme.iconSizeSmall,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: AppTheme.sizeXSmall),
                    Expanded(
                      child: Text(
                        widget.item.lastSyncDate != null
                            ? DateTimeHelper.formatDateTimeMedium(widget.item.lastSyncDate,
                                locale: Localizations.localeOf(context))
                            : '-',
                        style: AppTheme.labelSmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => widget.onRemove(widget.item.id),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          // Animated sync icon overlay in top-right corner
          if (widget.isBeingSynced)
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * 3.14159,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sync,
                        size: AppTheme.iconSizeSmall,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
