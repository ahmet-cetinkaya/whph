import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_data_processing_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tags/tag_tag.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart';

class PaginatedSyncCommand implements IRequest<PaginatedSyncCommandResponse> {
  final PaginatedSyncDataDto? paginatedSyncDataDto;
  final String? targetDeviceId;

  PaginatedSyncCommand({this.paginatedSyncDataDto, this.targetDeviceId});
}

@jsonSerializable
class PaginatedSyncCommandResponse {
  final PaginatedSyncDataDto? paginatedSyncDataDto;
  final bool isComplete;
  final String? nextEntityType;
  final int? nextPageIndex;
  final int syncedDeviceCount;
  final bool hadMeaningfulSync;
  final bool hasErrors;
  final List<String> errorMessages;

  PaginatedSyncCommandResponse({
    this.paginatedSyncDataDto,
    this.isComplete = false,
    this.nextEntityType,
    this.nextPageIndex,
    this.syncedDeviceCount = 0,
    this.hadMeaningfulSync = false,
    this.hasErrors = false,
    this.errorMessages = const [],
  });
}

class PaginatedSyncCommandHandler implements IRequestHandler<PaginatedSyncCommand, PaginatedSyncCommandResponse> {
  final ISyncDeviceRepository _syncDeviceRepository;
  final ISyncConfigurationService _configurationService;
  final ISyncValidationService _validationService;
  final ISyncCommunicationService _communicationService;
  final ISyncDataProcessingService _dataProcessingService;
  final ISyncPaginationService _paginationService;

  PaginatedSyncCommandHandler({
    required ISyncDeviceRepository syncDeviceRepository,
    required ISyncConfigurationService configurationService,
    required ISyncValidationService validationService,
    required ISyncCommunicationService communicationService,
    required ISyncDataProcessingService dataProcessingService,
    required ISyncPaginationService paginationService,
  })  : _syncDeviceRepository = syncDeviceRepository,
        _configurationService = configurationService,
        _validationService = validationService,
        _communicationService = communicationService,
        _dataProcessingService = dataProcessingService,
        _paginationService = paginationService;

  /// Progress stream from pagination service
  Stream<SyncProgress> get progressStream => _paginationService.progressStream;

  @override
  Future<PaginatedSyncCommandResponse> call(PaginatedSyncCommand request) async {
    Logger.info('🚀 Starting paginated sync operation');
    Logger.debug(
        '📝 Request details: targetDeviceId=${request.targetDeviceId}, hasIncomingData=${request.paginatedSyncDataDto != null}');

    try {
      if (request.paginatedSyncDataDto != null) {
        Logger.info('📨 Handling incoming sync data');
        return await _handleIncomingSync(request.paginatedSyncDataDto!);
      } else {
        Logger.info('📤 Initiating outgoing sync');
        return await _initiateOutgoingSync(request.targetDeviceId);
      }
    } catch (e, stackTrace) {
      Logger.error('❌ CRITICAL: Paginated sync operation failed: $e');
      Logger.error('🔍 Stack trace: $stackTrace');
      return PaginatedSyncCommandResponse(
        isComplete: false,
        syncedDeviceCount: 0,
        hadMeaningfulSync: false,
        hasErrors: true,
        errorMessages: ['Critical sync operation failed: $e'],
      );
    }
  }

