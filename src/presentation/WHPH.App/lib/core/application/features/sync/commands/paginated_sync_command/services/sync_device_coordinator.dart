import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Typedef for the DTO creation callback
typedef DtoCreator = Future<dynamic> Function(
  SyncDevice syncDevice,
  PaginatedSyncData localData,
  String entityType,
);

/// Service for coordinating sync device operations including consistency sync,
/// verification, and diagnostics.
class SyncDeviceCoordinator {
  final ISyncConfigurationService _configurationService;
  final ISyncCommunicationService _communicationService;
  final ISyncDeviceRepository _syncDeviceRepository;

  SyncDeviceCoordinator({
    required ISyncConfigurationService configurationService,
    required ISyncCommunicationService communicationService,
    required ISyncDeviceRepository syncDeviceRepository,
  })  : _configurationService = configurationService,
        _communicationService = communicationService,
        _syncDeviceRepository = syncDeviceRepository;

  /// Syncs updated sync device records back to the server for consistency.
  Future<void> syncUpdatedDevicesBackToServer(
    List<SyncDevice> updatedSyncDevices,
    DtoCreator createDto,
  ) async {
    try {
      Logger.info('Starting sync device consistency sync for ${updatedSyncDevices.length} devices');

      for (final updatedSyncDevice in updatedSyncDevices) {
        try {
          Logger.info('Syncing updated sync device ${updatedSyncDevice.id} back to server');

          final syncDeviceConfig = _configurationService.getConfiguration('SyncDevice');
          if (syncDeviceConfig == null) {
            Logger.error('SyncDevice configuration not found');
            continue;
          }

          final singleDeviceData = await syncDeviceConfig.getPaginatedSyncData(
            DateTime(2000),
            0,
            1,
            'SyncDevice',
          );

          final filteredData = filterSyncDataForSpecificDevice(singleDeviceData, updatedSyncDevice);

          if (filteredData.data.getTotalItemCount() > 0) {
            Logger.info('Sending updated sync device ${updatedSyncDevice.id} to server');

            final dto = await createDto(updatedSyncDevice, filteredData, 'SyncDevice');

            final targetIp = getTargetIpForDevice(updatedSyncDevice);
            if (targetIp.isNotEmpty) {
              final response = await _communicationService.sendPaginatedDataToDevice(targetIp, dto);
              if (response.success) {
                Logger.info('Successfully synced updated sync device ${updatedSyncDevice.id} back to server');
              } else {
                Logger.error('Failed to sync updated sync device ${updatedSyncDevice.id}: ${response.error}');
              }
            } else {
              Logger.error('Could not determine target IP for sync device ${updatedSyncDevice.id}');
            }
          } else {
            Logger.warning('No sync data found for updated sync device ${updatedSyncDevice.id}');
          }
        } catch (e) {
          Logger.error('Error syncing updated sync device ${updatedSyncDevice.id}: $e');
        }
      }

      Logger.info('Sync device consistency sync completed');
    } catch (e, stackTrace) {
      Logger.error('CRITICAL: Failed to sync updated sync devices back to server', error: e, stackTrace: stackTrace);
    }
  }

  /// Filters sync data to include only the specific sync device.
  PaginatedSyncData<SyncDevice> filterSyncDataForSpecificDevice(
    PaginatedSyncData syncData,
    SyncDevice targetDevice,
  ) {
    final filteredCreateSync = <SyncDevice>[];
    final filteredUpdateSync = <SyncDevice>[];
    final filteredDeleteSync = <SyncDevice>[];

    if (syncData.data.createSync.isNotEmpty) {
      for (final item in syncData.data.createSync) {
        if (item is SyncDevice && item.id == targetDevice.id) {
          filteredCreateSync.add(item);
        }
      }
    }

    if (syncData.data.updateSync.isNotEmpty) {
      for (final item in syncData.data.updateSync) {
        if (item is SyncDevice && item.id == targetDevice.id) {
          filteredUpdateSync.add(item);
        }
      }
    }

    if (filteredCreateSync.isEmpty && filteredUpdateSync.isEmpty) {
      filteredUpdateSync.add(targetDevice);
    }

    final filteredSyncData = SyncData<SyncDevice>(
      createSync: filteredCreateSync,
      updateSync: filteredUpdateSync,
      deleteSync: filteredDeleteSync,
    );

    return PaginatedSyncData<SyncDevice>(
      data: filteredSyncData,
      pageIndex: 0,
      pageSize: 1,
      totalPages: 1,
      totalItems: filteredSyncData.getTotalItemCount(),
      isLastPage: true,
      entityType: 'SyncDevice',
    );
  }

