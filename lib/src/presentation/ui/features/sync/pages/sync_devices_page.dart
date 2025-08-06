import 'dart:io';
import 'dart:async';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/src/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/sync/components/sync_qr_scan_button.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/features/sync/components/sync_qr_code_button.dart';
import 'package:whph/src/presentation/ui/shared/components/help_menu.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/src/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/src/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/src/core/application/features/sync/models/sync_status.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/src/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';

class SyncDevicesPage extends StatefulWidget {
  static const route = '/sync-devices';

  const SyncDevicesPage({super.key});

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  static const String _serverModeSettingKey = 'sync_server_mode_enabled';

  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _settingRepository = container.resolve<ISettingRepository>();
  late final ISyncService _syncService;
  AndroidServerSyncService? _serverSyncService;

  GetListSyncDevicesQueryResponse? list;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;
  SyncStatus _currentSyncStatus = const SyncStatus(state: SyncState.idle);
  bool _isServerMode = false;
  late AnimationController _syncIconAnimationController;
  late AnimationController _syncButtonAnimationController;
  
  // Server mode specific sync tracking
  bool _isServerSyncActive = false;
  Timer? _syncStatusDebounceTimer;
  SyncState? _lastProcessedState;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // CRITICAL: Use the same sync service instance from container
    // This ensures we listen to the same stream that's being updated
    _syncService = container.resolve<ISyncService>();
    if (Platform.isAndroid) {
      _serverSyncService = container.resolve<AndroidServerSyncService>();
    }

    // Desktop is always in server mode (passive)
    if (PlatformUtils.isDesktop) {
      _isServerMode = true;
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
    _loadServerModePreference();
    refresh();
  }

  /// Load server mode preference and sync UI state
  Future<void> _loadServerModePreference() async {
    if (!Platform.isAndroid || _serverSyncService == null) return;

    try {
      // Check if server is already running (started by platform initialization)
      final isServerRunning = _serverSyncService!.isServerMode;

      if (isServerRunning && mounted) {
        setState(() {
          _isServerMode = true;
        });
        Logger.info('📱 Server mode already running from platform initialization');
      } else {
        // Fallback: check preference and start if needed
        final setting = await _settingRepository.getByKey(_serverModeSettingKey);
        final shouldStartServer = setting?.getValue<bool>() ?? false;

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
        Logger.debug('📡 Sync status received: ${status.state} (manual: ${status.isManual})');

        if (_isServerMode) {
          _handleServerModeSyncStatusWithDebounce(status);
        } else {
          // For client mode, always update UI for any sync status change
          setState(() {});
          _handleSyncStatusChange(status);
        }
      }
    });
    
    Logger.debug('✅ Sync status listener setup completed');
  }

  void _handleServerModeSyncStatusWithDebounce(SyncStatus status) {
    // Cancel any existing debounce timer
    _syncStatusDebounceTimer?.cancel();
    
    // For server mode, only process meaningful state changes
    if (status.state == _lastProcessedState) {
      return; // Ignore duplicate states
    }

    Logger.debug('🔄 Server sync status: ${status.state} (last: $_lastProcessedState)');

    // Handle immediate state changes
    if (status.state == SyncState.syncing && !_isServerSyncActive) {
      // Start sync immediately
      _isServerSyncActive = true;
      _syncIconAnimationController.repeat();
      _lastProcessedState = status.state;
      setState(() {});
      Logger.debug('🔄 Server sync animation started immediately');
      return;
    }

    // Debounce other state changes to prevent flicker
    _syncStatusDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _processServerSyncStatusChange(status);
      }
    });
  }

  void _processServerSyncStatusChange(SyncStatus status) {
    final previousState = _lastProcessedState;
    _lastProcessedState = status.state;

    switch (status.state) {
      case SyncState.syncing:
        // Already handled immediately above
        break;

      case SyncState.idle:
        if (_isServerSyncActive) {
          _isServerSyncActive = false;
          _syncIconAnimationController.stop();
          _syncIconAnimationController.reset();
          setState(() {});
          Logger.debug('✅ Server sync animation stopped ($previousState → ${status.state})');
          refresh(); // Refresh device list
        }
        break;

      case SyncState.completed:
      case SyncState.error:
        // Ignore intermediate states completely
        Logger.debug('🔄 Server sync intermediate state ignored: ${status.state}');
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

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    _syncStatusDebounceTimer?.cancel();
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

    if (!Platform.isAndroid) {
      Logger.warning('Sync is only supported on Android platform');
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
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
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
          // Sync status indicator - only show in server mode when actually syncing
          if (_isServerSyncActive && _isServerMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildSyncStatusIndicator(),
            ),

          // Sync Now button - only show in client mode (quick access)
          if (!_isServerMode)
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

          // Mobile sync mode controls
          if (Platform.isAndroid) ...[
            // Direct server mode toggle button
            IconButton(
              onPressed: _toggleServerMode,
              icon: Icon(
                _isServerMode ? Icons.stop : Icons.wifi_tethering,
              ),
              color: _isServerMode ? Colors.red : Theme.of(context).colorScheme.primary,
              tooltip: _isServerMode
                  ? _translationService.translate(SyncTranslationKeys.serverModeStopTooltip)
                  : _translationService.translate(SyncTranslationKeys.serverModeStartTooltip),
            ),

            // Show QR code if in server mode, otherwise show scanner
            if (_isServerMode)
              SyncQrCodeButton()
            else
              SyncQrScanButton(
                onSyncComplete: refresh,
              ),
          ],

          // Desktop QR code (existing behavior)
          if (PlatformUtils.isDesktop) SyncQrCodeButton(),
          HelpMenu(
            titleKey: SyncTranslationKeys.helpTitle,
            markdownContentKey: SyncTranslationKeys.helpContent,
          ),
        ],
      ),
      body: list == null || list!.items.isEmpty
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
    );
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
    return Row(
      children: [
        Icon(Icons.sync_alt, size: AppTheme.iconSizeSmall, color: Theme.of(context).primaryColor),
        SizedBox(width: AppTheme.sizeXSmall),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              '${widget.item.fromIP} - ${widget.item.toIP}',
              style: AppTheme.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
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