  Future<PaginatedSyncCommandResponse> _handleIncomingSync(PaginatedSyncDataDto dto) async {
    Logger.info('📨 Processing incoming paginated sync data from remote device');

    // Debug: Log DTO contents for SyncDevice
    Logger.info('🔍 DTO entity type: ${dto.entityType}');
    if (dto.entityType == 'SyncDevice') {
      Logger.info(
          '🔍 SyncDevice DTO details: syncDevicesSyncData is ${dto.syncDevicesSyncData != null ? "not null" : "null"}');
      if (dto.syncDevicesSyncData != null) {
        Logger.info(
            '🔍 SyncDevice data: creates=${dto.syncDevicesSyncData!.data.createSync.length}, updates=${dto.syncDevicesSyncData!.data.updateSync.length}, deletes=${dto.syncDevicesSyncData!.data.deleteSync.length}');
        Logger.info('🔍 SyncDevice total count: ${dto.syncDevicesSyncData!.data.getTotalItemCount()}');
      } else {
        Logger.warning(
            '⚠️ SyncDevice DTO is null but entity type is SyncDevice - this indicates a serialization issue');
      }
    }

    // Additional debug for all entity types to understand what data is present
    Logger.info('🔍 DTO contents summary:');
    Logger.info(
        '   - appUsagesSyncData: ${dto.appUsagesSyncData != null ? "${dto.appUsagesSyncData!.data.getTotalItemCount()} items" : "null"}');
    Logger.info(
        '   - appUsageTagsSyncData: ${dto.appUsageTagsSyncData != null ? "${dto.appUsageTagsSyncData!.data.getTotalItemCount()} items" : "null"}');
    Logger.info(
        '   - syncDevicesSyncData: ${dto.syncDevicesSyncData != null ? "${dto.syncDevicesSyncData!.data.getTotalItemCount()} items" : "null"}');
    Logger.info(
        '   - tasksSyncData: ${dto.tasksSyncData != null ? "${dto.tasksSyncData!.data.getTotalItemCount()} items" : "null"}');
    Logger.info(
        '   - habitsSyncData: ${dto.habitsSyncData != null ? "${dto.habitsSyncData!.data.getTotalItemCount()} items" : "null"}');

    // Validate incoming data
    await _validationService.validateVersion(dto.appVersion);
    await _validationService.validateDeviceId(dto.syncDevice);
    _validationService.validateEnvironmentMode(dto);

    // Note: SyncDevice auto-pairing logic removed - now handled during data processing

    // Process the incoming DTO data
    int processedCount = 0;
    List<String> processingErrors = [];
    try {
      processedCount = await _processPaginatedSyncDto(dto);
      Logger.info('✅ Processed $processedCount items from incoming sync data');
    } catch (e) {
      Logger.error('❌ Error processing incoming sync data: $e');
      processingErrors.add(e.toString());
    }

    // For bidirectional sync, check if we have local data to send back
    Logger.info('🔄 Checking for local data to send back for entity: ${dto.entityType}');
    bool hasLocalDataToSend = false;
    PaginatedSyncDataDto? responseDto;

    try {
      // Get the configuration for this entity type
      final config = _configurationService.getConfiguration(dto.entityType);
      if (config != null) {
        // Check if we have local data for this entity type
        final syncDevice = dto.syncDevice;
        final lastSyncDate = syncDevice.lastSyncDate ?? DateTime(2000);

        Logger.info('📤 Checking local ${dto.entityType} data count (page ${dto.pageIndex})');

        final localData = await config.getPaginatedSyncData(
          lastSyncDate,
          dto.pageIndex,
          dto.pageSize,
          dto.entityType,
        );

        Logger.info(
            '📊 Local ${dto.entityType} data check: ${localData.data.getTotalItemCount()} items, page ${dto.pageIndex}/${localData.totalPages - 1}');

        if (localData.data.getTotalItemCount() > 0) {
          hasLocalDataToSend = true;
          Logger.info('✅ Local device has ${dto.entityType} data to send back');

          // Actually send the local data back to the client
          Logger.info(
              '📤 Creating response DTO with local ${dto.entityType} data (${localData.data.getTotalItemCount()} items)');
          responseDto = await _createBidirectionalResponseDto(syncDevice, localData, dto.entityType);
        } else {
          Logger.info('📋 No local ${dto.entityType} data to send back (page ${dto.pageIndex})');
        }
      }
    } catch (e) {
      Logger.error('❌ Error checking local data: $e');
    }

    // Return response with actual data if we have it
    return PaginatedSyncCommandResponse(
      paginatedSyncDataDto: responseDto,
      isComplete: !hasLocalDataToSend &&
          processingErrors.isEmpty, // Not complete if we have data to send back or errors occurred
      syncedDeviceCount: 1,
      hadMeaningfulSync: true,
      hasErrors: processingErrors.isNotEmpty,
      errorMessages: processingErrors,
    );
  }

