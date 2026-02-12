import 'package:flutter/foundation.dart';
import 'package:application/features/sync/models/paginated_sync_data.dart';
import 'package:application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:application/features/sync/commands/paginated_sync_command/services/sync_device_coordinator.dart';
import 'package:application/features/sync/constants/sync_translation_keys.dart';
import 'package:domain/features/sync/sync_device.dart';
import 'package:domain/shared/utils/logger.dart';

/// Callback types for outgoing sync operations
typedef DeviceSyncCallback = Future<bool> Function(SyncDevice device);
typedef ResponseDtoCreator = Future<PaginatedSyncDataDto> Function(
  SyncDevice syncDevice,
  PaginatedSyncData localData,
  String entityType, {
  int? currentServerPage,
  int? totalServerPages,
  bool? hasMoreServerPages,
});

/// Result of outgoing sync operation
class OutgoingSyncResult {
  final bool isComplete;
  final int syncedDeviceCount;
  final bool hadMeaningfulSync;
  final List<String> errors;
  final Map<String, String>? errorParams;

  const OutgoingSyncResult({
    required this.isComplete,
    required this.syncedDeviceCount,
    required this.hadMeaningfulSync,
    required this.errors,
    this.errorParams,
  });

  bool get hasErrors => errors.isNotEmpty;
}

class SyncOutgoingHandler {
  final ISyncDeviceRepository _syncDeviceRepository;
  final ISyncPaginationService _paginationService;
  final SyncDeviceCoordinator _deviceCoordinator;

  SyncOutgoingHandler({
    required ISyncDeviceRepository syncDeviceRepository,
    required ISyncPaginationService paginationService,
    required SyncDeviceCoordinator deviceCoordinator,
  })  : _syncDeviceRepository = syncDeviceRepository,
        _paginationService = paginationService,
        _deviceCoordinator = deviceCoordinator;

  /// Initiates outgoing sync to all configured devices
  Future<OutgoingSyncResult> initiateOutgoingSync({
    String? targetDeviceId,
    required DeviceSyncCallback syncWithDevice,
    required ResponseDtoCreator createResponseDto,
    required VoidCallback resetProgressTracking,
  }) async {
    DomainLogger.info('Initiating outgoing paginated sync');
    DomainLogger.info('Target device ID: $targetDeviceId');

    try {
      // Get all devices to sync with
      DomainLogger.info('Fetching sync devices from repository...');
      final allDevices = await _syncDeviceRepository.getAll();
      DomainLogger.info('Found ${allDevices.length} sync devices in database');

      _logDeviceDetails(allDevices);

      if (allDevices.isEmpty) {
        DomainLogger.warning('No devices configured for sync');
        return const OutgoingSyncResult(
          isComplete: true,
          syncedDeviceCount: 0,
          hadMeaningfulSync: false,
          errors: [],
        );
      }

      // Reset progress tracking
      DomainLogger.info('Resetting pagination progress...');
      _paginationService.resetProgress();
      resetProgressTracking();

      // Sync with each device
      final syncResult = await _syncAllDevices(allDevices, syncWithDevice);

      // Update last sync dates and verify
      await _handlePostSyncUpdates(
        allDevices: allDevices,
        successfulDevices: syncResult.successfulDevices,
        allDevicesSynced: syncResult.allDevicesSynced,
        createResponseDto: createResponseDto,
      );

      await _deviceCoordinator.logSyncDiagnostics(allDevices, syncResult.successfulDevices);

      DomainLogger.info(syncResult.allDevicesSynced
          ? 'Paginated sync operation completed successfully'
          : 'Paginated sync operation completed with some failures');

      return OutgoingSyncResult(
        isComplete: syncResult.allDevicesSynced,
        syncedDeviceCount: syncResult.successfulDevices.length,
        hadMeaningfulSync: syncResult.successfulDevices.isNotEmpty,
        errors: !syncResult.allDevicesSynced ? [SyncTranslationKeys.someDevicesFailedToSyncError] : [],
      );
    } catch (e, stackTrace) {
      DomainLogger.error('CRITICAL: Failed to initiate outgoing sync', error: e, stackTrace: stackTrace);
      return _handleOutgoingSyncError(e);
    }
  }

  void _logDeviceDetails(List<SyncDevice> devices) {
    for (int i = 0; i < devices.length; i++) {
      final device = devices[i];
      DomainLogger.info(
          'Device $i LOADED FROM DATABASE with lastSyncDate=${device.lastSyncDate} (is null: ${device.lastSyncDate == null})');
    }
  }

