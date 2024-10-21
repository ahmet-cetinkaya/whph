import 'dart:convert';

import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/network_utils.dart';
import 'package:whph/presentation/features/sync/models/sync_qr_code_message.dart';
import 'package:whph/presentation/features/sync/pages/qr_code_scanner_page.dart';

class SyncQrScanButton extends StatelessWidget {
  final Mediator _mediator = container.resolve<Mediator>();

  SyncQrScanButton({super.key});

  _openQRScanner(BuildContext context) async {
    String? scannedMessage = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QRCodeScannerPage(),
      ),
    );
    if (scannedMessage == null) return;

    var parsedMessage = JsonMapper.deserialize<SyncQrCodeMessage>(scannedMessage);
    if (parsedMessage == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Unable to parse scanned message.'),
          ),
        );
      }
      return;
    }

    if (context.mounted) _saveSyncDevice(context, parsedMessage);
  }

  _saveSyncDevice(BuildContext context, SyncQrCodeMessage syncQrCodeMessageFromIP) async {
    String? toIP = await NetworkUtils.getLocalIpAddress();
    if (toIP == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Unable to fetch local IP address.'),
          ),
        );
      }
      return;
    }

    SaveSyncDeviceCommand saveCommand;
    try {
      var fromIPAndToIPQuery = GetSyncDeviceQuery(fromIP: syncQrCodeMessageFromIP.localIP, toIP: toIP);
      var fromIPAndToIPResponse =
          await _mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse>(fromIPAndToIPQuery);
      saveCommand = SaveSyncDeviceCommand(
        fromIp: syncQrCodeMessageFromIP.localIP,
        toIp: toIP,
        id: fromIPAndToIPResponse.id,
        name: syncQrCodeMessageFromIP.deviceName,
        lastSyncDate: fromIPAndToIPResponse.lastSyncDate,
      );
    } catch (e) {
      saveCommand = SaveSyncDeviceCommand(
          fromIp: syncQrCodeMessageFromIP.localIP,
          toIp: toIP,
          name: syncQrCodeMessageFromIP.deviceName,
          lastSyncDate: DateTime(0));
    }
    await _mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(saveCommand);

    if (context.mounted) _sync(context);
  }

  _sync(BuildContext context) async {
    await _mediator.send<SyncCommand, SyncCommandResponse>(SyncCommand());
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _openQRScanner(context),
      child: const Icon(Icons.qr_code_scanner),
    );
  }
}
