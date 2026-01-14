import 'package:whph/core/application/features/sync/services/sync_conflict_resolution_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Handler for processing SyncDevice entities during sync.
///
/// This handler provides specialized logic for SyncDevice entities,
/// including device pair detection, merging, and verification.
class SyncDeviceProcessingHandler {
  final SyncConflictResolutionService _conflictResolutionService;
  final Future<void> Function() onYieldToUI;

  SyncDeviceProcessingHandler({
    SyncConflictResolutionService? conflictResolutionService,
    required this.onYieldToUI,
  }) : _conflictResolutionService = conflictResolutionService ?? SyncConflictResolutionService();

  /// Process a SyncDevice entity with special handling for device pair management
  Future<int> processSyncDeviceItem(
    SyncDevice syncDevice,
    IRepository<SyncDevice, String> repository,
    String operationType,
  ) async {
    Logger.info('Special handling for SyncDevice entity ${syncDevice.id} ($operationType)');
    Logger.info(
        'SyncDevice details: ${syncDevice.fromDeviceId} (${syncDevice.fromIp}) → ${syncDevice.toDeviceId} (${syncDevice.toIp})');

    try {
      switch (operationType) {
        case 'create':
          return await _handleCreate(syncDevice, repository);
        case 'update':
          return await _handleUpdate(syncDevice, repository);
        case 'delete':
          return await _handleDelete(syncDevice, repository);
        default:
          Logger.error('Unknown operation type for SyncDevice: $operationType');
          return 0;
      }
    } catch (e) {
      Logger.error('Error processing SyncDevice ${syncDevice.id} ($operationType): $e');
      rethrow;
    }
  }

  Future<int> _handleCreate(SyncDevice syncDevice, IRepository<SyncDevice, String> repository) async {
    await onYieldToUI();

    // First check if the exact same device record exists
    SyncDevice? existingDeviceById = await repository.getById(syncDevice.id, includeDeleted: true);

    // Check for existing device pair relationship
    final allDevices = await repository.getAll();
    SyncDevice? existingDevicePair = _findExistingDevicePair(allDevices, syncDevice);

    await onYieldToUI();

    if (existingDeviceById == null && existingDevicePair == null) {
      // No existing device at all, create it
      Logger.debug('Creating new SyncDevice: ${syncDevice.id}');
      await repository.add(syncDevice);
      await onYieldToUI();
      Logger.info('Created SyncDevice: ${syncDevice.id}');
      return 1;
    } else if (existingDeviceById != null) {
      // Exact same device exists, update it with remote data
      Logger.debug('Updating existing SyncDevice by ID: ${syncDevice.id}');
      await repository.update(syncDevice);
      await onYieldToUI();
      await _verifyUpdate(repository, syncDevice);
      Logger.info('Updated SyncDevice: ${syncDevice.id}');
      return 1;
    } else if (existingDevicePair != null) {
      // Device pair exists but with different ID/direction - merge
      return await _mergeDevicePair(existingDevicePair, syncDevice, repository);
    }

    return 0;
  }

  Future<int> _handleUpdate(SyncDevice syncDevice, IRepository<SyncDevice, String> repository) async {
    await onYieldToUI();
    // CRITICAL FIX: Must include soft-deleted items in lookup.
    // Otherwise, if the item exists but is soft-deleted, getById returns null,
    // leading to an attempt to .add() (INSERT) which violates the UNIQUE ID constraint.
    SyncDevice? existingDevice = await repository.getById(syncDevice.id, includeDeleted: true);
    await onYieldToUI();

    if (existingDevice != null) {
      Logger.debug('Updating SyncDevice: ${syncDevice.id}');
      // If it was soft-deleted, this update will revive it if deletedDate is null in syncDevice
      await repository.update(syncDevice);
      await onYieldToUI();
      await _verifyUpdate(repository, syncDevice);
      Logger.info('Updated SyncDevice: ${syncDevice.id}');
      return 1;
    } else {
      // Device doesn't exist, create it
      Logger.debug('Creating SyncDevice from update: ${syncDevice.id}');
      await repository.add(syncDevice);
      await onYieldToUI();
      await _verifyCreate(repository, syncDevice);
      Logger.info('Created SyncDevice from update: ${syncDevice.id}');
      return 1;
    }
  }

