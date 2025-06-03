import 'package:flutter/foundation.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/presentation/ui/features/sync/models/sync_qr_code_message.dart';
import 'package:whph/src/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_device_id_service.dart';

class SyncQrCodeButton extends StatelessWidget {
  final _translationService = container.resolve<ITranslationService>();
  final _deviceIdService = container.resolve<IDeviceIdService>();

  SyncQrCodeButton({super.key});

  void _showQrCodeModal(BuildContext context) async {
    String? ipAddress = await NetworkUtils.getLocalIpAddress();

    final deviceName = await DeviceInfoHelper.getDeviceName();
    final deviceId = await _deviceIdService.getDeviceId();

    SyncQrCodeMessage syncQrCodeMessage = SyncQrCodeMessage(
      localIP: ipAddress ?? 'Unknown IP',
      deviceName: deviceName,
      deviceId: deviceId,
    );

    if (kDebugMode) {
      debugPrint('Sync QR Code Message: ${JsonMapper.serialize(syncQrCodeMessage)}');
    }

    final qrData = JsonMapper.serialize(syncQrCodeMessage);

    if (context.mounted) {
      ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: AlertDialog(
          title: Text(_translationService.translate(SyncTranslationKeys.qrDialogTitle)),
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
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(_translationService.translate(SyncTranslationKeys.qrDialogCloseButton)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        size: DialogSize.min,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code),
      onPressed: () => _showQrCodeModal(context),
      color: AppTheme.primaryColor,
    );
  }
}
