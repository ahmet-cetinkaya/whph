import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/app_logo.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/sync/components/sync_qr_code_button.dart';
import 'package:whph/presentation/features/sync/components/sync_qr_scan_button.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/constants/navigation_items.dart';

class SyncDevicesPage extends StatefulWidget {
  static const route = '/sync-devices';

  final Mediator mediator = container.resolve<Mediator>();
  final Key key;

  SyncDevicesPage({key})
      : key = key ?? UniqueKey(),
        super(key: key);

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage> with AutomaticKeepAliveClientMixin {
  GetListSyncDevicesQueryResponse? list;
  Key _listKey = UniqueKey(); // Add this

  @override
  bool get wantKeepAlive => true; // Add this

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
    print('M. Starting _getDevices...'); // Debug log
    try {
      var query = GetListSyncDevicesQuery(pageIndex: pageIndex, pageSize: pageSize);
      var response = await widget.mediator.send<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse>(query);
      print('N. Received ${response.items.length} devices'); // Debug log

      if (mounted) {
        print('O. Updating state with new devices...'); // Debug log
        setState(() {
          list = response;
        });
        print('P. State updated'); // Debug log
      }
    } catch (e, stackTrace) {
      print('Error in _getDevices: $e'); // Debug log
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
      print('DEBUG: Starting sync process...');
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
      print('DEBUG: Sync process completed');
    } catch (e, stackTrace) {
      print('ERROR: Sync failed: $e');
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
    print('X. Starting _refreshDevices...'); // Debug log
    if (mounted) {
      setState(() {
        list = null;
        _listKey = UniqueKey(); // Force rebuild
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await _getDevices(pageIndex: 0, pageSize: 10);
    }
  }

  List<Widget> _buildAppBarActions() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IconButton(
          onPressed: _sync,
          icon: Icon(Icons.sync),
          color: AppTheme.primaryColor,
        ),
      ),
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows)
        Padding(
          padding: const EdgeInsets.all(8),
          child: const SyncQrCodeButton(),
        ),
      if (Platform.isAndroid || Platform.isIOS)
        Padding(
          padding: const EdgeInsets.all(4),
          child: SyncQrScanButton(
            onSyncComplete: _refreshDevices,
          ),
        )
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Add this
    return ResponsiveScaffoldLayout(
      appBarTitle: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppLogo(width: 32, height: 32),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: const Text(
                'Sync Devices',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        ],
      ),
      appBarActions: _buildAppBarActions(),
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => list == null || list!.items.isEmpty
          ? const Center(child: Text('No synced devices found'))
          : ListView.builder(
              key: _listKey, // Add this
              itemCount: list!.items.length,
              itemBuilder: (context, index) {
                return SyncDeviceListItemWidget(
                  key: ValueKey(list!.items[index].id), // Add this
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