  Future<PaginatedSyncCommandResponse> _initiateOutgoingSync(String? targetDeviceId) async {
    Logger.info('📤 Initiating outgoing paginated sync');
    Logger.debug('🎯 Target device ID: $targetDeviceId');

    try {
      // Get all devices to sync with
      Logger.debug('🔍 Fetching sync devices from repository...');
      final allDevices = await _syncDeviceRepository.getAll();
      Logger.info('📋 Found ${allDevices.length} sync devices in database');

      for (int i = 0; i < allDevices.length; i++) {
        final device = allDevices[i];
        Logger.debug(
            '🔗 Device $i: ID=${device.id}, fromIp=${device.fromIp}, toIp=${device.toIp}, fromDeviceId=${device.fromDeviceId}, toDeviceId=${device.toDeviceId}, lastSyncDate=${device.lastSyncDate}');
      }

      if (allDevices.isEmpty) {
        Logger.warning('⚠️ No devices configured for sync');
        return PaginatedSyncCommandResponse(
          isComplete: true,
          syncedDeviceCount: 0,
          hadMeaningfulSync: false,
          hasErrors: false,
          errorMessages: [],
        );
      }

      // Reset progress tracking
      Logger.debug('🔄 Resetting pagination progress...');
      _paginationService.resetProgress();

      final successfulDevices = <SyncDevice>[];
      bool allDevicesSynced = true;
      DateTime? oldestLastSyncDate;

      // Sync with each device
      Logger.info('🔄 Starting sync with ${allDevices.length} devices...');
      for (int i = 0; i < allDevices.length; i++) {
        final syncDevice = allDevices[i];
        Logger.info('🔄 Syncing with device ${i + 1}/${allDevices.length}: ${syncDevice.id}');

        try {
          final success = await _syncWithDevice(syncDevice);
          if (success) {
            Logger.info('✅ Successfully synced with device ${syncDevice.id}');
            successfulDevices.add(syncDevice);
            oldestLastSyncDate = oldestLastSyncDate == null
                ? syncDevice.lastSyncDate
                : (syncDevice.lastSyncDate!.isBefore(oldestLastSyncDate)
                    ? syncDevice.lastSyncDate
                    : oldestLastSyncDate);
          } else {
            Logger.error('❌ Failed to sync with device ${syncDevice.id}');
            allDevicesSynced = false;
          }
        } catch (e, stackTrace) {
          Logger.error('❌ CRITICAL: Exception during sync with device ${syncDevice.id}: $e');
          Logger.error('🔍 Stack trace: $stackTrace');
          allDevicesSynced = false;
        }
      }
      // Update last sync date only if all devices synced successfully
      if (allDevicesSynced) {
        Logger.info('📅 Updating last sync dates for ${successfulDevices.length} successful devices');
        final updatedSyncDevices = <SyncDevice>[];

        for (final syncDevice in successfulDevices) {
          syncDevice.lastSyncDate = DateTime.now();
          await _syncDeviceRepository.update(syncDevice);
          updatedSyncDevices.add(syncDevice);
        }

        // Sync the updated sync device records back to the server for consistency
        if (updatedSyncDevices.isNotEmpty) {
          Logger.info('🔄 Syncing updated sync device records back to server for consistency');
          await _syncUpdatedSyncDevicesBackToServer(updatedSyncDevices);
        }
      } else {
        Logger.warning('⚠️ Not updating sync dates due to sync failures');
      }

      Logger.info(allDevicesSynced
          ? '✅ Paginated sync operation completed successfully'
          : '⚠️ Paginated sync operation completed with some failures');

      return PaginatedSyncCommandResponse(
        isComplete: allDevicesSynced,
        syncedDeviceCount: successfulDevices.length,
        hadMeaningfulSync: successfulDevices.isNotEmpty,
        hasErrors: !allDevicesSynced,
        errorMessages: !allDevicesSynced ? ['Some devices failed to sync'] : [],
      );
    } catch (e, stackTrace) {
      Logger.error('❌ CRITICAL: Failed to initiate outgoing sync: $e');
      Logger.error('🔍 Stack trace: $stackTrace');
      return PaginatedSyncCommandResponse(
        isComplete: false,
        syncedDeviceCount: 0,
        hadMeaningfulSync: false,
        hasErrors: true,
        errorMessages: ['Failed to initiate outgoing sync: $e'],
      );
    }
  }

