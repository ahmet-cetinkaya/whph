import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/src/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/src/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/features/sync/models/sync_qr_code_message.dart';
import 'package:whph/src/presentation/ui/features/sync/pages/qr_code_scanner_page.dart';
import 'package:whph/src/presentation/ui/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'dart:async';

class SyncQrScanButton extends StatelessWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _deviceIdService = container.resolve<IDeviceIdService>();
  final VoidCallback? onSyncComplete;

  SyncQrScanButton({
    super.key,
    this.onSyncComplete,
  });

  Future<void> _openQRScanner(BuildContext context) async {
    await AsyncErrorHandler.execute<String?>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.scanError),
      operation: () async {
        final result = await Navigator.pushNamed(
          context,
          QRCodeScannerPage.route,
        );
        return result as String?;
      },
      onSuccess: (scannedMessage) async {
        if (scannedMessage == null || !context.mounted) return;

        SyncQrCodeMessage? parsedMessage;
        try {
          // Try CSV format first
          parsedMessage = SyncQrCodeMessage.fromCsv(scannedMessage);
        } catch (e) {
          // Fallback to JSON format for backward compatibility
          try {
            parsedMessage = JsonMapper.deserialize<SyncQrCodeMessage>(scannedMessage);
          } catch (e) {
            throw BusinessException('Failed to parse QR code message', SyncTranslationKeys.parseError);
          }
        }

        if (parsedMessage == null) {
          throw BusinessException('Failed to parse QR code message', SyncTranslationKeys.parseError);
        }

        if (context.mounted) {
          await _saveSyncDevice(context, parsedMessage);
        }
      },
    );
  }

  Future<void> _saveSyncDevice(BuildContext context, SyncQrCodeMessage syncQrCodeMessageFromIP) async {
    if (!context.mounted) return;

    await AsyncErrorHandler.executeChain<String>(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.saveDeviceError),
      operation: () async {
        // Get local IP
        final localIp = await NetworkUtils.getLocalIpAddress();
        if (localIp == null) {
          throw BusinessException('Local IP address could not be determined', SyncTranslationKeys.ipAddressError);
        }

        // Show testing connection message
        if (context.mounted) {
          OverlayNotificationHelper.showLoading(
            context: context,
            message: _translationService.translate(SyncTranslationKeys.testingConnection),
            duration: const Duration(seconds: 15),
          );
        }

        // Test connection
        final canConnect = await NetworkUtils.testWebSocketConnection(
          syncQrCodeMessageFromIP.localIP,
          timeout: const Duration(seconds: 10),
        );

        if (!canConnect) {
          throw BusinessException('Cannot connect to remote device', SyncTranslationKeys.connectionFailedError);
        }

        return localIp;
      },
      intermediateContextChecks: [
        (context) => OverlayNotificationHelper.hideNotification(),
      ],
      onSuccess: (toIP) async {
        final localDeviceId = await _deviceIdService.getDeviceId();
        if (!context.mounted) return;

        // Check if device already exists
        final existingDevice = await _mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(
            GetSyncDeviceQuery(fromDeviceId: syncQrCodeMessageFromIP.deviceId, toDeviceId: localDeviceId));

        if (existingDevice?.id.isNotEmpty == true && existingDevice?.deletedDate == null) {
          if (context.mounted) {
            OverlayNotificationHelper.showInfo(
              context: context,
              message: _translationService.translate(SyncTranslationKeys.deviceAlreadyPaired),
            );
          }
          return;
        }

        // Save device and start sync
        final localDeviceName = await DeviceInfoHelper.getDeviceName();
        final saveCommand = SaveSyncDeviceCommand(
          fromIP: syncQrCodeMessageFromIP.localIP,
          toIP: toIP,
          fromDeviceId: syncQrCodeMessageFromIP.deviceId,
          toDeviceId: localDeviceId,
          name: "${syncQrCodeMessageFromIP.deviceName} > $localDeviceName",
        );

        if (context.mounted) {
          await AsyncErrorHandler.execute<SaveSyncDeviceCommandResponse>(
            context: context,
            errorMessage: _translationService.translate(SyncTranslationKeys.saveDeviceError),
            operation: () => _mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(saveCommand),
            onSuccess: (_) async {
              if (!context.mounted) return;

              // Show sync progress
              OverlayNotificationHelper.showLoading(
                context: context,
                message: _translationService.translate(SyncTranslationKeys.syncInProgress),
                duration: const Duration(seconds: 30),
              );

              onSyncComplete?.call();
              await _sync(context);

              if (!context.mounted) return;
              OverlayNotificationHelper.hideNotification();
              await Future.delayed(const Duration(milliseconds: 100));

              if (!context.mounted) return;
              OverlayNotificationHelper.showSuccess(
                context: context,
                message: _translationService.translate(SyncTranslationKeys.syncCompleted),
                duration: const Duration(seconds: 3),
              );

              onSyncComplete?.call();
            },
          );
        }
      },
    );
  }

  Future<void> _sync(BuildContext context) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SyncTranslationKeys.syncError),
      operation: () async {
        final syncService = container.resolve<ISyncService>();
        final completer = Completer<void>();

        final subscription = syncService.onSyncComplete.listen((completed) {
          if (completed && !completer.isCompleted) {
            completer.complete();
          }
        });

        await syncService.runSync();

        await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            subscription.cancel();
            throw BusinessException('Sync operation timed out', SyncTranslationKeys.syncTimeoutError);
          },
        );

        subscription.cancel();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _openQRScanner(context),
      icon: const Icon(Icons.qr_code_scanner),
      color: AppTheme.primaryColor,
    );
  }
}
