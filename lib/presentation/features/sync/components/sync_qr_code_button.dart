import 'dart:io';

import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/utils/network_utils.dart';
import 'package:whph/presentation/features/sync/models/sync_qr_code_message.dart';

class SyncQrCodeButton extends StatelessWidget {
  const SyncQrCodeButton({super.key});

  void _showQrCodeModal(BuildContext context) async {
    String? ipAddress = await NetworkUtils.getLocalIpAddress();
    if (ipAddress == null) {
      if (context.mounted) {
        BusinessException exception = BusinessException('Error: Unable to fetch local IP address.');
        ErrorHelper.showError(context, exception);
      }
      return;
    }

    SyncQrCodeMessage syncQrCodeMessage = SyncQrCodeMessage(localIP: ipAddress, deviceName: Platform.localHostname);
    var qrData = JsonMapper.serialize(syncQrCodeMessage);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Scan QR Code to Sync'),
            content: SizedBox(
              width: 200.0,
              height: 200.0,
              child: Center(
                child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppTheme.textColor,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: AppTheme.textColor,
                    )),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code),
      onPressed: () {
        _showQrCodeModal(context);
      },
      color: AppTheme.primaryColor,
    );
  }
}