  Future<int> _handleDelete(SyncDevice syncDevice, IRepository<SyncDevice, String> repository) async {
    await onYieldToUI();
    // Also include soft-deleted here for consistency
    SyncDevice? existingDevice = await repository.getById(syncDevice.id, includeDeleted: true);
    await onYieldToUI();

    if (existingDevice != null) {
      final resolution = _conflictResolutionService.resolveConflict(existingDevice, syncDevice);
      switch (resolution.action) {
        case ConflictAction.keepLocal:
          Logger.debug('Keeping local version of SyncDevice ${syncDevice.id}, ignoring delete');
          break;
        case ConflictAction.acceptRemote:
        case ConflictAction.acceptRemoteForceUpdate:
          Logger.debug('Soft-deleting SyncDevice ${syncDevice.id} as requested by remote');
          await onYieldToUI();
          await repository.delete(syncDevice);
          await onYieldToUI();
          break;
      }
    } else {
      Logger.debug('Delete operation for non-existing SyncDevice ${syncDevice.id}, skipping');
    }
    return 1;
  }

  SyncDevice? _findExistingDevicePair(List<SyncDevice> allDevices, SyncDevice syncDevice) {
    for (final existing in allDevices) {
      final sameDevicePair =
          (existing.fromDeviceId == syncDevice.fromDeviceId && existing.toDeviceId == syncDevice.toDeviceId) ||
              (existing.fromDeviceId == syncDevice.toDeviceId && existing.toDeviceId == syncDevice.fromDeviceId);

      if (sameDevicePair && existing.id != syncDevice.id) {
        Logger.info('Found existing device pair: ${existing.id} (${existing.fromDeviceId} ↔ ${existing.toDeviceId})');
        return existing;
      }
    }
    return null;
  }

  Future<int> _mergeDevicePair(
    SyncDevice existingDevicePair,
    SyncDevice syncDevice,
    IRepository<SyncDevice, String> repository,
  ) async {
    Logger.info(
        'Merging SyncDevice data: updating existing device ${existingDevicePair.id} with data from ${syncDevice.id}');

    final mergedDevice = SyncDevice(
      id: existingDevicePair.id,
      createdDate: existingDevicePair.createdDate,
      modifiedDate: DateTime.now().toUtc(),
      fromIp: syncDevice.fromIp,
      toIp: syncDevice.toIp,
      fromDeviceId: syncDevice.fromDeviceId,
      toDeviceId: syncDevice.toDeviceId,
      name: syncDevice.name,
      lastSyncDate: syncDevice.lastSyncDate,
      deletedDate: null,
    );

    await repository.update(mergedDevice);
    await onYieldToUI();
    await _verifyUpdate(repository, mergedDevice);
    Logger.info('Merged SyncDevice: ${existingDevicePair.id} updated with data from ${syncDevice.id}');
    return 1;
  }

  Future<void> _verifyUpdate(IRepository<SyncDevice, String> repository, SyncDevice syncDevice) async {
    // Also check soft-deleted during verification to be safe
    final verificationDevice = await repository.getById(syncDevice.id, includeDeleted: true);
    if (verificationDevice != null) {
      Logger.debug(
          'Verification: SyncDevice ${syncDevice.id} re-read from DB with lastSyncDate=${verificationDevice.lastSyncDate}');
      if (verificationDevice.lastSyncDate == null && syncDevice.lastSyncDate != null) {
        Logger.warning('CRITICAL: Database update verification failed - lastSyncDate is still null after update!');
        await repository.update(syncDevice);
      } else {
        Logger.debug('Database update verification passed - lastSyncDate properly persisted');
      }
    } else {
      Logger.error('CRITICAL: Could not re-read sync device ${syncDevice.id} from database for verification');
    }
  }

  Future<void> _verifyCreate(IRepository<SyncDevice, String> repository, SyncDevice syncDevice) async {
    // Also check soft-deleted here
    final verificationDevice = await repository.getById(syncDevice.id, includeDeleted: true);
    if (verificationDevice != null) {
      Logger.debug(
          'Verification: Created SyncDevice ${syncDevice.id} re-read from DB with lastSyncDate=${verificationDevice.lastSyncDate}');
      if (verificationDevice.lastSyncDate == null && syncDevice.lastSyncDate != null) {
        Logger.warning('CRITICAL: Database create verification failed - lastSyncDate is still null after creation!');
        await repository.update(syncDevice);
      } else {
        Logger.debug('Database create verification passed - lastSyncDate properly set');
      }
    } else {
      Logger.error('CRITICAL: Could not re-read created sync device ${syncDevice.id} from database for verification');
    }
  }
}