  /// Gets target IP address for a sync device.
  String getTargetIpForDevice(SyncDevice syncDevice) {
    return syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
  }

  /// Verifies that sync date updates were properly applied to all devices.
  Future<void> verifySyncDateUpdates(List<SyncDevice> updatedSyncDevices) async {
    Logger.info('Starting verification of sync date updates for ${updatedSyncDevices.length} devices');

    for (final device in updatedSyncDevices) {
      final verificationDevice = await _syncDeviceRepository.getById(device.id);
      if (verificationDevice != null) {
        if (verificationDevice.lastSyncDate != null) {
          Logger.info('Sync date verification passed for device ${device.id}: ${verificationDevice.lastSyncDate}');
        } else {
          Logger.error('Sync date verification failed for device ${device.id}: lastSyncDate is still null');
        }
      } else {
        Logger.error('Could not verify sync date for device ${device.id}: device not found in repository');
      }
    }
  }

  /// Enhanced diagnostics to help identify sync issues vs empty databases.
  Future<void> logSyncDiagnostics(List<SyncDevice> allDevices, List<SyncDevice> successfulDevices) async {
    Logger.info('SYNC DIAGNOSTICS SUMMARY');
    Logger.info('═══════════════════════════');

    final configs = _configurationService.getAllConfigurations();
    int totalActiveItems = 0;
    int totalAllItems = 0;
    int entitiesWithActiveData = 0;

    for (final config in configs) {
      try {
        final allItems = await config.repository.getAll(includeDeleted: true);
        final totalCount = allItems.length;
        final activeCount = allItems.where((item) => item.deletedDate == null).length;
        final deletedCount = totalCount - activeCount;

        totalActiveItems += activeCount;
        totalAllItems += totalCount;

        if (totalCount > 0) {
          if (activeCount > 0) {
            entitiesWithActiveData++;
          }
          Logger.info(
              '${config.name}: $activeCount active / $totalCount total items locally (soft-deleted: $deletedCount)');
        }
      } catch (e) {
        Logger.warning('Failed to check ${config.name} data: $e');
      }
    }

    if (totalAllItems == 0) {
      Logger.warning('DIAGNOSIS: This device has NO LOCAL DATA to sync');
      Logger.warning('This is likely a fresh installation or the app hasn\'t collected data yet');
      Logger.warning('Recommended: Use the app to create tasks, habits, track app usage, etc.');
    } else {
      Logger.info(
          'DIAGNOSIS: Device has $totalActiveItems active items and $totalAllItems total (including soft-deleted) across $entitiesWithActiveData entity types');
    }

    Logger.info('Sync Device Status:');
    for (final device in allDevices) {
      final isSuccessful = successfulDevices.contains(device);
      final status = isSuccessful ? 'SUCCESS' : 'FAILED';
      Logger.info('${device.id} (${device.fromIp} ↔ ${device.toIp}): $status');
      if (device.lastSyncDate != null) {
        Logger.info('Last sync: ${device.lastSyncDate}');
      } else {
        Logger.info('Last sync: Never (initial sync)');
      }
    }
    Logger.info('═══════════════════════════');
  }
}