  Future<({List<SyncDevice> successfulDevices, bool allDevicesSynced})> _syncAllDevices(
    List<SyncDevice> allDevices,
    DeviceSyncCallback syncWithDevice,
  ) async {
    final successfulDevices = <SyncDevice>[];
    bool allDevicesSynced = true;

    DomainLogger.info('Starting sync with ${allDevices.length} devices...');
    for (int i = 0; i < allDevices.length; i++) {
      final syncDevice = allDevices[i];
      DomainLogger.info('Syncing with device ${i + 1}/${allDevices.length}: ${syncDevice.id}');

      try {
        final success = await syncWithDevice(syncDevice);
        if (success) {
          DomainLogger.info('Successfully synced with device ${syncDevice.id}');
          successfulDevices.add(syncDevice);
        } else {
          DomainLogger.error('Failed to sync with device ${syncDevice.id} - this will prevent sync date updates');
          allDevicesSynced = false;
        }
      } catch (e, stackTrace) {
        DomainLogger.error('CRITICAL: Exception during sync with device ${syncDevice.id}',
            error: e, stackTrace: stackTrace);
        allDevicesSynced = false;
      }
    }

    DomainLogger.info(
        'Sync completion status: allDevicesSynced=$allDevicesSynced, successfulDevices=${successfulDevices.length}');
    return (successfulDevices: successfulDevices, allDevicesSynced: allDevicesSynced);
  }

  Future<void> _handlePostSyncUpdates({
    required List<SyncDevice> allDevices,
    required List<SyncDevice> successfulDevices,
    required bool allDevicesSynced,
    required ResponseDtoCreator createResponseDto,
  }) async {
    if (allDevicesSynced) {
      DomainLogger.info('Updating last sync dates for ${successfulDevices.length} successful devices');
      final updatedSyncDevices = await _updateSyncDates(successfulDevices);

      // Sync the updated sync device records back to the server for consistency
      if (updatedSyncDevices.isNotEmpty) {
        await _deviceCoordinator.syncUpdatedDevicesBackToServer(updatedSyncDevices, createResponseDto);
      }

      await _deviceCoordinator.verifySyncDateUpdates(updatedSyncDevices);
    } else {
      DomainLogger.warning('Not updating sync dates due to sync failures');
      DomainLogger.warning('allDevicesSynced=$allDevicesSynced, this means at least one device sync failed');

      // Log which devices failed
      for (final device in allDevices) {
        final wasSuccessful = successfulDevices.contains(device);
        DomainLogger.warning('Device ${device.id}: ${wasSuccessful ? "SUCCESS" : "FAILED"}');
      }
    }
  }

  Future<List<SyncDevice>> _updateSyncDates(List<SyncDevice> successfulDevices) async {
    final updatedSyncDevices = <SyncDevice>[];

    for (final syncDevice in successfulDevices) {
      final newSyncDate = DateTime.now();
      DomainLogger.info('Before update: device ${syncDevice.id} lastSyncDate=${syncDevice.lastSyncDate}');

      syncDevice.lastSyncDate = newSyncDate;
      await _syncDeviceRepository.update(syncDevice);

      // Add small delay to ensure database update is fully committed
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify the update
      await _verifySyncDateUpdate(syncDevice);

      updatedSyncDevices.add(syncDevice);
    }

    return updatedSyncDevices;
  }

  Future<void> _verifySyncDateUpdate(SyncDevice syncDevice) async {
    final verificationDevice = await _syncDeviceRepository.getById(syncDevice.id);
    if (verificationDevice != null) {
      if (verificationDevice.lastSyncDate == null) {
        DomainLogger.warning(
            'CRITICAL: Database update verification failed - lastSyncDate is still null after update!');
        // Retry the update once more to ensure it persists
        await _syncDeviceRepository.update(syncDevice);
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify again after retry
        final retryVerification = await _syncDeviceRepository.getById(syncDevice.id);
        if (retryVerification != null && retryVerification.lastSyncDate != null) {
          DomainLogger.info('Database update verification passed after retry - lastSyncDate properly persisted');
        } else {
          DomainLogger.error('Database update verification failed even after retry!');
        }
      }
    } else {
      DomainLogger.error('CRITICAL: Could not re-read sync device ${syncDevice.id} from database for verification');
    }
  }

  OutgoingSyncResult _handleOutgoingSyncError(dynamic e) {
    final String errorKey;
    final Map<String, String>? errorParams;

    if (e is SyncValidationException) {
      errorKey = e.code ?? SyncTranslationKeys.syncFailedError;
      errorParams = e.params;
      if (kDebugMode) {
        DomainLogger.debug('SyncValidationException caught! Code: ${e.code}, params: $errorParams');
      }
    } else {
      errorKey = SyncTranslationKeys.initiateOutgoingSyncFailedError;
      errorParams = null;
    }

    return OutgoingSyncResult(
      isComplete: false,
      syncedDeviceCount: 0,
      hadMeaningfulSync: false,
      errors: [errorKey],
      errorParams: errorParams,
    );
  }
}
