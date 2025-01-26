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

class SyncDevicesPage extends StatefulWidget {
  static const route = '/sync-devices';

  final Mediator mediator = container.resolve<Mediator>();

  SyncDevicesPage({super.key});

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage> with AutomaticKeepAliveClientMixin {
  GetListSyncDevicesQueryResponse? list;
  Key _listKey = UniqueKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _getDevices(pageIndex: 0, pageSize: 10);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getDevices({required int pageIndex, required int pageSize}) async {
    try {
      var query = GetListSyncDevicesQuery(pageIndex: pageIndex, pageSize: pageSize);
      var response = await widget.mediator.send<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse>(query);

      if (mounted) {
        setState(() {
          list = response;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Failed to load sync devices.');
      }
    }
  }

  Future<void> _removeDevice(String id) async {
    try {
      var command = DeleteSyncDeviceCommand(id: id);
      await widget.mediator.send<DeleteSyncDeviceCommand, void>(command);
      if (mounted) {
        setState(() {
          list!.items.removeWhere((item) => item.id == id);
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Failed to remove sync device.');
      }
    }
  }

  bool _isSyncing = false;
  Future<void> _sync() async {
    if (_isSyncing) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Sync in progress...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {
      if (kDebugMode) print('DEBUG: Starting sync process...');
      var command = SyncCommand();
      await widget.mediator.send<SyncCommand, void>(command);

      // Add a small delay before refreshing the devices list
      await Future.delayed(const Duration(seconds: 2));
      await _refreshDevices();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 16),
                  Text('Sync completed successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
      }
      if (kDebugMode) print('DEBUG: Sync process completed');
    } catch (e, stackTrace) {
      if (kDebugMode) print('ERROR: Sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Failed to sync devices.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _refreshDevices() async {
    if (mounted) {
      setState(() {
        list = null;
        _listKey = UniqueKey();
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await _getDevices(pageIndex: 0, pageSize: 10);
    }
  }

  void _showHelpModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sync Devices Help',
                      style: AppTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '🔄 Sync your data across multiple devices securely.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚡ Features',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Device Sync:',
                  '  - Sync tasks and habits',
                  '  - Sync time records',
                  '  - Sync tag configurations',
                  '• QR Code Connection:',
                  '  - Easy device pairing',
                  '  - Secure connection setup',
                  '  - Quick sync initiation',
                  '• Device Management:',
                  '  - View connected devices',
                  '  - Monitor sync status',
                  '  - Remove old devices',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '💡 Tips',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Keep devices on the same network',
                  '• Sync regularly for best results',
                  '• Remove unused device connections',
                  '• Check last sync dates',
                  '• Use QR codes for quick setup',
                  '• Wait for sync completion',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ResponsiveScaffoldLayout(
      title: 'Sync Devices',
      appBarActions: [
        IconButton(
          onPressed: _sync,
          icon: Icon(Icons.sync),
          color: AppTheme.primaryColor,
        ),
        if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) const SyncQrCodeButton(),
        if (Platform.isAndroid || Platform.isIOS)
          SyncQrScanButton(
            onSyncComplete: _refreshDevices,
          ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpModal,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => list == null || list!.items.isEmpty
          ? const Center(child: Text('No synced devices found'))
          : ListView.builder(
              key: _listKey,
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

  const SyncDeviceListItemWidget({
    super.key,
    required this.item,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.name ?? 'Unnamed Device'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('From: ${item.fromIp}'),
          Text('To: ${item.toIp}'),
          Text(
              'Last Sync: ${item.lastSyncDate != null ? DateFormat('yyyy/MM/dd kk:mm:ss').format(item.lastSyncDate!.toLocal()) : 'Never'}'),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete),
        onPressed: () => onRemove(item.id),
      ),
    );
  }
}