  Future<bool> _syncWithDevice(SyncDevice syncDevice) async {
    Logger.info('🔄 Starting sync with device ${syncDevice.id}');
    Logger.debug(
        '📋 Device details: fromIp=${syncDevice.fromIp}, toIp=${syncDevice.toIp}, fromDeviceId=${syncDevice.fromDeviceId}, toDeviceId=${syncDevice.toDeviceId}');
    Logger.debug('📅 Last sync date: ${syncDevice.lastSyncDate}');

    try {
      // Test connectivity first
      Logger.debug('🌐 Determining target IP for device ${syncDevice.id}...');
      final targetIp = await _getTargetIp(syncDevice);
      if (targetIp.isEmpty) {
        Logger.error('❌ Could not determine target IP for device ${syncDevice.id}');
        return false;
      }

      Logger.info('📡 Testing connectivity to $targetIp for device ${syncDevice.id}...');
      final isReachable = await _communicationService.isDeviceReachable(targetIp);
      if (!isReachable) {
        Logger.error('❌ Device ${syncDevice.id} is not reachable at $targetIp');
        return false;
      }

      Logger.info('✅ Device ${syncDevice.id} is reachable at $targetIp');

      // Sync each entity type
      Logger.debug('📝 Getting entity configurations...');
      final configs = _configurationService.getAllConfigurations();
      Logger.info('🔄 Syncing ${configs.length} entity types with device ${syncDevice.id}');

      for (int i = 0; i < configs.length; i++) {
        final config = configs[i];
        Logger.info('🔄 Syncing entity ${i + 1}/${configs.length}: ${config.name} with device ${syncDevice.id}');

        try {
          final lastSyncDate = syncDevice.lastSyncDate ?? DateTime(2000);
          Logger.info(
              '📅 Using last sync date: $lastSyncDate for ${config.name} (device lastSync: ${syncDevice.lastSyncDate})');

          // Debug: Check if we're using the fallback date
          if (syncDevice.lastSyncDate == null) {
            Logger.info('🔍 Device has no previous sync date - using DateTime(2000) to get ALL data');
          } else {
            Logger.info('🔍 Device has previous sync date - getting data modified after ${syncDevice.lastSyncDate}');
          }

          final success = await _paginationService.syncEntityWithPagination(
            config,
            syncDevice,
            lastSyncDate,
          );

          if (!success) {
            Logger.error('❌ Failed to sync ${config.name} with device ${syncDevice.id}');
            return false;
          }

          Logger.info('✅ Successfully synced ${config.name} with device ${syncDevice.id}');
        } catch (e, stackTrace) {
          Logger.error('❌ CRITICAL: Exception during ${config.name} sync with device ${syncDevice.id}: $e');
          Logger.error('🔍 Stack trace: $stackTrace');
          return false;
        }
      }

      Logger.info('✅ Successfully synced all ${configs.length} entities with device ${syncDevice.id}');

      // Process any pending response data from bidirectional sync
      final pendingResponseData = _paginationService.getPendingResponseData();
      if (pendingResponseData.isNotEmpty) {
        Logger.info('📨 Processing ${pendingResponseData.length} pending response DTOs from bidirectional sync');

        int totalProcessedFromResponses = 0;
        for (final entry in pendingResponseData.entries) {
          final entityType = entry.key;
          final responseDto = entry.value;

          try {
            Logger.info('📨 Processing bidirectional response data for $entityType');
            final processedCount = await _processPaginatedSyncDto(responseDto);
            totalProcessedFromResponses += processedCount;
            Logger.info('✅ Processed $processedCount items from $entityType response data');
          } catch (e) {
            Logger.error('❌ Failed to process response data for $entityType: $e');
          }
        }

        Logger.info('✅ Total items processed from bidirectional responses: $totalProcessedFromResponses');
        _paginationService.clearPendingResponseData();
      }

      return true;
    } catch (e, stackTrace) {
      Logger.error('❌ CRITICAL: Exception in _syncWithDevice for ${syncDevice.id}: $e');
      Logger.error('🔍 Stack trace: $stackTrace');
      return false;
    }
  }

  Future<String> _getTargetIp(SyncDevice syncDevice) async {
    // Determine which IP to use based on the sync direction
    // This is a simplified implementation - in reality you'd need to check device IDs
    return syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
  }

