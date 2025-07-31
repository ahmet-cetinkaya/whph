import 'dart:io';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/presentation/ui/features/sync/models/sync_qr_code_message.dart';
import 'package:whph/src/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:acore/acore.dart';

class SyncQrCodeButton extends StatelessWidget {
  const SyncQrCodeButton({super.key});

  /// Static method to show QR code modal from anywhere
  static void showQrCodeModal(BuildContext context) async {
    final translationService = container.resolve<ITranslationService>();
    final deviceIdService = container.resolve<IDeviceIdService>();

    String? ipAddress = await NetworkUtils.getLocalIpAddress();

    final deviceName = await DeviceInfoHelper.getDeviceName();
    final deviceId = await deviceIdService.getDeviceId();

    // Determine platform for QR code
    String platform;
    if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    } else if (PlatformUtils.isDesktop) {
      platform = 'desktop';
    } else {
      platform = 'unknown';
    }

    SyncQrCodeMessage syncQrCodeMessage = SyncQrCodeMessage(
      localIP: ipAddress ?? 'Unknown IP',
      deviceName: deviceName,
      deviceId: deviceId,
      platform: platform,
    );

    Logger.debug('Sync QR Code Message: ${syncQrCodeMessage.toCsv()}');

    final qrData = syncQrCodeMessage.toCsv();

    if (context.mounted) {
      ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: AlertDialog(
          title: Text(translationService.translate(SyncTranslationKeys.qrDialogTitle)),
          content: SizedBox(
            width: 200.0,
            height: 200.0,
            child: Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: QrEyeStyle(
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
              child: Text(translationService.translate(SyncTranslationKeys.qrDialogCloseButton)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        size: DialogSize.min,
      );
    }
  }

  void _showQrCodeModal(BuildContext context) {
    SyncQrCodeButton.showQrCodeModal(context);
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
