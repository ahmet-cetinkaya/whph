import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/domain/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/sync/components/sync_qr_code_button.dart';
import 'package:whph/presentation/features/sync/components/sync_qr_scan_button.dart';

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
    var query = GetListSyncDevicesQuery(pageIndex: pageIndex, pageSize: pageSize);
    var response = await widget.mediator.send<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse>(query);
    setState(() {
      list = response;
    });
  }

  Future<void> _removeDevice(String id) async {
    var command = DeleteSyncDeviceCommand(id: id);
    await widget.mediator.send<DeleteSyncDeviceCommand, void>(command);
    setState(() {
      list!.items.removeWhere((item) => item.id == id);
    });
  }

  bool _isSyncing = false;
  Future<void> _sync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Syncing...'),
      ),
    );

    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    var command = SyncCommand();
    await widget.mediator.send<SyncCommand, void>(command);

    setState(() {
      _isSyncing = false;
    });
  }

  List<Widget> _buildAppBarActions() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: IconButton(
          onPressed: _sync,
          icon: Icon(Icons.sync),
          color: AppTheme.primaryColor,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all<Color>(AppTheme.surface2),
          ),
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
    return Scaffold(
      appBar: SecondaryAppBar(
        context: context,
        title: const Text('Sync Devices'),
        actions: _buildAppBarActions(),
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
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
