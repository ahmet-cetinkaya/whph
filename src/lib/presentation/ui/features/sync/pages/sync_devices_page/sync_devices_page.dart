import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/core/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/sync/models/desktop_sync_mode.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/android/features/sync/android_server_sync_service.dart';
import 'package:whph/infrastructure/desktop/features/sync/desktop_sync_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_connect_info_button.dart';
import 'package:whph/presentation/ui/features/sync/components/firewall_permission_card/firewall_permission_card.dart';
import 'package:whph/presentation/ui/features/sync/components/sync_device_list_item/sync_device_list_item.dart';
import 'package:whph/presentation/ui/features/sync/pages/add_sync_device_page/add_sync_device_page.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/server_mode_mixin.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/desktop_sync_mode_mixin.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/mixins/sync_status_mixin.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/components/server_mode_toggle.dart';
import 'package:whph/presentation/ui/features/sync/pages/sync_devices_page/components/sync_devices_empty_state.dart';

/// Page for managing sync devices and server/client mode configuration.
class SyncDevicesPage extends StatefulWidget {
  static const route = '/sync-devices';

  const SyncDevicesPage({super.key});

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage>
    with
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin,
        ServerModeMixin,
        DesktopSyncModeMixin,
        SyncStatusMixin {
  // Services
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _settingRepository = container.resolve<ISettingRepository>();
  late final ISyncService _syncService;
  AndroidServerSyncService? _serverSyncService;
  DesktopSyncService? _desktopSyncService;

  // State
  GetListSyncDevicesQueryResponse? _list;
  SyncStatus _currentSyncStatus = const SyncStatus(state: SyncState.idle);
  late AnimationController _syncIconAnimationController;
  late AnimationController _syncButtonAnimationController;

  // Mixin service accessors
  @override
  Mediator get mediator => _mediator;
  @override
  ITranslationService get translationService => _translationService;
  @override
  ISettingRepository get settingRepository => _settingRepository;
  @override
  ISyncService get syncService => _syncService;
  @override
  AndroidServerSyncService? get serverSyncService => _serverSyncService;
  @override
  DesktopSyncService? get desktopSyncService => _desktopSyncService;
  @override
  AnimationController get syncIconAnimationController => _syncIconAnimationController;
  @override
  AnimationController get syncButtonAnimationController => _syncButtonAnimationController;
  @override
  SyncStatus get currentSyncStatus => _currentSyncStatus;
  @override
  set currentSyncStatus(SyncStatus value) => _currentSyncStatus = value;
  @override
  Future<void> Function() get onRefresh => refresh;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeAnimationControllers();
    _loadPreferences();
    setupSyncStatusListeners();
    refresh();
  }

  void _initializeServices() {
    // CRITICAL: Use the same sync service instance from container
    _syncService = container.resolve<ISyncService>();
    Logger.info('SyncDevicesPage: Resolved sync service: ${_syncService.runtimeType}');

    if (Platform.isAndroid) {
      _serverSyncService = container.resolve<AndroidServerSyncService>();
      Logger.info('SyncDevicesPage: Resolved server sync service: ${_serverSyncService.runtimeType}');

      if (_syncService == _serverSyncService) {
        Logger.info('SyncDevicesPage: Same instance - sync status will work');
      } else {
        Logger.warning('SyncDevicesPage: Different instances - sync status may not work!');
      }
    }

    // Initialize desktop sync service for enhanced mode switching
    if (PlatformUtils.isDesktop) {
      _desktopSyncService = _syncService as DesktopSyncService;
      desktopSyncMode = _desktopSyncService!.currentMode;
      isServerMode = desktopSyncMode == DesktopSyncMode.server;
      Logger.info('Desktop sync mode initialized: $desktopSyncMode, serverMode: $isServerMode');
    } else if (Platform.isAndroid) {
      Logger.info('Android platform detected - will check server mode in loadServerModePreference');
    }
  }

