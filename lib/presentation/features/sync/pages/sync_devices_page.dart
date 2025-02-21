import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/sync/components/sync_qr_code_button.dart';
import 'package:whph/presentation/features/sync/components/sync_qr_scan_button.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/sync/constants/sync_translation_keys.dart';

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
    try {
      final query = GetListSyncDevicesQuery(pageIndex: pageIndex, pageSize: pageSize);
      final response = await _mediator.send<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse>(query);

      if (mounted) {
        setState(() {
          list = response;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(SyncTranslationKeys.loadDevicesError),
        );
      }
    }
  }

  Future<void> _sync() async {
    if (_isSyncing) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(_translationService.translate(SyncTranslationKeys.syncInProgress)),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    setState(() => _isSyncing = true);

    try {
      if (kDebugMode) print('DEBUG: Starting sync process...');
      final command = SyncCommand();
      await _mediator.send<SyncCommand, void>(command);

      await Future.delayed(const Duration(seconds: 2));
      await refresh();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 16),
                  Text(_translationService.translate(SyncTranslationKeys.syncCompleted)),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('ERROR: Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(SyncTranslationKeys.syncDevicesError),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _removeDevice(String id) async {
    try {
      final command = DeleteSyncDeviceCommand(id: id);
      await _mediator.send<DeleteSyncDeviceCommand, void>(command);
      if (mounted) {
        setState(() {
          list!.items.removeWhere((item) => item.id == id);
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(SyncTranslationKeys.removeDeviceError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(SyncTranslationKeys.pageTitle),
      appBarActions: [
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
        const SizedBox(width: 8),
      ],
      builder: (context) => list == null || list!.items.isEmpty
          ? Center(child: Text(_translationService.translate(SyncTranslationKeys.noDevicesFound)))
          : ListView.builder(
              itemCount: list!.items.length,
              itemBuilder: (context, index) {
                return SyncDeviceListItemWidget(
                  key: ValueKey(list!.items[index].id),
                  item: list!.items[index],
                  onRemove: _removeDevice,
                );
              },
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
                            item.lastSyncDate != null
                                ? DateFormat('yyyy/MM/dd kk:mm:ss').format(item.lastSyncDate!.toLocal())
                                : 'Never',
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
