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
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/utils/network_utils.dart';
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

  _openQRScanner(BuildContext context) async {
    String? scannedMessage = await Navigator.pushNamed(
      context,
      QRCodeScannerPage.route,
    ) as String?;

    if (scannedMessage == null) return;

    final parsedMessage = JsonMapper.deserialize<SyncQrCodeMessage>(scannedMessage);
    if (parsedMessage == null) {
      if (context.mounted) {
        ErrorHelper.showError(
            context, BusinessException(_translationService.translate(SyncTranslationKeys.parseError)));
      }
      return;
    }

    if (context.mounted) _saveSyncDevice(context, parsedMessage);
  }

  _saveSyncDevice(BuildContext context, SyncQrCodeMessage syncQrCodeMessageFromIP) async {
    String? toIP = await NetworkUtils.getLocalIpAddress();
    if (toIP == null) {
      if (context.mounted) {
        ErrorHelper.showError(
            context, BusinessException(_translationService.translate(SyncTranslationKeys.ipAddressError)));
      }
      return;
    }

    // Get local device ID
    final localDeviceId = await _deviceIdService.getDeviceId();

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

    final canConnect = await NetworkUtils.testWebSocketConnection(
      syncQrCodeMessageFromIP.localIP,
      timeout: const Duration(seconds: 10),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();

      if (!canConnect) {
        ErrorHelper.showError(
            context, BusinessException(_translationService.translate(SyncTranslationKeys.connectionFailedError)));
        return;
      }
    }

    try {
      GetSyncDeviceQueryResponse? existingDevice;
      try {
        existingDevice = await _mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(
            GetSyncDeviceQuery(fromDeviceId: syncQrCodeMessageFromIP.deviceId, toDeviceId: localDeviceId));
      } catch (e) {
        if (kDebugMode) debugPrint('[SyncQrScanButton]: Get device error: $e');
        existingDevice = null;
      }

      if (existingDevice != null && existingDevice.id.isNotEmpty && existingDevice.deletedDate == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_translationService.translate(SyncTranslationKeys.deviceAlreadyPaired)),
            ),
          );
          return;
        }
      }

      final localDeviceName = await DeviceInfoHelper.getDeviceName();
      final saveCommand = SaveSyncDeviceCommand(
        fromIP: syncQrCodeMessageFromIP.localIP,
        toIP: toIP,
        fromDeviceId: syncQrCodeMessageFromIP.deviceId, // Host device's ID
        toDeviceId: localDeviceId, // Clint device's ID
        name: "${syncQrCodeMessageFromIP.deviceName} > $localDeviceName",
        lastSyncDate: DateTime(0),
      );

      await _mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(saveCommand);

      if (context.mounted) {
        final syncSnackBar = SnackBar(
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
        );

        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(syncSnackBar);

        if (kDebugMode) debugPrint('[SyncQrScanButton]: Starting sync process...');

        if (onSyncComplete != null) {
          onSyncComplete!();
        }

        try {
          await _sync(context);
          if (kDebugMode) debugPrint('[SyncQrScanButton]: Sync completed successfully');

          if (context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            await Future.delayed(const Duration(milliseconds: 100));

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_translationService.translate(SyncTranslationKeys.syncCompleted)),
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              if (onSyncComplete != null) {
                onSyncComplete!();
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[SyncQrScanButton]: Sync error: $e');
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('[SyncQrScanButton]: Save device error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (e is Exception) {
          ErrorHelper.showUnexpectedError(context, e, stackTrace,
              message: _translationService.translate(SyncTranslationKeys.saveDeviceError));
        } else {
          ErrorHelper.showError(
              context, BusinessException(_translationService.translate(SyncTranslationKeys.saveDeviceError)));
        }
      }
    }
  }

  _sync(BuildContext context) async {
    try {
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
    } catch (e) {
      if (kDebugMode) debugPrint('[SyncQrScanButton]: Sync error: $e');
      if (context.mounted) {
        ErrorHelper.showError(context, BusinessException(_translationService.translate(SyncTranslationKeys.syncError)));
      }
    }
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