  Future<int> _processPaginatedSyncDto(PaginatedSyncDataDto dto) async {
    int totalProcessed = 0;

    // Process each entity type in the DTO
    final configs = _configurationService.getAllConfigurations();
    for (final config in configs) {
      final syncData = config.getPaginatedSyncDataFromDto(dto);
      Logger.debug('🔍 Processing ${config.name}: syncData is null: ${syncData == null}');

      if (syncData != null) {
        final itemCount = syncData.data.getTotalItemCount();
        Logger.info('🔍 ${config.name} sync data: $itemCount total items');
        if (itemCount > 0) {
          final processedCount = await _dataProcessingService.processSyncDataBatchDynamic(
            syncData.data,
            config.repository,
          );
          totalProcessed += processedCount;
          Logger.info('✅ Processed $processedCount ${config.name} items');
        } else {
          Logger.info('⏭️ Skipping ${config.name} - no items to process');
        }
      } else {
        Logger.info('⏭️ Skipping ${config.name} - no sync data found in DTO');
      }
    }

    return totalProcessed;
  }

  Future<PaginatedSyncDataDto> _createBidirectionalResponseDto(
    SyncDevice syncDevice,
    PaginatedSyncData localData,
    String entityType,
  ) async {
    Logger.info(
        '🔧 Creating bidirectional response DTO for $entityType with ${localData.data.getTotalItemCount()} items');

    // Create the response DTO with the actual local data based on entity type
    switch (entityType) {
      case 'AppUsage':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          appUsagesSyncData: localData as PaginatedSyncData<AppUsage>?,
        );

      case 'AppUsageTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          appUsageTagsSyncData: localData as PaginatedSyncData<AppUsageTag>?,
        );

