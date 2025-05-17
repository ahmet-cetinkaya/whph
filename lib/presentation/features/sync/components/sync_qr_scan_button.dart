import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/device_info_helper.dart';
import 'package:whph/presentation/shared/utils/network_utils.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/features/sync/models/sync_qr_code_message.dart';
import 'package:whph/presentation/features/sync/pages/qr_code_scanner_page.dart';
import 'package:whph/presentation/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/application/features/sync/services/abstraction/i_device_id_service.dart';
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

        final parsedMessage = JsonMapper.deserialize<SyncQrCodeMessage>(scannedMessage);
        if (parsedMessage == null) {
          throw BusinessException(_translationService.translate(SyncTranslationKeys.parseError));
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
          throw BusinessException(_translationService.translate(SyncTranslationKeys.ipAddressError));
        }

        // Show testing connection message
        if (context.mounted) {
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
                  Text(_translationService.translate(SyncTranslationKeys.testingConnection)),
                ],
              ),
              duration: const Duration(seconds: 15),
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }

        // Test connection
        final canConnect = await NetworkUtils.testWebSocketConnection(
          syncQrCodeMessageFromIP.localIP,
          timeout: const Duration(seconds: 10),
        );

        if (!canConnect) {
          throw BusinessException(_translationService.translate(SyncTranslationKeys.connectionFailedError));
        }

        return localIp;
      },
      intermediateContextChecks: [
        (context) => ScaffoldMessenger.of(context).clearSnackBars(),
      ],
      onSuccess: (toIP) async {
        final localDeviceId = await _deviceIdService.getDeviceId();
        if (!context.mounted) return;

        // Check if device already exists
        final existingDevice = await _mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(
            GetSyncDeviceQuery(fromDeviceId: syncQrCodeMessageFromIP.deviceId, toDeviceId: localDeviceId));

        if (existingDevice?.id.isNotEmpty == true && existingDevice?.deletedDate == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_translationService.translate(SyncTranslationKeys.deviceAlreadyPaired)),
              ),
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
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
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
                ));

              if (kDebugMode) debugPrint('[SyncQrScanButton]: Starting sync process...');

              onSyncComplete?.call();
              await _sync(context);

              if (kDebugMode) debugPrint('[SyncQrScanButton]: Sync completed successfully');

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              await Future.delayed(const Duration(milliseconds: 100));

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_translationService.translate(SyncTranslationKeys.syncCompleted)),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
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
        if (kDebugMode) debugPrint('[SyncQrScanButton]: Starting sync process...');

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
            throw BusinessException(_translationService.translate(SyncTranslationKeys.syncTimeoutError));
          },
        );

        subscription.cancel();
        if (kDebugMode) debugPrint('[SyncQrScanButton]: Sync process completed');
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
