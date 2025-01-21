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
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/utils/network_utils.dart';
import 'package:whph/presentation/features/sync/models/sync_qr_code_message.dart';
import 'package:whph/presentation/features/sync/pages/qr_code_scanner_page.dart';
import 'dart:async';

class SyncQrScanButton extends StatelessWidget {
  final Mediator _mediator = container.resolve<Mediator>();
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

    var parsedMessage = JsonMapper.deserialize<SyncQrCodeMessage>(scannedMessage);
    if (parsedMessage == null) {
      if (context.mounted) {
        ErrorHelper.showError(context, BusinessException('Error: Unable to parse scanned message.'));
      }
      return;
    }

    if (context.mounted) _saveSyncDevice(context, parsedMessage);
  }

  _saveSyncDevice(BuildContext context, SyncQrCodeMessage syncQrCodeMessageFromIP) async {
    String? toIP = await NetworkUtils.getLocalIpAddress();
    if (toIP == null) {
      if (context.mounted) {
        ErrorHelper.showError(context, BusinessException('Error: Unable to fetch local IP address.'));
      }
      return;
    }

    // Show testing connection message
    if (context.mounted) {
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
              Text('Testing connection...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    // Test connection to target device
    bool canConnect = await NetworkUtils.testWebSocketConnection(
      syncQrCodeMessageFromIP.localIP,
      timeout: const Duration(seconds: 5),
    );

    if (!canConnect) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ErrorHelper.showError(
          context,
          BusinessException(
            'Unable to connect to device. Please ensure both devices are on the same network.',
          ),
        );
      }
      return;
    }

    try {
      GetSyncDeviceQueryResponse? existingDevice;
      try {
        // Check existing device
        var fromIPAndToIPQuery = GetSyncDeviceQuery(fromIP: syncQrCodeMessageFromIP.localIP, toIP: toIP);
        existingDevice = await _mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(fromIPAndToIPQuery);
      } catch (e) {
        if (kDebugMode) print('DEBUG: Get device error: $e');
        existingDevice = null;
      }

      if (existingDevice != null && existingDevice.id.isNotEmpty && existingDevice.deletedDate == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This device is already paired')),
          );
          return;
        }
      }

      // Save new device
      var saveCommand = SaveSyncDeviceCommand(
          fromIP: syncQrCodeMessageFromIP.localIP,
          toIP: toIP,
          name: syncQrCodeMessageFromIP.deviceName,
          lastSyncDate: DateTime(0));

      await _mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(saveCommand);

      if (context.mounted) {
        // Show syncing message and refresh list immediately
        final syncSnackBar = SnackBar(
          content: const Row(
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
              Text('Syncing in progress...'),
            ],
          ),
          duration: const Duration(seconds: 30), // Reduced duration
        );

        ScaffoldMessenger.of(context)
          ..clearSnackBars() // Clear all existing snack bars
          ..showSnackBar(syncSnackBar);

        if (kDebugMode) print('DEBUG: Starting sync process...');

        // Refresh list immediately
        if (onSyncComplete != null) {
          onSyncComplete!();
        }

        try {
          // Start sync process
          await _sync(context);
          if (kDebugMode) print('DEBUG: Sync completed successfully');

          if (context.mounted) {
            // Ensure we clear any existing snack bars before showing completion
            ScaffoldMessenger.of(context).clearSnackBars();

            // Show completion message with longer duration
            await Future.delayed(const Duration(milliseconds: 100)); // Small delay

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sync completed successfully'),
                  duration: Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );

              // Final refresh after sync complete
              if (onSyncComplete != null) {
                onSyncComplete!();
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print('DEBUG: Sync error: $e');
          rethrow; // Rethrow to be caught by outer try-catch
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('DEBUG: Save device error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (e is Exception) {
          ErrorHelper.showUnexpectedError(context, e, stackTrace, message: 'Failed to save sync device.');
        } else {
          ErrorHelper.showError(context, BusinessException('Failed to save sync device: ${e.toString()}'));
        }
      }
    }
  }

  _sync(BuildContext context) async {
    try {
      if (kDebugMode) print('DEBUG: Starting sync process...');

      final syncService = container.resolve<ISyncService>();
      var completer = Completer<void>();

      // Listen for sync completion
      var subscription = syncService.onSyncComplete.listen((completed) {
        if (completed && !completer.isCompleted) {
          completer.complete();
        }
      });

      // Run immediate sync and restart timer
      await syncService.runSync();

      // Wait for completion or timeout
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          subscription.cancel();
          throw BusinessException('Sync timeout');
        },
      );

      subscription.cancel();
      if (kDebugMode) print('DEBUG: Sync process completed');
    } catch (e) {
      // ...existing error handling...
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