      case 'AppUsageTimeRecord':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          appUsageTimeRecordsSyncData: localData as PaginatedSyncData<AppUsageTimeRecord>?,
        );

      case 'AppUsageTagRule':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          appUsageTagRulesSyncData: localData as PaginatedSyncData<AppUsageTagRule>?,
        );

      case 'AppUsageIgnoreRule':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          appUsageIgnoreRulesSyncData: localData as PaginatedSyncData<AppUsageIgnoreRule>?,
        );

      case 'Task':
        final itemCount = localData.data.getTotalItemCount();
        Logger.debug('🔧 COMMAND Task DTO - ENTRY: itemCount=$itemCount, totalItems=${localData.totalItems}');
        Logger.debug(
            '🔧 COMMAND Task DTO - createSync: ${localData.data.createSync.length}, updateSync: ${localData.data.updateSync.length}');

        final paginatedSyncData = localData as PaginatedSyncData<Task>;
        final tasksData = itemCount > 0 ? paginatedSyncData : null;
        Logger.debug('🔧 COMMAND Task DTO - tasksData null: ${tasksData == null}');

        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          tasksSyncData: tasksData,
        );

      case 'TaskTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          taskTagsSyncData: localData as PaginatedSyncData<TaskTag>?,
        );

      case 'TaskTimeRecord':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          taskTimeRecordsSyncData: localData as PaginatedSyncData<TaskTimeRecord>?,
        );

      case 'Habit':
        final itemCount = localData.data.getTotalItemCount();
        final paginatedSyncData = localData as PaginatedSyncData<Habit>;
        final habitsData = itemCount > 0 ? paginatedSyncData : null;
        Logger.debug('🔧 COMMAND Habit DTO - itemCount: $itemCount, habitsData null: ${habitsData == null}');

        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          habitsSyncData: habitsData,
        );

      case 'HabitRecord':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          habitRecordsSyncData: localData as PaginatedSyncData<HabitRecord>?,
        );

      case 'HabitTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          habitTagsSyncData: localData as PaginatedSyncData<HabitTag>?,
        );

      case 'Tag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          tagsSyncData: localData as PaginatedSyncData<Tag>?,
        );

      case 'TagTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          tagTagsSyncData: localData as PaginatedSyncData<TagTag>?,
        );

      case 'Setting':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          settingsSyncData: localData as PaginatedSyncData<Setting>?,
        );

      case 'SyncDevice':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          syncDevicesSyncData: localData as PaginatedSyncData<SyncDevice>?,
        );

      case 'Note':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          notesSyncData: localData as PaginatedSyncData<Note>?,
        );

      case 'NoteTag':
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
          noteTagsSyncData: localData as PaginatedSyncData<NoteTag>?,
        );

      default:
        Logger.warning('⚠️ Unknown entity type for bidirectional sync: $entityType');
        return PaginatedSyncDataDto(
          appVersion: AppInfo.version,
          syncDevice: syncDevice,
          isDebugMode: kDebugMode,
          entityType: entityType,
          pageIndex: localData.pageIndex,
          pageSize: localData.pageSize,
          totalPages: localData.totalPages,
          totalItems: localData.totalItems,
          isLastPage: localData.isLastPage,
        );
    }
  }

  /// Syncs updated sync device records back to the server for consistency
  /// This ensures that when the client updates lastSyncDate, the server is also updated
  Future<void> _syncUpdatedSyncDevicesBackToServer(List<SyncDevice> updatedSyncDevices) async {
    try {
      Logger.info('📡 Starting sync device consistency sync for ${updatedSyncDevices.length} devices');

      for (final updatedSyncDevice in updatedSyncDevices) {
        try {
          Logger.info('🔄 Syncing updated sync device ${updatedSyncDevice.id} back to server');

          // Get the SyncDevice configuration
          final syncDeviceConfig = _configurationService.getConfiguration('SyncDevice');
          if (syncDeviceConfig == null) {
            Logger.error('❌ SyncDevice configuration not found');
            continue;
          }

          // Create paginated sync data for this single updated sync device
          final singleDeviceData = await syncDeviceConfig.getPaginatedSyncData(
            DateTime(2000), // Use old date to ensure this device is included
            0, // First page
            1, // Only one item
            'SyncDevice',
          );

          // Filter to only include our specific updated device
          final filteredData = _filterSyncDataForSpecificDevice(singleDeviceData, updatedSyncDevice);

          if (filteredData.data.getTotalItemCount() > 0) {
            Logger.info('📤 Sending updated sync device ${updatedSyncDevice.id} to server');

            // Create DTO for the updated sync device
            final dto = await _createBidirectionalResponseDto(updatedSyncDevice, filteredData, 'SyncDevice');

            // Send to the server via the same communication mechanism
            final targetIp = await _getTargetIpForDevice(updatedSyncDevice);
            if (targetIp.isNotEmpty) {
              final response = await _communicationService.sendPaginatedDataToDevice(targetIp, dto);
              if (response.success) {
                Logger.info('✅ Successfully synced updated sync device ${updatedSyncDevice.id} back to server');
              } else {
                Logger.error('❌ Failed to sync updated sync device ${updatedSyncDevice.id}: ${response.error}');
              }
            } else {
              Logger.error('❌ Could not determine target IP for sync device ${updatedSyncDevice.id}');
            }
          } else {
            Logger.warning('⚠️ No sync data found for updated sync device ${updatedSyncDevice.id}');
          }
        } catch (e) {
          Logger.error('❌ Error syncing updated sync device ${updatedSyncDevice.id}: $e');
        }
      }

      Logger.info('✅ Sync device consistency sync completed');
    } catch (e, stackTrace) {
      Logger.error('❌ CRITICAL: Failed to sync updated sync devices back to server: $e');
      Logger.error('🔍 Stack trace: $stackTrace');
    }
  }

  /// Filters sync data to include only the specific sync device
  PaginatedSyncData<SyncDevice> _filterSyncDataForSpecificDevice(
    PaginatedSyncData syncData,
    SyncDevice targetDevice,
  ) {
    // Create filtered sync data containing only the target device
    final filteredCreateSync = <SyncDevice>[];
    final filteredUpdateSync = <SyncDevice>[];
    final filteredDeleteSync = <SyncDevice>[];

    // Check create sync items
    if (syncData.data.createSync.isNotEmpty) {
      for (final item in syncData.data.createSync) {
        if (item is SyncDevice && item.id == targetDevice.id) {
          filteredCreateSync.add(item);
        }
      }
    }

    // Check update sync items
    if (syncData.data.updateSync.isNotEmpty) {
      for (final item in syncData.data.updateSync) {
        if (item is SyncDevice && item.id == targetDevice.id) {
          filteredUpdateSync.add(item);
        }
      }
    }

    // Since we just updated the device, it should be in updateSync
    // If not found in existing sync data, add it to updateSync
    if (filteredCreateSync.isEmpty && filteredUpdateSync.isEmpty) {
      filteredUpdateSync.add(targetDevice);
    }

    // Create new sync data with filtered items
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

  /// Gets target IP address for a sync device
  Future<String> _getTargetIpForDevice(SyncDevice syncDevice) async {
    // Use the same logic as in _getTargetIp but for a specific device
    return syncDevice.fromIp.isNotEmpty ? syncDevice.fromIp : syncDevice.toIp;
  }
}
