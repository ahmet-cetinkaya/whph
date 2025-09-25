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
import 'package:whph/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
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
  final IDeviceIdService _deviceIdService;
  final Mediator _mediator;

  PaginatedSyncCommandHandler({
    required ISyncDeviceRepository syncDeviceRepository,
    required ISyncConfigurationService configurationService,
    required ISyncValidationService validationService,
    required ISyncCommunicationService communicationService,
    required ISyncDataProcessingService dataProcessingService,
    required ISyncPaginationService paginationService,
    required IDeviceIdService deviceIdService,
    required Mediator mediator,
  })  : _syncDeviceRepository = syncDeviceRepository,
        _configurationService = configurationService,
        _validationService = validationService,
        _communicationService = communicationService,
        _dataProcessingService = dataProcessingService,
        _paginationService = paginationService,
        _deviceIdService = deviceIdService,
        _mediator = mediator;

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
      }
    }

    // Validate incoming data
    await _validationService.validateVersion(dto.appVersion);
    await _validationService.validateDeviceId(dto.syncDevice);
    _validationService.validateEnvironmentMode(dto);

    // Auto-create SyncDevice record if this is a new device pairing
    await _ensureSyncDeviceExists(dto);

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
        for (final syncDevice in successfulDevices) {
          syncDevice.lastSyncDate = DateTime.now();
          await _syncDeviceRepository.update(syncDevice);
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
          tasksSyncData: localData as PaginatedSyncData<Task>?,
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
          habitsSyncData: localData as PaginatedSyncData<Habit>?,
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

  /// Ensure a SyncDevice record exists for the connecting client device
  Future<void> _ensureSyncDeviceExists(PaginatedSyncDataDto dto) async {
    try {
      // Extract client device information from the DTO
      final clientSyncDevice = dto.syncDevice;
      final clientDeviceId = clientSyncDevice.fromDeviceId;
      final serverDeviceId = await _deviceIdService.getDeviceId();

      // Check if we already have a SyncDevice record for this client
      final existingDeviceQuery = GetSyncDeviceQuery(
        fromDeviceId: serverDeviceId,
        toDeviceId: clientDeviceId
      );

      final existingDevice = await _mediator.send<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?>(existingDeviceQuery);

      if (existingDevice?.id.isNotEmpty == true) {
        Logger.debug('🔗 SyncDevice record already exists for client $clientDeviceId');
        return;
      }

      // Create SyncDevice record for bidirectional sync
      final serverLocalIp = await NetworkUtils.getLocalIpAddress();
      final clientRemoteIp = clientSyncDevice.fromIp; // Use client's IP from DTO
      final serverDeviceName = await DeviceInfoHelper.getDeviceName();

      if (serverLocalIp == null) {
        Logger.warning('⚠️ Could not determine server local IP for SyncDevice creation');
        return;
      }

      Logger.info('🔗 Creating SyncDevice record for new client: ${clientSyncDevice.name} ($clientDeviceId)');

      final saveCommand = SaveSyncDeviceCommand(
        fromIP: serverLocalIp, // Server IP (this device)
        toIP: clientRemoteIp, // Client IP (connecting device)
        fromDeviceId: serverDeviceId, // Server device ID
        toDeviceId: clientDeviceId, // Client device ID
        name: "$serverDeviceName ↔ ${clientSyncDevice.name}",
      );

      await _mediator.send<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse>(saveCommand);
      Logger.info('✅ SyncDevice record created successfully for client $clientDeviceId');

    } catch (e) {
      Logger.error('❌ Failed to ensure SyncDevice exists: $e');
      // Don't throw - sync should continue even if device pairing fails
    }
  }
}
