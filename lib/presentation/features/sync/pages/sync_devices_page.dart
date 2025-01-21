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

  SyncDevicesPage({super.key});

  @override
  State<SyncDevicesPage> createState() => _SyncDevicesPageState();
}

class _SyncDevicesPageState extends State<SyncDevicesPage> {
  GetListSyncDevicesQueryResponse? list;

  @override
  void initState() {
    _getDevices(pageIndex: 0, pageSize: 10);
    super.initState();
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
      SnackBar(
        content: Text('Syncing...'),
      ),
    );

    if (mounted) {
      setState(() {
        _isSyncing = true;
      });
    }

    try {
      var command = SyncCommand();
      await widget.mediator.send<SyncCommand, void>(command);
      await _refreshDevices();
    } catch (e, stackTrace) {
      if (mounted) {
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
    await _getDevices(pageIndex: 0, pageSize: 10);
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
          child: SyncQrScanButton(),
        )
    ];
  }

  @override
  Widget build(BuildContext context) {
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
              itemCount: list!.items.length,
              itemBuilder: (context, index) {
                return SyncDeviceListItemWidget(
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
