import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/src/core/application/features/sync/commands/sync_command.dart';
import 'package:whph/src/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/corePackages/acore/time/date_time_helper.dart';
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
    if (_isSyncing) return;

    // Show initial syncing notification
    OverlayNotificationHelper.showLoading(
      context: context,
      message: _translationService.translate(SyncTranslationKeys.syncInProgress),
      duration: const Duration(seconds: 30),
    );

    setState(() => _isSyncing = true);

    await AsyncErrorHandler.execute<void>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.syncDevicesError),
      operation: () async {
        final command = SyncCommand();
        await _mediator.send<SyncCommand, void>(command);
        return;
      },
      onSuccess: (_) async {
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
      },
      onError: (_) {
        if (kDebugMode) debugPrint('Sync failed');
        if (mounted) {
          OverlayNotificationHelper.hideNotification();
        }
      },
      finallyAction: () {
        if (mounted) setState(() => _isSyncing = false);
      },
    );
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
          IconButton(
            onPressed: _sync,
            icon: const Icon(Icons.sync),
            color: AppTheme.primaryColor,
          ),
          if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) SyncQrCodeButton(),
          if (Platform.isAndroid || Platform.isIOS)
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
              padding: const EdgeInsets.all(AppTheme.sizeMedium),
              child: IconOverlay(
                icon: Icons.devices_other,
                message: _translationService.translate(SyncTranslationKeys.noDevicesFound),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(AppTheme.sizeSmall),
              child: ListView.builder(
                itemCount: list!.items.length,
                itemBuilder: (context, index) {
                  return SyncDeviceListItemWidget(
                    key: ValueKey(list!.items[index].id),
                    item: list!.items[index],
                    onRemove: _removeDevice,
                  );
                },
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
              if (Platform.isAndroid || Platform.isIOS) ...[
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
              if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) ...[
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
