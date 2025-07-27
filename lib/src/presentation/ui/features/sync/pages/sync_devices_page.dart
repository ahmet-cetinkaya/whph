import 'dart:io';
import 'dart:async';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/src/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/features/sync/components/sync_qr_code_button.dart';
import 'package:whph/src/presentation/ui/features/sync/components/sync_qr_scan_button.dart';
import 'package:whph/src/presentation/ui/shared/components/help_menu.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/src/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/src/infrastructure/android/features/sync/android_sync_service.dart';
import 'package:whph/src/core/application/features/sync/models/sync_status.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_service.dart';

class SyncDevicesPage extends StatefulWidget {
  static const route = '/sync-devices';

  const SyncDevicesPage({super.key});

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage> with AutomaticKeepAliveClientMixin {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  late final ISyncService _syncService;

  GetListSyncDevicesQueryResponse? list;
  StreamSubscription<SyncStatus>? _syncStatusSubscription;
  SyncStatus _currentSyncStatus = const SyncStatus(state: SyncState.idle);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _syncService = Platform.isAndroid ? AndroidSyncService(_mediator) : container.resolve<ISyncService>();
    _setupSyncStatusListener();
    refresh();
  }

  void _setupSyncStatusListener() {
    _syncStatusSubscription = _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentSyncStatus = status;
        });
        _handleSyncStatusChange(status);
      }
    });
  }

  void _handleSyncStatusChange(SyncStatus status) {
    switch (status.state) {
      case SyncState.syncing:
        if (status.isManual) {
          OverlayNotificationHelper.showLoading(
            context: context,
            message: _translationService.translate(SyncTranslationKeys.syncInProgress),
            duration: const Duration(seconds: 30),
          );
        }
        break;
      case SyncState.completed:
        OverlayNotificationHelper.hideNotification();
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(SyncTranslationKeys.syncCompleted),
          duration: const Duration(seconds: 3),
        );
        refresh();
        break;
      case SyncState.error:
        OverlayNotificationHelper.hideNotification();
        OverlayNotificationHelper.showError(
          context: context,
          message: _translationService.translate(SyncTranslationKeys.syncDevicesError),
          duration: const Duration(seconds: 3),
        );
        break;
      case SyncState.idle:
        break;
    }
  }

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Use a standard Scaffold instead of ResponsiveScaffoldLayout
    // This makes the page more compatible when displayed in dialogs/bottom sheets
    return Scaffold(
      appBar: AppBar(
        title: Text(_translationService.translate(SyncTranslationKeys.pageTitle)),
        actions: [
          // Only Android can initiate sync, desktop is passive
          if (Platform.isAndroid)
            IconButton(
              onPressed: _currentSyncStatus.isSyncing ? null : _sync,
              icon: _currentSyncStatus.isSyncing
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                    )
                  : const Icon(Icons.sync),
              color: Theme.of(context).colorScheme.primary,
              tooltip: _translationService.translate(SyncTranslationKeys.syncTooltip),
            ),
          if (PlatformUtils.isDesktop) SyncQrCodeButton(),
          if (PlatformUtils.isMobile)
            SyncQrScanButton(
              onSyncComplete: refresh,
            ),
          HelpMenu(
            titleKey: SyncTranslationKeys.helpTitle,
            markdownContentKey: SyncTranslationKeys.helpContent,
          ),
        ],
      ),
      body: list == null || list!.items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppTheme.sizeLarge),
              child: IconOverlay(
                icon: Icons.devices_other,
                message: _translationService.translate(SyncTranslationKeys.noDevicesFound),
              ),
            )
          : ListView.separated(
              itemCount: list!.items.length,
              padding: EdgeInsets.only(bottom: AppTheme.sizeSmall),
              itemBuilder: (context, index) {
                return SyncDeviceListItemWidget(
                  key: ValueKey(list!.items[index].id),
                  item: list!.items[index],
                  onRemove: _removeDevice,
                  isBeingSynced: _currentSyncStatus.isSyncing && _currentSyncStatus.currentDeviceId == list!.items[index].id,
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
                        widget.item.lastSyncDate != null ? DateTimeHelper.formatDate(widget.item.lastSyncDate) : '-',
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
