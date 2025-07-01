import 'dart:io';
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

class SyncDevicesPage extends StatefulWidget {
  static const route = '/sync-devices';

  const SyncDevicesPage({super.key});

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage> with AutomaticKeepAliveClientMixin {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  GetListSyncDevicesQueryResponse? list;
  bool _isSyncing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    refresh();
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

    if (_isSyncing) return;

    // Show initial syncing notification
    OverlayNotificationHelper.showLoading(
      context: context,
      message: _translationService.translate(SyncTranslationKeys.syncInProgress),
      duration: const Duration(seconds: 30),
    );

    setState(() => _isSyncing = true);

    try {
      // Use AndroidSyncService for manual sync trigger
      final androidSyncService = AndroidSyncService(_mediator);
      await androidSyncService.runSync();
      
      await Future.delayed(const Duration(seconds: 2));
      await refresh();

      if (mounted) {
        OverlayNotificationHelper.hideNotification();
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(SyncTranslationKeys.syncCompleted),
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Logger.error('Manual sync failed: $e');
      if (mounted) {
        OverlayNotificationHelper.hideNotification();
        OverlayNotificationHelper.showError(
          context: context,
          message: _translationService.translate(SyncTranslationKeys.syncDevicesError),
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
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
          if (PlatformUtils.isMobile)
            IconButton(
              onPressed: _sync,
              icon: const Icon(Icons.sync),
              color: AppTheme.primaryColor,
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
          : Padding(
              padding: const EdgeInsets.all(AppTheme.sizeLarge),
              child: ListView.separated(
                itemCount: list!.items.length,
                padding: EdgeInsets.only(bottom: AppTheme.sizeSmall),
                itemBuilder: (context, index) {
                  return SyncDeviceListItemWidget(
                    key: ValueKey(list!.items[index].id),
                    item: list!.items[index],
                    onRemove: _removeDevice,
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: AppTheme.sizeSmall),
              ),
            ),
    );
  }
}

class SyncDeviceListItemWidget extends StatelessWidget {
  final SyncDeviceListItem item;
  final void Function(String) onRemove;
  final _translationService = container.resolve<ITranslationService>();

  SyncDeviceListItemWidget({
    super.key,
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.name ?? _translationService.translate(SyncTranslationKeys.unnamedDevice)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (PlatformUtils.isMobile) ...[
                // Host
                Row(
                  children: [
                    Text(
                      '${_translationService.translate(SyncTranslationKeys.fromLabel)}:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Chip(
                          label: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              'IP: ${item.fromIP} | ID: ${item.fromDeviceID}',
                              style: AppTheme.labelXSmall,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
              ],
              if (PlatformUtils.isDesktop) ...[
                // Client
                Row(
                  children: [
                    Text(
                      '${_translationService.translate(SyncTranslationKeys.toLabel)}:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Chip(
                          label: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              'IP: ${item.toIP} | ID: ${item.toDeviceID}',
                              style: AppTheme.labelXSmall,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
              ],
              Row(
                children: [
                  Text(
                    '${_translationService.translate(SyncTranslationKeys.lastSyncLabel)}:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Chip(
                        label: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            item.lastSyncDate != null ? DateTimeHelper.formatDate(item.lastSyncDate) : '-',
                            style: AppTheme.labelXSmall,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => onRemove(item.id),
        ),
      ),
    );
  }
}