  void _initializeAnimationControllers() {
    _syncIconAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _syncButtonAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  Future<void> _loadPreferences() async {
    await loadServerModePreference();
    await loadDesktopSyncModePreference();
  }

  @override
  void dispose() {
    disposeSyncStatusResources();
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
            _list = response;
          });
        }
      },
    );
  }

  Future<void> _sync() async {
    // Only allow sync in client mode
    if (isServerMode) {
      Logger.warning('Sync cannot be initiated in server mode');
      return;
    }

    if (_currentSyncStatus.isSyncing) return;

    try {
      _simulateDeviceSpecificSync();
      await _syncService.runSync(isManual: true);
    } catch (e) {
      Logger.error('Manual sync failed: $e');
    }
  }

  void _simulateDeviceSpecificSync() {
    if (_list == null || _list!.items.isEmpty) return;

    int currentDeviceIndex = 0;

    // Start with first device
    if (_list!.items.isNotEmpty) {
      _syncService.updateSyncStatus(_currentSyncStatus.copyWith(
        currentDeviceId: _list!.items[0].id,
      ));
    }

    // Simulate individual device sync progress
    Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_currentSyncStatus.isSyncing) {
        timer.cancel();
        return;
      }

      currentDeviceIndex++;
      if (currentDeviceIndex < _list!.items.length) {
        final device = _list!.items[currentDeviceIndex];
        _syncService.updateSyncStatus(_currentSyncStatus.copyWith(
          currentDeviceId: device.id,
        ));
      } else {
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
            _list!.items.removeWhere((item) => item.id == id);
          });
        }
      },
    );
  }

  Future<void> _showAddDevicePage() async {
    final result = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.max,
      child: AddSyncDevicePage(
        onDeviceAdded: () {
          Logger.info('Device added from AddSyncDevicePage - refreshing device list');
          if (mounted) {
            refresh();
          }
        },
      ),
    );

    if (result == true && mounted) {
      Logger.info('AddSyncDevicePage completed successfully - performing final refresh');
      await refresh();
    }
  }

  void _onFirewallPermissionChanged() {
    Logger.debug('Firewall permission status changed');
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

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(_translationService.translate(SyncTranslationKeys.pageTitle)),
        actions: _buildAppBarActions(),
      ),
      body: Padding(
        padding: context.pageBodyPadding,
        child: CustomScrollView(
          slivers: [
            // Firewall permission card (desktop only)
            SliverToBoxAdapter(
              child: FirewallPermissionCard(
                onPermissionChanged: _onFirewallPermissionChanged,
              ),
            ),

            // Server Mode Toggle (Android only)
            if (Platform.isAndroid) ...[
              SliverToBoxAdapter(
                child: ServerModeToggle(
                  isServerMode: isServerMode,
                  onToggle: toggleServerMode,
                  title: _translationService.translate(SyncTranslationKeys.serverModeTitle),
                  subtitle: isServerMode
                      ? _translationService.translate(SyncTranslationKeys.serverModeActive)
                      : _translationService.translate(SyncTranslationKeys.serverModeInactive),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.sizeLarge),
              ),
            ],

            // Device List
            if (_list == null || _list!.items.isEmpty)
              SliverFillRemaining(
                child: SyncDevicesEmptyState(
                  message: _translationService.translate(SyncTranslationKeys.noDevicesFound),
                  addDeviceLabel: _translationService.translate(SyncTranslationKeys.addDeviceTooltip),
                  showAddButton: !isServerMode,
                  onAddDevice: _showAddDevicePage,
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
                      child: SyncDeviceListItemWidget(
                        key: ValueKey(_list!.items[index].id),
                        item: _list!.items[index],
                        onRemove: _removeDevice,
                        isBeingSynced: _currentSyncStatus.isSyncing &&
                            _currentSyncStatus.currentDeviceId == _list!.items[index].id,
                      ),
                    );
                  },
                  childCount: _list!.items.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      // Sync status indicator - only show in server mode during actual sync activity
      if (isServerMode && isServerSyncActive)
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: _buildSyncStatusIndicator(),
        ),

      // Sync button - behavior depends on mode
      if (!isServerMode && (_list?.items.isNotEmpty ?? false))
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
      if (!isServerMode)
        IconButton(
          onPressed: _showAddDevicePage,
          icon: const Icon(Icons.add),
          color: Theme.of(context).colorScheme.primary,
          tooltip: _translationService.translate(SyncTranslationKeys.addDeviceTooltip),
        ),

      // Connection Info Button - show only when in server mode
      if (isServerMode) SyncConnectInfoButton(),

      // Kebab menu
      KebabMenu(
        helpTitleKey: SyncTranslationKeys.helpTitle,
        helpMarkdownContentKey: SyncTranslationKeys.helpContent,
        additionalMenuItems: [
          // Mobile sync mode toggle (only on Android)
          if (Platform.isAndroid)
            PopupMenuItem<String>(
              value: 'toggle_server',
              child: Row(
                children: [
                  Icon(isServerMode ? Icons.stop : Icons.wifi_tethering, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(isServerMode
                      ? _translationService.translate(SyncTranslationKeys.serverModeStopMenu)
                      : _translationService.translate(SyncTranslationKeys.serverModeStartMenu)),
                ],
              ),
            ),
          // Desktop sync mode toggle (only on Desktop)
          if (PlatformUtils.isDesktop)
            PopupMenuItem<String>(
              value: 'toggle_client',
              child: Row(
                children: [
                  Icon(desktopSyncMode == DesktopSyncMode.client ? Icons.stop : Icons.wifi_tethering,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(desktopSyncMode == DesktopSyncMode.client
                      ? _translationService.translate(SyncTranslationKeys.desktopSyncModeStopMenu)
                      : _translationService.translate(SyncTranslationKeys.desktopSyncModeStartMenu)),
                ],
              ),
            ),
        ],
        onMenuItemSelected: (value) {
          switch (value) {
            case 'toggle_server':
              toggleServerMode();
              break;
            case 'toggle_client':
              toggleDesktopSyncMode();
              break;
          }
        },
      ),
    ];
  }
}
