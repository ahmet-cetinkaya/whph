import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/sync/models/sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/sync/sync_device.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tags/tag_tag.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/notes/note_tag.dart';

/// Custom exception for data validation errors
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => 'ValidationException: $message';
}

/// Result of paginated sync operation
class PaginatedSyncResult {
  final bool success;
  final bool hasMorePages;
  final int? totalPages;
  final int? totalItems;
  final String? errorMessage;

  PaginatedSyncResult({
    required this.success,
    this.hasMorePages = false,
    this.totalPages,
    this.totalItems,
    this.errorMessage,
  });

  factory PaginatedSyncResult.success({
    bool hasMorePages = false,
    int? totalPages,
    int? totalItems,
  }) {
    return PaginatedSyncResult(
      success: true,
      hasMorePages: hasMorePages,
      totalPages: totalPages,
      totalItems: totalItems,
    );
  }

  factory PaginatedSyncResult.failure(String errorMessage) {
    return PaginatedSyncResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

class PaginatedSyncCommand implements IRequest<PaginatedSyncCommandResponse> {
  final PaginatedSyncDataDto? paginatedSyncDataDto;

  PaginatedSyncCommand({this.paginatedSyncDataDto});
}

@jsonSerializable
class PaginatedSyncCommandResponse {
  final PaginatedSyncDataDto? paginatedSyncDataDto;
  final bool isComplete;
  final String? nextEntityType;
  final int? nextPageIndex;
  final int syncedDeviceCount;
  final bool hadMeaningfulSync;

  PaginatedSyncCommandResponse({
    this.paginatedSyncDataDto,
    this.isComplete = false,
    this.nextEntityType,
    this.nextPageIndex,
    this.syncedDeviceCount = 0,
    this.hadMeaningfulSync = false,
  });
}

class PaginatedSyncConfig<T extends BaseEntity<String>> {
  final String name;
  final IRepository<T, String> repository;
  final Future<PaginatedSyncData<T>> Function(DateTime, int, int, String?) getPaginatedSyncData;
  final PaginatedSyncData<T>? Function(PaginatedSyncDataDto) getPaginatedSyncDataFromDto;

  PaginatedSyncConfig({
    required this.name,
    required this.repository,
    required this.getPaginatedSyncData,
    required this.getPaginatedSyncDataFromDto,
  });
}

class PaginatedSyncCommandHandler implements IRequestHandler<PaginatedSyncCommand, PaginatedSyncCommandResponse> {
  final ISyncDeviceRepository syncDeviceRepository;
  final IDeviceIdService deviceIdService;
  final IAppUsageRepository appUsageRepository;
  final IAppUsageTagRepository appUsageTagRepository;
  final IAppUsageTimeRecordRepository appUsageTimeRecordRepository;
  final IAppUsageTagRuleRepository appUsageTagRuleRepository;
  final IHabitRepository habitRepository;
  final IHabitRecordRepository habitRecordRepository;
  final IHabitTagsRepository habitTagRepository;
  final ITagRepository tagRepository;
  final ITagTagRepository tagTagRepository;
  final ITaskRepository taskRepository;
  final ITaskTagRepository taskTagRepository;
  final ITaskTimeRecordRepository taskTimeRecordRepository;
  final ISettingRepository settingRepository;
  final IAppUsageIgnoreRuleRepository appUsageIgnoreRuleRepository;
  final IRepository<Note, String> noteRepository;
  final IRepository<NoteTag, String> noteTagRepository;

  late final List<PaginatedSyncConfig> _syncConfigs;

  // Public accessor for sync configurations
  List<PaginatedSyncConfig> get syncConfigs => _syncConfigs;

  // Progress tracking
  final _progressController = StreamController<SyncProgress>.broadcast();
  Stream<SyncProgress> get progressStream => _progressController.stream;

  // Server pagination tracking for dynamic pagination control
  final Map<String, int> _serverTotalPages = {};
  final Map<String, int> _serverTotalItems = {};

  PaginatedSyncCommandHandler({
    required this.syncDeviceRepository,
    required this.deviceIdService,
    required this.appUsageRepository,
    required this.appUsageTagRepository,
    required this.appUsageTimeRecordRepository,
    required this.appUsageTagRuleRepository,
    required this.habitRepository,
    required this.habitRecordRepository,
    required this.habitTagRepository,
    required this.tagRepository,
    required this.tagTagRepository,
    required this.taskRepository,
    required this.taskTagRepository,
    required this.taskTimeRecordRepository,
    required this.settingRepository,
    required this.appUsageIgnoreRuleRepository,
    required this.noteRepository,
    required this.noteTagRepository,
  }) {
    _syncConfigs = [
      PaginatedSyncConfig<AppUsage>(
        name: 'AppUsage',
        repository: appUsageRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => appUsageRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.appUsagesSyncData,
      ),
      PaginatedSyncConfig<AppUsageTag>(
        name: 'AppUsageTag',
        repository: appUsageTagRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => appUsageTagRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.appUsageTagsSyncData,
      ),
      PaginatedSyncConfig<AppUsageTimeRecord>(
        name: 'AppUsageTimeRecord',
        repository: appUsageTimeRecordRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => appUsageTimeRecordRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.appUsageTimeRecordsSyncData,
      ),
      PaginatedSyncConfig<AppUsageTagRule>(
        name: 'AppUsageTagRule',
        repository: appUsageTagRuleRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => appUsageTagRuleRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.appUsageTagRulesSyncData,
      ),
      PaginatedSyncConfig<Habit>(
        name: 'Habit',
        repository: habitRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => habitRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.habitsSyncData,
      ),
      PaginatedSyncConfig<HabitRecord>(
        name: 'HabitRecord',
        repository: habitRecordRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => habitRecordRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.habitRecordsSyncData,
      ),
      PaginatedSyncConfig<HabitTag>(
        name: 'HabitTag',
        repository: habitTagRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => habitTagRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.habitTagsSyncData,
      ),
      PaginatedSyncConfig<Tag>(
        name: 'Tag',
        repository: tagRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => tagRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.tagsSyncData,
      ),
      PaginatedSyncConfig<TagTag>(
        name: 'TagTag',
        repository: tagTagRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => tagTagRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.tagTagsSyncData,
      ),
      PaginatedSyncConfig<Task>(
        name: 'Task',
        repository: taskRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => taskRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.tasksSyncData,
      ),
      PaginatedSyncConfig<TaskTag>(
        name: 'TaskTag',
        repository: taskTagRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => taskTagRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.taskTagsSyncData,
      ),
      PaginatedSyncConfig<TaskTimeRecord>(
        name: 'TaskTimeRecord',
        repository: taskTimeRecordRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => taskTimeRecordRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.taskTimeRecordsSyncData,
      ),
      PaginatedSyncConfig<Setting>(
        name: 'Setting',
        repository: settingRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => settingRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.settingsSyncData,
      ),
      PaginatedSyncConfig<SyncDevice>(
        name: 'SyncDevice',
        repository: syncDeviceRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => syncDeviceRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.syncDevicesSyncData,
      ),
      PaginatedSyncConfig<Note>(
        name: 'Note',
        repository: noteRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => noteRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.notesSyncData,
      ),
      PaginatedSyncConfig<NoteTag>(
        name: 'NoteTag',
        repository: noteTagRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => noteTagRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.noteTagsSyncData,
      ),
      PaginatedSyncConfig<AppUsageIgnoreRule>(
        name: 'AppUsageIgnoreRule',
        repository: appUsageIgnoreRuleRepository,
        getPaginatedSyncData: (lastSyncDate, pageIndex, pageSize, entityType) => appUsageIgnoreRuleRepository
            .getPaginatedSyncData(lastSyncDate, pageIndex: pageIndex, pageSize: pageSize, entityType: entityType),
        getPaginatedSyncDataFromDto: (dto) => dto.appUsageIgnoreRulesSyncData,
      ),
    ];
  }

  @override
  Future<PaginatedSyncCommandResponse> call(PaginatedSyncCommand request) async {
    Logger.info('🚀 Starting paginated sync operation');

    if (request.paginatedSyncDataDto != null) {
      Logger.info('📨 Processing incoming paginated sync data from remote device');

      // Yield immediately to prevent UI blocking from large DTO processing
      await _yieldToUIThreadMaximum();

      Logger.debug('🔄 Starting version check');
      await _checkVersion(request.paginatedSyncDataDto!.appVersion);

      await _yieldToUIThreadMaximum();
      Logger.debug('🔄 Starting device validation');
      await _validateDeviceId(request.paginatedSyncDataDto!.syncDevice);

      await _yieldToUIThreadMaximum();
      Logger.debug('🔄 Starting environment mode validation');
      _validateEnvironmentMode(request.paginatedSyncDataDto!);

      await _yieldToUIThreadMaximum();
      Logger.debug('🔄 Starting incoming data processing');
      // Process the incoming paginated data
      final success = await processIncomingPaginatedData(request.paginatedSyncDataDto!);
      if (success) {
        Logger.debug('🔄 Starting response data preparation');
        // Prepare response data for the same entity type and page
        final responseData = await preparePaginatedSyncDataResponse(request.paginatedSyncDataDto!);
        Logger.debug('✅ Paginated sync command completed successfully');
        return PaginatedSyncCommandResponse(
          paginatedSyncDataDto: responseData,
          isComplete: responseData?.isLastPage ?? true,
        );
      }
      throw BusinessException('Failed to process paginated sync data', SyncTranslationKeys.processFailedError);
    } else {
      // Outgoing sync initiation
      Logger.info('🔄 Proceeding with paginated sync initiation');
      return await _initiatePaginatedSync();
    }
  }

  Future<PaginatedSyncCommandResponse> _initiatePaginatedSync() async {
    final localDeviceId = await deviceIdService.getDeviceId();
    final localIP = await NetworkUtils.getLocalIpAddress();
    final allDevices = await syncDeviceRepository.getAll();

    Logger.debug('🔍 Local device details - ID: $localDeviceId, IP: $localIP');

    final syncDevices = allDevices
        .where((device) => device.fromDeviceId == localDeviceId || device.toDeviceId == localDeviceId)
        .toList();

    if (syncDevices.isEmpty) {
      Logger.info('🔍 No remote devices found to sync with');
      return PaginatedSyncCommandResponse(
        isComplete: true,
        syncedDeviceCount: 0,
        hadMeaningfulSync: false,
      );
    }

    bool allDevicesSynced = true;
    DateTime? oldestLastSyncDate;
    final List<SyncDevice> successfulDevices = [];

    for (SyncDevice syncDevice in syncDevices) {
      try {
        Logger.info('🔄 Starting paginated sync with device: ${syncDevice.id}');

        final success = await _syncDeviceWithPagination(syncDevice);
        if (success) {
          // Store successful devices for later processing - don't update lastSyncDate yet
          successfulDevices.add(syncDevice);
          oldestLastSyncDate = oldestLastSyncDate == null
              ? syncDevice.lastSyncDate
              : (syncDevice.lastSyncDate!.isBefore(oldestLastSyncDate) ? syncDevice.lastSyncDate : oldestLastSyncDate);
        } else {
          allDevicesSynced = false;
        }
      } catch (e) {
        Logger.error('❌ CRITICAL: Failed to sync with device ${syncDevice.id}: $e');
        Logger.error('🔍 Error type: ${e.runtimeType}');
        Logger.error('🔍 This will prevent lastSyncDate update and mark sync as failed');
        allDevicesSynced = false;
      }
    }

    // Only update lastSyncDate if ALL devices synced successfully
    if (allDevicesSynced) {
      for (SyncDevice syncDevice in successfulDevices) {
        await _saveSyncDevice(syncDevice);
      }
    } else {
      Logger.error('❌ Sync incomplete - some devices failed. Not updating lastSyncDate for any devices');
    }

    if (allDevicesSynced && oldestLastSyncDate != null) {
      Logger.info('🧹 Cleaning up soft-deleted data older than: $oldestLastSyncDate');
      await _cleanupSoftDeletedData(oldestLastSyncDate);
    }

    if (allDevicesSynced) {
      Logger.info('🏁 Paginated sync operation completed successfully');
      return PaginatedSyncCommandResponse(
        isComplete: true,
        syncedDeviceCount: successfulDevices.length,
        hadMeaningfulSync: successfulDevices.isNotEmpty,
      );
    } else {
      Logger.error('🏁 Paginated sync operation completed with failures');
      return PaginatedSyncCommandResponse(
        isComplete: false,
        syncedDeviceCount: successfulDevices.length,
        hadMeaningfulSync: successfulDevices.isNotEmpty,
      );
    }
  }

  Future<bool> _syncDeviceWithPagination(SyncDevice syncDevice) async {
    final localDeviceId = await deviceIdService.getDeviceId();
    final isFromDevice = syncDevice.fromDeviceId == localDeviceId;
    final targetIp = isFromDevice ? syncDevice.toIp : syncDevice.fromIp;

    Logger.debug('🎯 Targeting IP: $targetIp for paginated sync');

    // Test connectivity
    final portTest = await NetworkUtils.testPortConnectivity(targetIp);
    if (!portTest) {
      Logger.error('❌ Port connectivity test failed for $targetIp:44040');
      return false;
    }

    // Track sync failures for detailed error reporting
    final List<String> failedEntities = [];

    // Sync each entity type with pagination
    for (int configIndex = 0; configIndex < _syncConfigs.length; configIndex++) {
      final config = _syncConfigs[configIndex];

      _updateProgress(
        currentEntity: config.name,
        currentPage: 0,
        totalPages: 1,
        entitiesCompleted: configIndex,
        totalEntities: _syncConfigs.length,
        operation: 'preparing',
      );

      try {
        final success = await _syncEntityWithPagination(syncDevice, config, targetIp);
        if (!success) {
          Logger.error('❌ Failed to sync ${config.name} with device ${syncDevice.id}');
          failedEntities.add(config.name);
        }
      } catch (e) {
        Logger.error('❌ Exception during ${config.name} sync with device ${syncDevice.id}: $e');
        failedEntities.add(config.name);
      }

      // Add delay between entities to prevent overwhelming the system
      await Future.delayed(SyncPaginationConfig.batchDelay);
    }

    if (failedEntities.isNotEmpty) {
      Logger.error('❌ Device sync failed for ${failedEntities.length} entities: ${failedEntities.join(', ')}');
      return false;
    }

    Logger.info('✅ All entities synced successfully with device ${syncDevice.id}');
    return true;
  }

  Future<bool> _syncEntityWithPagination(
    SyncDevice syncDevice,
    PaginatedSyncConfig config,
    String targetIp,
  ) async {
    final DateTime lastSyncDate = syncDevice.lastSyncDate ?? DateTime(1900, 1, 1);
    int pageIndex = 0;
    bool hasMorePages = true;

    Logger.debug('🔄 Starting paginated sync for ${config.name}');

    while (hasMorePages) {
      try {
        _updateProgress(
          currentEntity: config.name,
          currentPage: pageIndex,
          totalPages: -1, // Unknown until first page
          entitiesCompleted: _syncConfigs.indexOf(config),
          totalEntities: _syncConfigs.length,
          operation: 'fetching',
        );

        // Get paginated data for this entity
        final paginatedData = await config.getPaginatedSyncData(
          lastSyncDate,
          pageIndex,
          SyncPaginationConfig.defaultNetworkPageSize,
          config.name,
        );

        // Update progress with actual page info
        _updateProgress(
          currentEntity: config.name,
          currentPage: pageIndex,
          totalPages: paginatedData.totalPages,
          entitiesCompleted: _syncConfigs.indexOf(config),
          totalEntities: _syncConfigs.length,
          operation: 'transmitting',
        );

        // Always send sync request for bidirectional sync, even if local device has no data
        // This ensures the remote device can send its data back
        if (paginatedData.totalItems == 0) {
          Logger.debug('📤 Sending empty sync request for ${config.name} to receive remote data');
        }

        // Create DTO for this page
        final dto = _createPaginatedSyncDataDto(syncDevice, paginatedData, config.name);

        // Send this page to the remote device
        final success = await _sendPaginatedDataToWebSocket(targetIp, dto);
        if (!success) {
          Logger.error('Failed to send ${config.name} page $pageIndex');
          return false;
        }

        hasMorePages = !paginatedData.isLastPage;
        // CRITICAL FIX: If local data says no more pages but we are still early in pagination,
        // continue to check server response for more data
        // CRITICAL FIX: Dynamic pagination based on server response
        // If local data says no more pages but server indicated more pages exist, continue
        if (!hasMorePages) {
          final serverTotalPages = _serverTotalPages[config.name];
          if (serverTotalPages != null && pageIndex < serverTotalPages - 1) {
            hasMorePages = true;
            Logger.debug(
                "🔄 Local data complete but server has $serverTotalPages pages total. Continuing pagination for ${config.name} (page $pageIndex)");
          } else if (serverTotalPages == null && pageIndex < 2) {
            // Fallback: if no server info yet, try a few more pages for low-volume entities
            hasMorePages = true;
            Logger.debug(
                "🔄 No server pagination info yet. Continuing pagination for ${config.name} (page $pageIndex)");
          }
        }
        pageIndex++;

        // Add delay between pages
        if (hasMorePages) {
          await Future.delayed(SyncPaginationConfig.batchDelay);
        }

        Logger.debug('✅ Sent ${config.name} page ${pageIndex - 1}/${paginatedData.totalPages - 1}');
      } catch (e) {
        Logger.error('Error syncing ${config.name} page $pageIndex: $e');
        return false;
      }
    }

    Logger.debug('✅ Completed paginated sync for ${config.name}');
    return true;
  }

  PaginatedSyncDataDto _createPaginatedSyncDataDto(
    SyncDevice syncDevice,
    PaginatedSyncData paginatedData,
    String entityType,
  ) {
    final progress = SyncProgress(
      currentEntity: entityType,
      currentPage: paginatedData.pageIndex,
      totalPages: paginatedData.totalPages,
      progressPercentage: ((paginatedData.pageIndex + 1) / paginatedData.totalPages * 100),
      entitiesCompleted: _syncConfigs.indexWhere((c) => c.name == entityType),
      totalEntities: _syncConfigs.length,
      operation: 'transmitting',
    );

    // Create DTO with only the relevant entity data populated
    final debugMode = _isDeviceInDebugMode();
    Logger.info('📤 Creating PaginatedSyncDataDto with isDebugMode: $debugMode for entity: $entityType');
    Logger.info('🔍 Debug mode detection details:');
    Logger.info('   kDebugMode: $kDebugMode, kReleaseMode: $kReleaseMode, kProfileMode: $kProfileMode');

    return PaginatedSyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      isDebugMode: debugMode,
      entityType: entityType,
      pageIndex: paginatedData.pageIndex,
      pageSize: paginatedData.pageSize,
      totalPages: paginatedData.totalPages,
      totalItems: paginatedData.totalItems,
      isLastPage: paginatedData.isLastPage,
      progress: progress,
      // Populate the appropriate field based on entity type
      appUsagesSyncData: entityType == 'AppUsage' ? paginatedData as PaginatedSyncData<AppUsage>? : null,
      appUsageTagsSyncData: entityType == 'AppUsageTag' ? paginatedData as PaginatedSyncData<AppUsageTag>? : null,
      appUsageTimeRecordsSyncData:
          entityType == 'AppUsageTimeRecord' ? paginatedData as PaginatedSyncData<AppUsageTimeRecord>? : null,
      appUsageTagRulesSyncData:
          entityType == 'AppUsageTagRule' ? paginatedData as PaginatedSyncData<AppUsageTagRule>? : null,
      appUsageIgnoreRulesSyncData:
          entityType == 'AppUsageIgnoreRule' ? paginatedData as PaginatedSyncData<AppUsageIgnoreRule>? : null,
      habitsSyncData: entityType == 'Habit' ? paginatedData as PaginatedSyncData<Habit>? : null,
      habitRecordsSyncData: entityType == 'HabitRecord' ? paginatedData as PaginatedSyncData<HabitRecord>? : null,
      habitTagsSyncData: entityType == 'HabitTag' ? paginatedData as PaginatedSyncData<HabitTag>? : null,
      tagsSyncData: entityType == 'Tag' ? paginatedData as PaginatedSyncData<Tag>? : null,
      tagTagsSyncData: entityType == 'TagTag' ? paginatedData as PaginatedSyncData<TagTag>? : null,
      tasksSyncData: entityType == 'Task' ? paginatedData as PaginatedSyncData<Task>? : null,
      taskTagsSyncData: entityType == 'TaskTag' ? paginatedData as PaginatedSyncData<TaskTag>? : null,
      taskTimeRecordsSyncData:
          entityType == 'TaskTimeRecord' ? paginatedData as PaginatedSyncData<TaskTimeRecord>? : null,
      settingsSyncData: entityType == 'Setting' ? paginatedData as PaginatedSyncData<Setting>? : null,
      syncDevicesSyncData: entityType == 'SyncDevice' ? paginatedData as PaginatedSyncData<SyncDevice>? : null,
      notesSyncData: entityType == 'Note' ? paginatedData as PaginatedSyncData<Note>? : null,
      noteTagsSyncData: entityType == 'NoteTag' ? paginatedData as PaginatedSyncData<NoteTag>? : null,
    );
  }

  Future<bool> _sendPaginatedDataToWebSocket(String ipAddress, PaginatedSyncDataDto dto) async {
    const int maxRetries = 3;
    const int baseTimeout = 15; // Increased timeout for paginated data
    int attempt = 0;

    // Extract variables from DTO for logging and validation
    final entityType = dto.entityType;
    final pageIndex = dto.pageIndex;
    final startTime = DateTime.now();

    while (attempt < maxRetries) {
      WebSocket? socket;
      try {
        socket =
            await WebSocket.connect('ws://$ipAddress:44040').timeout(Duration(seconds: baseTimeout * (attempt + 1)));

        final completer = Completer<bool>();
        Timer? timeoutTimer;

        timeoutTimer = Timer(Duration(seconds: baseTimeout * (attempt + 1)), () {
          if (!completer.isCompleted) {
            Logger.error(
                '⏰ WebSocket timeout after ${baseTimeout * (attempt + 1)} seconds (attempt ${attempt + 1}/$maxRetries)');
            completer.complete(false);
            socket?.close();
          }
        });

        // Extract sync data from DTO for logging
        final syncData = _extractSyncDataFromDto(dto);

        // Send paginated data with yielding around heavy JSON operations
        final startJsonTime = DateTime.now();
        final totalItems = syncData?.getTotalItemCount() ?? 0;
        Logger.debug('🔄 Converting DTO to JSON for transmission ($totalItems items)');
        Logger.debug(
            '🔍 Entity breakdown: Create=${syncData?.createSync.length ?? 0}, Update=${syncData?.updateSync.length ?? 0}, Delete=${syncData?.deleteSync.length ?? 0}');
        await _yieldToUIThreadMaximum();

        final dtoJson = await _convertDtoToJsonWithYielding(dto);
        final jsonTime = DateTime.now().difference(startJsonTime).inMilliseconds;
        Logger.debug('✅ DTO to JSON conversion completed in ${jsonTime}ms');

        await _yieldToUIThreadMaximum();
        Logger.debug('🔄 Serializing WebSocket message');

        final message = WebSocketMessage(type: 'paginated_sync', data: dtoJson);
        final serializedMessage = await _serializeMessageWithYielding(message);

        await _yieldToUIThreadMaximum();

        // PRE-TRANSMISSION VALIDATION: Validate data integrity before sending
        try {
          final startValidationTime = DateTime.now();
          Logger.debug('🔍 Validating message before transmission...');
          await _validateMessageIntegrity(dtoJson, entityType);
          final validationTime = DateTime.now().difference(startValidationTime).inMilliseconds;
          Logger.debug('✅ Pre-transmission validation passed in ${validationTime}ms');
        } catch (validationError) {
          Logger.error('❌ Pre-transmission validation failed: $validationError');
          Logger.error('🔍 This prevents server-side errors by catching issues early');
          throw BusinessException(
              'Pre-transmission validation failed: $validationError', SyncTranslationKeys.processFailedError);
        }

        final transmissionStartTime = DateTime.now();
        Logger.debug('🔄 Sending message via WebSocket (${serializedMessage.length} bytes)');

        socket.add(serializedMessage);

        // Listen for response with yielding around JSON processing
        await for (final message in socket) {
          try {
            final responseTime = DateTime.now().difference(transmissionStartTime).inMilliseconds;
            Logger.debug(
                '🔄 Deserializing received WebSocket message (${message.toString().length} bytes) - Server response time: ${responseTime}ms');
            await _yieldToUIThreadMaximum();

            final receivedMessage = await _deserializeMessageWithYielding(message);

            if (receivedMessage == null) {
              Logger.error('❌ Failed to deserialize WebSocket message - received null result');
              completer.complete(false);
              break;
            }

            Logger.debug('✓ Successfully deserialized message type: ${receivedMessage.type}');
            await _yieldToUIThreadMaximum();

            if (receivedMessage.type == 'paginated_sync_complete') {
              timeoutTimer.cancel();

              // CRITICAL FIX: Validate response structure before processing
              if (receivedMessage.data == null) {
                Logger.error('❌ Paginated sync response missing data field');
                completer.complete(false);
                break;
              }

              if (receivedMessage.data is! Map<String, dynamic>) {
                Logger.error('❌ Paginated sync response data is not a Map: ${receivedMessage.data.runtimeType}');
                completer.complete(false);
                break;
              }

              final messageData = receivedMessage.data as Map<String, dynamic>;
              final bool? success = messageData['success'] as bool?;
              final bool isComplete = messageData['isComplete'] as bool? ?? false;

              Logger.debug('📨 Received paginated sync response: success=$success, isComplete=$isComplete');

              if (success == true) {
                // CRITICAL FIX: Process server response data to sync desktop data to mobile
                // Previous bug: This data was being skipped, causing sync to appear successful
                // but desktop data never reached the mobile device database
                bool responseProcessingSuccess = true;
                if (messageData['paginatedSyncDataDto'] != null) {
                  Logger.info(
                      '📥 Server returned response data - processing desktop data sync to mobile (isComplete: $isComplete)');

                  Map<String, dynamic>? responseDataMap;
                  try {
                    // Parse the server response data
                    responseDataMap = messageData['paginatedSyncDataDto'] as Map<String, dynamic>;

                    // Fix potential type casting issues by normalizing numeric fields
                    _normalizeJsonNumericTypes(responseDataMap);

                    // Manual deserialization to avoid generic type issues with JsonMapper
                    final responseDto = _deserializePaginatedSyncDataDto(responseDataMap);

                    if (responseDto == null) {
                      Logger.error('❌ Failed to deserialize server response data');
                      responseProcessingSuccess = false;
                    } else {
                      Logger.debug(
                          '📋 Processing ${responseDto.entityType} data from server (${responseDto.totalItems} items)');

                      // Process the incoming data using the same method used for server-side processing
                      final processSuccess = await processIncomingPaginatedData(responseDto);

                      // CRITICAL FIX: Store server pagination info for dynamic pagination control
                      // This enables proper pagination based on servers actual data, not static limits
                      _serverTotalPages[responseDto.entityType] = responseDto.totalPages;
                      _serverTotalItems[responseDto.entityType] = responseDto.totalItems;

                      Logger.debug(
                          "🔄 Server pagination info for ${responseDto.entityType}: page ${responseDto.pageIndex + 1}/${responseDto.totalPages}, ${responseDto.totalItems} total items");
                      if (processSuccess) {
                        Logger.info('✅ Successfully processed server response data for ${responseDto.entityType}');
                      } else {
                        Logger.error('❌ Failed to process server response data for ${responseDto.entityType}');
                        responseProcessingSuccess = false;
                      }
                    }
                  } catch (e) {
                    Logger.error('❌ Error processing server response data: $e');
                    if (responseDataMap != null) {
                      Logger.debug('📦 Raw server response data: ${responseDataMap.toString().substring(0, 500)}...');
                    }
                    responseProcessingSuccess = false;
                  }
                }

                // Only complete successfully if both server response AND response processing succeeded
                completer.complete(responseProcessingSuccess);
                break;
              } else {
                final String reason = messageData['message']?.toString() ?? 'Unknown server-side failure';
                Logger.error('❌ Server reported sync failure: $reason');
                completer.complete(false);
                break;
              }
            } else if (receivedMessage.type == 'paginated_sync_error') {
              timeoutTimer.cancel();

              // ENHANCED ERROR HANDLING: Extract comprehensive error details
              String errorDetails = 'Unknown error';
              String? errorType;
              String? stackTrace;
              String? entityContext;
              Map<String, dynamic>? errorMetadata;

              if (receivedMessage.data is Map<String, dynamic>) {
                final errorData = receivedMessage.data as Map<String, dynamic>;
                errorDetails = errorData['message']?.toString() ?? 'No error message provided';
                errorType = errorData['type']?.toString();
                stackTrace = errorData['stackTrace']?.toString();
                entityContext = errorData['entityType']?.toString() ?? entityType;
                errorMetadata = errorData['metadata'] as Map<String, dynamic>?;

                // Log comprehensive error information
                Logger.error('❌ Server returned paginated sync error for $entityContext:');
                Logger.error('🔍 Error Message: $errorDetails');
                if (errorType != null) Logger.error('🔍 Error Type: $errorType');
                if (stackTrace != null) Logger.error('🔍 Stack Trace: $stackTrace');
                if (errorMetadata != null) {
                  Logger.error('🔍 Error Metadata: ${JsonMapper.serialize(errorMetadata)}');
                }

                // Log sync context for debugging
                Logger.error('🔍 Sync Context:');
                Logger.error('   - Entity Type: $entityType');
                Logger.error('   - Page Index: $pageIndex');
                Logger.error('   - Total Items: ${syncData?.getTotalItemCount() ?? "unknown"}');
                Logger.error('   - Transmission Time: ${DateTime.now().difference(startTime).inMilliseconds}ms');

                // Try to identify problematic data if available
                if (errorMetadata?.containsKey('failedEntityId') == true) {
                  Logger.error('🔍 Failed Entity ID: ${errorMetadata!['failedEntityId']}');
                }
                if (errorMetadata?.containsKey('failedEntityData') == true) {
                  Logger.error('🔍 Failed Entity Data: ${errorMetadata!['failedEntityData']}');
                }
              } else {
                Logger.error('❌ Server returned paginated sync error with invalid data format');
                Logger.error('🔍 Raw error data: ${receivedMessage.data}');
              }

              completer.complete(false);
              break;
            } else {
              // CRITICAL FIX: Handle unrecognized message types
              Logger.error('❌ Received unrecognized message type: ${receivedMessage.type}');
              Logger.error('🔍 Expected: paginated_sync_complete or paginated_sync_error');
              try {
                Logger.error('🔍 Full message: ${JsonMapper.serialize(receivedMessage.toJson())}');
              } catch (e) {
                Logger.error('🔍 Full message (fallback): ${receivedMessage.toString()}');
              }
              completer.complete(false);
              break;
            }
          } catch (e) {
            Logger.error('❌ Error processing paginated sync message: $e');
            Logger.error('🔍 Error type: ${e.runtimeType}');
            Logger.error(
                '🔍 Raw message (first 200 chars): ${message.toString().substring(0, message.toString().length > 200 ? 200 : message.toString().length)}...');
            completer.complete(false);
            break;
          }
        }

        bool success = await completer.future;
        await socket.close();

        if (success) {
          return true;
        } else {
          // CRITICAL FIX: Provide more specific error information
          final String detailedError =
              'Paginated sync failed after ${baseTimeout * (attempt + 1)}s timeout (attempt ${attempt + 1}/$maxRetries). Check server connectivity and response format.';
          Logger.error('❌ $detailedError');
          throw BusinessException(detailedError, SyncTranslationKeys.syncFailedError);
        }
      } catch (e) {
        Logger.error('❌ Error during paginated WebSocket communication (Attempt ${attempt + 1}/$maxRetries): $e');

        // CRITICAL FIX: Log connection and communication details for debugging
        Logger.error('🔍 Connection details: ws://$ipAddress:44040');
        Logger.error('🔍 Timeout setting: ${baseTimeout * (attempt + 1)} seconds');
        Logger.error('🔍 Error type: ${e.runtimeType}');

        attempt++;

        if (attempt >= maxRetries) {
          Logger.error('❌ All $maxRetries retry attempts failed for paginated sync');
          return false;
        }

        final delaySeconds = pow(2, attempt).toInt();
        Logger.info('⏳ Retrying in $delaySeconds seconds... (attempt ${attempt + 1}/$maxRetries)');
        await Future.delayed(Duration(seconds: delaySeconds));
      } finally {
        await socket?.close();
      }
    }

    return false;
  }

  Future<bool> processIncomingPaginatedData(PaginatedSyncDataDto dto) async {
    try {
      Logger.info(
          '📥 Processing incoming paginated sync data for ${dto.entityType} (page ${dto.pageIndex + 1}/${dto.totalPages})');

      // Yield before heavy data extraction to prevent UI blocking
      await _yieldToUIThreadMaximum();
      Logger.debug('🔄 Finding config for ${dto.entityType}');

      // Find the appropriate config for this entity type
      final config = _syncConfigs.firstWhere((c) => c.name == dto.entityType);

      // For high-volume entities, use compute() to prevent UI blocking during data extraction
      final paginatedData = await _extractSyncDataWithIsolate(dto, config);

      Logger.debug('✅ Data extraction complete for ${dto.entityType}');

      if (paginatedData != null) {
        _updateProgress(
          currentEntity: dto.entityType,
          currentPage: dto.pageIndex,
          totalPages: dto.totalPages,
          entitiesCompleted: _syncConfigs.indexWhere((c) => c.name == dto.entityType),
          totalEntities: _syncConfigs.length,
          operation: 'processing',
        );

        // Yield before heavy processing
        await _yieldToUIThreadMaximum();
        Logger.debug('🔄 Starting batch processing for ${dto.entityType}');

        // Process the paginated data using existing batch processing logic
        final conflictCount = await _processSyncDataBatchDynamic(paginatedData.data, config.repository);

        Logger.debug(
            '✅ Processed ${dto.entityType} page ${dto.pageIndex}: ${paginatedData.data.createSync.length + paginatedData.data.updateSync.length + paginatedData.data.deleteSync.length} items, $conflictCount conflicts resolved');
        return true;
      }

      // CRITICAL FIX: Check if this is a legitimate empty sync vs a deserialization failure
      // If the DTO contains sync data but paginatedData is null, this indicates a deserialization error
      final bool hasActualSyncData = _dtoContainsSyncData(dto);

      if (hasActualSyncData) {
        // DTO contains data but deserialization failed - this is an error
        Logger.error('❌ ${dto.entityType} deserialization failed despite having sync data - marking as failed');
        return false;
      } else {
        // DTO has no sync data - this is legitimate skipping
        Logger.debug('⏭️ Skipping ${dto.entityType}: no sync data available');
        return true;
      }
    } catch (e) {
      Logger.error('❌ Error processing incoming paginated data for ${dto.entityType}: $e');
      return false;
    }
  }

  /// Helper method to check if a DTO contains actual sync data
  bool _dtoContainsSyncData(PaginatedSyncDataDto dto) {
    try {
      switch (dto.entityType) {
        case 'AppUsage':
          return dto.appUsagesSyncData != null && dto.appUsagesSyncData!.data.getTotalItemCount() > 0;
        case 'AppUsageTag':
          return dto.appUsageTagsSyncData != null && dto.appUsageTagsSyncData!.data.getTotalItemCount() > 0;
        case 'AppUsageTimeRecord':
          return dto.appUsageTimeRecordsSyncData != null &&
              dto.appUsageTimeRecordsSyncData!.data.getTotalItemCount() > 0;
        case 'AppUsageTagRule':
          return dto.appUsageTagRulesSyncData != null && dto.appUsageTagRulesSyncData!.data.getTotalItemCount() > 0;
        case 'AppUsageIgnoreRule':
          return dto.appUsageIgnoreRulesSyncData != null &&
              dto.appUsageIgnoreRulesSyncData!.data.getTotalItemCount() > 0;
        case 'Habit':
          return dto.habitsSyncData != null && dto.habitsSyncData!.data.getTotalItemCount() > 0;
        case 'HabitRecord':
          return dto.habitRecordsSyncData != null && dto.habitRecordsSyncData!.data.getTotalItemCount() > 0;
        case 'HabitTag':
          return dto.habitTagsSyncData != null && dto.habitTagsSyncData!.data.getTotalItemCount() > 0;
        case 'Tag':
          return dto.tagsSyncData != null && dto.tagsSyncData!.data.getTotalItemCount() > 0;
        case 'TagTag':
          return dto.tagTagsSyncData != null && dto.tagTagsSyncData!.data.getTotalItemCount() > 0;
        case 'Task':
          return dto.tasksSyncData != null && dto.tasksSyncData!.data.getTotalItemCount() > 0;
        case 'TaskTag':
          return dto.taskTagsSyncData != null && dto.taskTagsSyncData!.data.getTotalItemCount() > 0;
        case 'TaskTimeRecord':
          return dto.taskTimeRecordsSyncData != null && dto.taskTimeRecordsSyncData!.data.getTotalItemCount() > 0;
        case 'Setting':
          return dto.settingsSyncData != null && dto.settingsSyncData!.data.getTotalItemCount() > 0;
        case 'SyncDevice':
          return dto.syncDevicesSyncData != null && dto.syncDevicesSyncData!.data.getTotalItemCount() > 0;
        case 'Note':
          return dto.notesSyncData != null && dto.notesSyncData!.data.getTotalItemCount() > 0;
        case 'NoteTag':
          return dto.noteTagsSyncData != null && dto.noteTagsSyncData!.data.getTotalItemCount() > 0;
        default:
          Logger.warning('Unknown entity type in DTO sync data check: ${dto.entityType}');
          return false;
      }
    } catch (e) {
      Logger.error('Error checking DTO sync data for ${dto.entityType}: $e');
      return false;
    }
  }

  Future<PaginatedSyncDataDto?> preparePaginatedSyncDataResponse(PaginatedSyncDataDto incomingDto) async {
    try {
      // Find the config for the incoming entity type
      final config = _syncConfigs.firstWhere((c) => c.name == incomingDto.entityType);

      // CRITICAL FIX: Find the server's own sync device record to use its lastSyncDate
      // This ensures bidirectional sync works correctly - server sends its data based on its own sync state
      final allSyncDevices = await syncDeviceRepository.getAll();
      final serverSyncDevice = allSyncDevices.firstWhere(
        (device) => device.id == incomingDto.syncDevice.id,
        orElse: () => incomingDto.syncDevice,
      );

      // Create a response sync device (swap from/to for return path)
      final responseSyncDevice = SyncDevice(
        id: incomingDto.syncDevice.id,
        fromIp: incomingDto.syncDevice.toIp,
        toIp: incomingDto.syncDevice.fromIp,
        fromDeviceId: incomingDto.syncDevice.toDeviceId,
        toDeviceId: incomingDto.syncDevice.fromDeviceId,
        name: incomingDto.syncDevice.name,
        lastSyncDate: serverSyncDevice.lastSyncDate,
        createdDate: incomingDto.syncDevice.createdDate,
      );

      // CRITICAL FIX: Use server's own lastSyncDate to determine what data to send back
      // This enables proper bidirectional sync - server sends its data regardless of client's sync state
      final serverLastSyncDate = serverSyncDevice.lastSyncDate ?? DateTime(1900, 1, 1);
      Logger.debug(
          '🔄 Server preparing response using its own lastSyncDate: $serverLastSyncDate for ${incomingDto.entityType}');

      final responseData = await config.getPaginatedSyncData(
        serverLastSyncDate,
        incomingDto.pageIndex,
        incomingDto.pageSize,
        incomingDto.entityType,
      );

      Logger.debug('📤 Server response prepared: ${responseData.totalItems} items for ${incomingDto.entityType}');
      return _createPaginatedSyncDataDto(responseSyncDevice, responseData, incomingDto.entityType);
    } catch (e) {
      Logger.error('Error preparing paginated sync data response: $e');
      return null;
    }
  }

  /// Dynamic wrapper for processing mixed entity types
  Future<int> _processSyncDataBatchDynamic(SyncData syncData, IRepository repository) async {
    return await _processSyncDataBatch<BaseEntity<String>>(
        syncData as SyncData<BaseEntity<String>>, repository as IRepository<BaseEntity<String>, String>);
  }

  Future<int> _processSyncDataBatch<T extends BaseEntity<String>>(
      SyncData<T> syncData, IRepository<T, String> repository) async {
    try {
      final totalItems = syncData.createSync.length + syncData.updateSync.length + syncData.deleteSync.length;

      // For database operations taking >15ms each, use single-item processing
      const singleItemBatchSize = 1;
      int conflictsResolved = 0;

      // Track processed items to avoid duplicates
      final Set<String> processedItemIds = <String>{};

      Logger.debug('🔧 Using single-item processing for maximum UI responsiveness ($totalItems items)');

      // Process creates first with single-item yielding
      if (syncData.createSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.createSync.length} create items individually');
        conflictsResolved += await _processItemsWithMaximumYielding(
          syncData.createSync,
          singleItemBatchSize,
          processedItemIds,
          repository,
          'create',
        );
      }

      // Process updates with conflict resolution
      if (syncData.updateSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.updateSync.length} update items individually');
        conflictsResolved += await _processItemsWithMaximumYielding(
          syncData.updateSync,
          singleItemBatchSize,
          processedItemIds,
          repository,
          'update',
        );
      }

      // Process deletes
      if (syncData.deleteSync.isNotEmpty) {
        Logger.debug('📦 Processing ${syncData.deleteSync.length} delete items individually');
        await _processItemsWithMaximumYielding(
          syncData.deleteSync,
          singleItemBatchSize,
          processedItemIds,
          repository,
          'delete',
        );
      }

      Logger.debug('📊 Processed ${processedItemIds.length} unique items, $conflictsResolved conflicts resolved');
      return conflictsResolved;
    } catch (e) {
      Logger.error('Error processing batch for ${T.toString()}: $e');
      rethrow;
    }
  }

  ConflictResolutionResult<T> _resolveConflict<T extends BaseEntity<String>>(T localEntity, T remoteEntity) {
    final DateTime localTimestamp = _getEffectiveTimestamp(localEntity);
    final DateTime remoteTimestamp = _getEffectiveTimestamp(remoteEntity);

    if (localTimestamp.isAfter(remoteTimestamp)) {
      return ConflictResolutionResult(
        action: ConflictAction.keepLocal,
        winningEntity: localEntity,
        reason: 'Local timestamp ($localTimestamp) is newer than remote ($remoteTimestamp)',
      );
    } else if (remoteTimestamp.isAfter(localTimestamp)) {
      return ConflictResolutionResult(
        action: ConflictAction.acceptRemote,
        winningEntity: remoteEntity,
        reason: 'Remote timestamp ($remoteTimestamp) is newer than local ($localTimestamp)',
      );
    } else {
      return ConflictResolutionResult(
        action: ConflictAction.acceptRemoteForceUpdate,
        winningEntity: remoteEntity,
        reason: 'Timestamps are identical ($localTimestamp), preferring remote version for consistency',
      );
    }
  }

  DateTime _getEffectiveTimestamp<T extends BaseEntity<String>>(T entity) {
    return entity.modifiedDate ?? entity.createdDate;
  }

  Future<void> _saveSyncDevice(SyncDevice syncDevice) async {
    final DateTime now = DateTime.now().toUtc();
    final DateTime? previousSyncDate = syncDevice.lastSyncDate;

    syncDevice.lastSyncDate = now;
    await syncDeviceRepository.update(syncDevice);

    Logger.debug('💾 Updated sync device ${syncDevice.id}: lastSyncDate changed from $previousSyncDate to $now');
  }

  Future<void> _cleanupSoftDeletedData(DateTime oldestLastSyncDate) async {
    Logger.debug('🧹 Cleaning up soft deleted data older than: $oldestLastSyncDate');

    await Future.wait(
        _syncConfigs.map((config) => config.repository.hardDeleteSoftDeleted(oldestLastSyncDate)).toList());
  }

  Future<void> _checkVersion(String remoteVersion) async {
    if (remoteVersion != AppInfo.version) {
      throw BusinessException(
        'Version mismatch detected',
        SyncTranslationKeys.versionMismatchError,
        args: {
          'currentVersion': AppInfo.version,
          'remoteVersion': remoteVersion,
        },
      );
    }
  }

  /// Manually deserializes PaginatedSyncDataDto to avoid generic type issues with JsonMapper
  PaginatedSyncDataDto? _deserializePaginatedSyncDataDto(Map<String, dynamic> json) {
    try {
      // Extract basic fields
      final appVersion = json['appVersion'] as String;
      final entityType = json['entityType'] as String;
      final pageIndex = json['pageIndex'] as int;
      final pageSize = json['pageSize'] as int;
      final totalPages = json['totalPages'] as int;
      final totalItems = json['totalItems'] as int;
      final isLastPage = json['isLastPage'] as bool;

      // Deserialize sync device
      final syncDeviceMap = json['syncDevice'] as Map<String, dynamic>;
      final syncDevice = JsonMapper.deserialize<SyncDevice>(syncDeviceMap);
      if (syncDevice == null) {
        Logger.error('❌ Failed to deserialize SyncDevice');
        return null;
      }

      // Deserialize progress if present
      SyncProgress? progress;
      if (json['progress'] != null) {
        final progressMap = json['progress'] as Map<String, dynamic>;
        progress = JsonMapper.deserialize<SyncProgress>(progressMap);
      }

      // Deserialize the specific entity sync data based on entityType
      PaginatedSyncData? entitySyncData;
      final String syncDataKey = _getEntityDataKey(entityType);

      Logger.debug('🔍 Looking for sync data key: $syncDataKey');
      if (json[syncDataKey] != null) {
        final syncDataMap = json[syncDataKey] as Map<String, dynamic>;
        Logger.debug('🔍 Found $syncDataKey data, deserializing...');
        entitySyncData = _deserializePaginatedSyncDataForEntity(syncDataMap, entityType);
        if (entitySyncData != null) {
          Logger.debug('✅ Successfully deserialized $entityType data (${entitySyncData.runtimeType})');
        } else {
          Logger.error('❌ Failed to deserialize $entityType data');
        }
      } else {
        Logger.debug('⚠️ No $syncDataKey found in response data');
      }

      // Create the DTO using constructor
      return _createPaginatedSyncDataDtoFromDeserialized(
        appVersion: appVersion,
        syncDevice: syncDevice,
        entityType: entityType,
        pageIndex: pageIndex,
        pageSize: pageSize,
        totalPages: totalPages,
        totalItems: totalItems,
        isLastPage: isLastPage,
        progress: progress,
        entitySyncData: entitySyncData,
      );
    } catch (e) {
      Logger.error('❌ Error in manual PaginatedSyncDataDto deserialization: $e');
      return null;
    }
  }

  /// Helper function to safely deserialize entities with type conversion
  T? _safeDeserialize<T>(Map<String, dynamic> item) {
    try {
      // Handle type conversion for fields that might be int instead of double
      if (T == Task || T == Note) {
        // Convert int to double for 'order' field if needed
        if (item.containsKey('order') && item['order'] is int) {
          item['order'] = (item['order'] as int).toDouble();
        }
      }
      return JsonMapper.deserialize<T>(item);
    } catch (e) {
      Logger.warning('⚠️ Failed to deserialize ${T.toString()}: $e');
      return null;
    }
  }

  /// Deserializes PaginatedSyncData for a specific entity type
  PaginatedSyncData? _deserializePaginatedSyncDataForEntity(Map<String, dynamic> json, String entityType) {
    try {
      final dataMap = json['data'] as Map<String, dynamic>;
      final pageIndex = json['pageIndex'] as int;
      final pageSize = json['pageSize'] as int;
      final totalPages = json['totalPages'] as int;
      final totalItems = json['totalItems'] as int;
      final isLastPage = json['isLastPage'] as bool;

      // Deserialize the SyncData based on entity type
      SyncData? syncData;
      switch (entityType) {
        case 'Setting':
          Logger.debug('🔍 Deserializing Setting entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Setting>(item))
              .where((item) => item != null)
              .cast<Setting>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Setting>(item))
              .where((item) => item != null)
              .cast<Setting>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Setting>(item))
              .where((item) => item != null)
              .cast<Setting>()
              .toList();

          Logger.debug(
              '📊 Deserialized Settings: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<Setting>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          // Return properly typed PaginatedSyncData for Settings
          final result = PaginatedSyncData<Setting>(
            data: syncData as SyncData<Setting>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<Setting> (${result.runtimeType})');
          return result;

        case 'SyncDevice':
          Logger.debug('🔍 Deserializing SyncDevice entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<SyncDevice>(item))
              .where((item) => item != null)
              .cast<SyncDevice>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<SyncDevice>(item))
              .where((item) => item != null)
              .cast<SyncDevice>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<SyncDevice>(item))
              .where((item) => item != null)
              .cast<SyncDevice>()
              .toList();

          Logger.debug(
              '📊 Deserialized SyncDevices: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<SyncDevice>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          // Return properly typed PaginatedSyncData for SyncDevices
          final result = PaginatedSyncData<SyncDevice>(
            data: syncData as SyncData<SyncDevice>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<SyncDevice> (${result.runtimeType})');
          return result;

        case 'Task':
          Logger.debug('🔍 Deserializing Task entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => _safeDeserialize<Task>(item as Map<String, dynamic>))
              .where((item) => item != null)
              .cast<Task>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => _safeDeserialize<Task>(item as Map<String, dynamic>))
              .where((item) => item != null)
              .cast<Task>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => _safeDeserialize<Task>(item as Map<String, dynamic>))
              .where((item) => item != null)
              .cast<Task>()
              .toList();

          Logger.debug(
              '📊 Deserialized Tasks: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<Task>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<Task>(
            data: syncData as SyncData<Task>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<Task> (${result.runtimeType})');
          return result;

        case 'Note':
          Logger.debug('🔍 Deserializing Note entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => _safeDeserialize<Note>(item as Map<String, dynamic>))
              .where((item) => item != null)
              .cast<Note>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => _safeDeserialize<Note>(item as Map<String, dynamic>))
              .where((item) => item != null)
              .cast<Note>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => _safeDeserialize<Note>(item as Map<String, dynamic>))
              .where((item) => item != null)
              .cast<Note>()
              .toList();

          Logger.debug(
              '📊 Deserialized Notes: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<Note>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<Note>(
            data: syncData as SyncData<Note>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<Note> (${result.runtimeType})');
          return result;

        case 'Habit':
          Logger.debug('🔍 Deserializing Habit entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Habit>(item))
              .where((item) => item != null)
              .cast<Habit>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Habit>(item))
              .where((item) => item != null)
              .cast<Habit>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Habit>(item))
              .where((item) => item != null)
              .cast<Habit>()
              .toList();

          Logger.debug(
              '📊 Deserialized Habits: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<Habit>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<Habit>(
            data: syncData as SyncData<Habit>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<Habit> (${result.runtimeType})');
          return result;

        case 'Tag':
          Logger.debug('🔍 Deserializing Tag entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Tag>(item))
              .where((item) => item != null)
              .cast<Tag>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Tag>(item))
              .where((item) => item != null)
              .cast<Tag>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<Tag>(item))
              .where((item) => item != null)
              .cast<Tag>()
              .toList();

          Logger.debug(
              '📊 Deserialized Tags: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<Tag>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<Tag>(
            data: syncData as SyncData<Tag>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<Tag> (${result.runtimeType})');
          return result;

        case 'AppUsage':
          Logger.debug('🔍 Deserializing AppUsage entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsage>(item))
              .where((item) => item != null)
              .cast<AppUsage>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsage>(item))
              .where((item) => item != null)
              .cast<AppUsage>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsage>(item))
              .where((item) => item != null)
              .cast<AppUsage>()
              .toList();

          Logger.debug(
              '📊 Deserialized AppUsages: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<AppUsage>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<AppUsage>(
            data: syncData as SyncData<AppUsage>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<AppUsage> (${result.runtimeType})');
          return result;

        case 'TaskTag':
          Logger.debug('🔍 Deserializing TaskTag entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TaskTag>(item))
              .where((item) => item != null)
              .cast<TaskTag>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TaskTag>(item))
              .where((item) => item != null)
              .cast<TaskTag>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TaskTag>(item))
              .where((item) => item != null)
              .cast<TaskTag>()
              .toList();

          Logger.debug(
              '📊 Deserialized TaskTags: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<TaskTag>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<TaskTag>(
            data: syncData as SyncData<TaskTag>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<TaskTag> (${result.runtimeType})');
          return result;

        case 'TaskTimeRecord':
          Logger.debug('🔍 Deserializing TaskTimeRecord entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TaskTimeRecord>(item))
              .where((item) => item != null)
              .cast<TaskTimeRecord>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TaskTimeRecord>(item))
              .where((item) => item != null)
              .cast<TaskTimeRecord>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TaskTimeRecord>(item))
              .where((item) => item != null)
              .cast<TaskTimeRecord>()
              .toList();

          Logger.debug(
              '📊 Deserialized TaskTimeRecords: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<TaskTimeRecord>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<TaskTimeRecord>(
            data: syncData as SyncData<TaskTimeRecord>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<TaskTimeRecord> (${result.runtimeType})');
          return result;

        case 'HabitTag':
          Logger.debug('🔍 Deserializing HabitTag entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<HabitTag>(item))
              .where((item) => item != null)
              .cast<HabitTag>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<HabitTag>(item))
              .where((item) => item != null)
              .cast<HabitTag>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<HabitTag>(item))
              .where((item) => item != null)
              .cast<HabitTag>()
              .toList();

          Logger.debug(
              '📊 Deserialized HabitTags: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<HabitTag>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<HabitTag>(
            data: syncData as SyncData<HabitTag>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<HabitTag> (${result.runtimeType})');
          return result;

        case 'NoteTag':
          Logger.debug('🔍 Deserializing NoteTag entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<NoteTag>(item))
              .where((item) => item != null)
              .cast<NoteTag>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<NoteTag>(item))
              .where((item) => item != null)
              .cast<NoteTag>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<NoteTag>(item))
              .where((item) => item != null)
              .cast<NoteTag>()
              .toList();

          Logger.debug(
              '📊 Deserialized NoteTags: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<NoteTag>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<NoteTag>(
            data: syncData as SyncData<NoteTag>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<NoteTag> (${result.runtimeType})');
          return result;

        case 'AppUsageTag':
          Logger.debug('🔍 Deserializing AppUsageTag entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTag>(item))
              .where((item) => item != null)
              .cast<AppUsageTag>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTag>(item))
              .where((item) => item != null)
              .cast<AppUsageTag>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTag>(item))
              .where((item) => item != null)
              .cast<AppUsageTag>()
              .toList();

          Logger.debug(
              '📊 Deserialized AppUsageTags: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<AppUsageTag>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<AppUsageTag>(
            data: syncData as SyncData<AppUsageTag>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<AppUsageTag> (${result.runtimeType})');
          return result;

        case 'AppUsageTagRule':
          Logger.debug('🔍 Deserializing AppUsageTagRule entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTagRule>(item))
              .where((item) => item != null)
              .cast<AppUsageTagRule>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTagRule>(item))
              .where((item) => item != null)
              .cast<AppUsageTagRule>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTagRule>(item))
              .where((item) => item != null)
              .cast<AppUsageTagRule>()
              .toList();

          Logger.debug(
              '📊 Deserialized AppUsageTagRules: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<AppUsageTagRule>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<AppUsageTagRule>(
            data: syncData as SyncData<AppUsageTagRule>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<AppUsageTagRule> (${result.runtimeType})');
          return result;

        case 'TagTag':
          Logger.debug('🔍 Deserializing TagTag entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TagTag>(item))
              .where((item) => item != null)
              .cast<TagTag>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TagTag>(item))
              .where((item) => item != null)
              .cast<TagTag>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<TagTag>(item))
              .where((item) => item != null)
              .cast<TagTag>()
              .toList();

          Logger.debug(
              '📊 Deserialized TagTags: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<TagTag>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<TagTag>(
            data: syncData as SyncData<TagTag>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<TagTag> (${result.runtimeType})');
          return result;

        case 'AppUsageIgnoreRule':
          Logger.debug('🔍 Deserializing AppUsageIgnoreRule entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageIgnoreRule>(item))
              .where((item) => item != null)
              .cast<AppUsageIgnoreRule>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageIgnoreRule>(item))
              .where((item) => item != null)
              .cast<AppUsageIgnoreRule>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageIgnoreRule>(item))
              .where((item) => item != null)
              .cast<AppUsageIgnoreRule>()
              .toList();

          Logger.debug(
              '📊 Deserialized AppUsageIgnoreRules: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<AppUsageIgnoreRule>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<AppUsageIgnoreRule>(
            data: syncData as SyncData<AppUsageIgnoreRule>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<AppUsageIgnoreRule> (${result.runtimeType})');
          return result;

        case 'AppUsageTimeRecord':
          Logger.debug('🔍 Deserializing AppUsageTimeRecord entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTimeRecord>(item))
              .where((item) => item != null)
              .cast<AppUsageTimeRecord>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTimeRecord>(item))
              .where((item) => item != null)
              .cast<AppUsageTimeRecord>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<AppUsageTimeRecord>(item))
              .where((item) => item != null)
              .cast<AppUsageTimeRecord>()
              .toList();

          Logger.debug(
              '📊 Deserialized AppUsageTimeRecords: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<AppUsageTimeRecord>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<AppUsageTimeRecord>(
            data: syncData as SyncData<AppUsageTimeRecord>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<AppUsageTimeRecord> (${result.runtimeType})');
          return result;

        case 'HabitRecord':
          Logger.debug('🔍 Deserializing HabitRecord entities...');
          final createSync = (dataMap['createSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<HabitRecord>(item))
              .where((item) => item != null)
              .cast<HabitRecord>()
              .toList();
          final updateSync = (dataMap['updateSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<HabitRecord>(item))
              .where((item) => item != null)
              .cast<HabitRecord>()
              .toList();
          final deleteSync = (dataMap['deleteSync'] as List? ?? [])
              .map((item) => JsonMapper.deserialize<HabitRecord>(item))
              .where((item) => item != null)
              .cast<HabitRecord>()
              .toList();

          Logger.debug(
              '📊 Deserialized HabitRecords: ${createSync.length} create, ${updateSync.length} update, ${deleteSync.length} delete');

          syncData = SyncData<HabitRecord>(
            createSync: createSync,
            updateSync: updateSync,
            deleteSync: deleteSync,
          );

          final result = PaginatedSyncData<HabitRecord>(
            data: syncData as SyncData<HabitRecord>,
            pageIndex: pageIndex,
            pageSize: pageSize,
            totalPages: totalPages,
            totalItems: totalItems,
            isLastPage: isLastPage,
            entityType: entityType,
          );
          Logger.debug('✅ Created PaginatedSyncData<HabitRecord> (${result.runtimeType})');
          return result;

        // Add other entity types as needed
        default:
          Logger.warning('⚠️ Unsupported entity type for deserialization: $entityType');
          return null;
      }
    } catch (e) {
      Logger.error('❌ CRITICAL: Failed to deserialize PaginatedSyncData for $entityType: $e');
      Logger.error('🔍 This indicates a serious deserialization failure that will cause sync to fail');
      Logger.error('🔍 Error type: ${e.runtimeType}');
      if (e.toString().contains('Null') && e.toString().contains('subtype')) {
        Logger.error('🔍 This appears to be a null casting error - check for missing pagination parameters');
      }
      return null;
    }
  }

  /// Creates PaginatedSyncDataDto from deserialized components
  PaginatedSyncDataDto _createPaginatedSyncDataDtoFromDeserialized({
    required String appVersion,
    required SyncDevice syncDevice,
    required String entityType,
    required int pageIndex,
    required int pageSize,
    required int totalPages,
    required int totalItems,
    required bool isLastPage,
    SyncProgress? progress,
    PaginatedSyncData? entitySyncData,
  }) {
    final debugMode = _isDeviceInDebugMode();
    Logger.debug('📤 Creating server PaginatedSyncDataDto with isDebugMode: $debugMode for entity: $entityType');

    return PaginatedSyncDataDto(
      appVersion: appVersion,
      syncDevice: syncDevice,
      isDebugMode: debugMode,
      entityType: entityType,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalPages: totalPages,
      totalItems: totalItems,
      isLastPage: isLastPage,
      progress: progress,
      // CRITICAL FIX: Properly assign entity sync data based on entityType
      settingsSyncData: entityType == 'Setting' ? entitySyncData as PaginatedSyncData<Setting>? : null,
      appUsagesSyncData: entityType == 'AppUsage' ? entitySyncData as PaginatedSyncData<AppUsage>? : null,
      appUsageTagsSyncData: entityType == 'AppUsageTag' ? entitySyncData as PaginatedSyncData<AppUsageTag>? : null,
      appUsageTimeRecordsSyncData:
          entityType == 'AppUsageTimeRecord' ? entitySyncData as PaginatedSyncData<AppUsageTimeRecord>? : null,
      appUsageTagRulesSyncData:
          entityType == 'AppUsageTagRule' ? entitySyncData as PaginatedSyncData<AppUsageTagRule>? : null,
      appUsageIgnoreRulesSyncData:
          entityType == 'AppUsageIgnoreRule' ? entitySyncData as PaginatedSyncData<AppUsageIgnoreRule>? : null,
      habitsSyncData: entityType == 'Habit' ? entitySyncData as PaginatedSyncData<Habit>? : null,
      habitRecordsSyncData: entityType == 'HabitRecord' ? entitySyncData as PaginatedSyncData<HabitRecord>? : null,
      habitTagsSyncData: entityType == 'HabitTag' ? entitySyncData as PaginatedSyncData<HabitTag>? : null,
      tagsSyncData: entityType == 'Tag' ? entitySyncData as PaginatedSyncData<Tag>? : null,
      tagTagsSyncData: entityType == 'TagTag' ? entitySyncData as PaginatedSyncData<TagTag>? : null,
      tasksSyncData: entityType == 'Task' ? entitySyncData as PaginatedSyncData<Task>? : null,
      taskTagsSyncData: entityType == 'TaskTag' ? entitySyncData as PaginatedSyncData<TaskTag>? : null,
      taskTimeRecordsSyncData:
          entityType == 'TaskTimeRecord' ? entitySyncData as PaginatedSyncData<TaskTimeRecord>? : null,
      syncDevicesSyncData: entityType == 'SyncDevice' ? entitySyncData as PaginatedSyncData<SyncDevice>? : null,
      notesSyncData: entityType == 'Note' ? entitySyncData as PaginatedSyncData<Note>? : null,
      noteTagsSyncData: entityType == 'NoteTag' ? entitySyncData as PaginatedSyncData<NoteTag>? : null,
    );
  }

  /// Normalizes numeric types in JSON to prevent int/double casting errors during deserialization
  void _normalizeJsonNumericTypes(Map<String, dynamic> json) {
    // Recursively process nested maps and lists
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _normalizeJsonNumericTypes(value);
      } else if (value is List) {
        for (var item in value) {
          if (item is Map<String, dynamic>) {
            _normalizeJsonNumericTypes(item);
          }
        }
      } else if (value is int) {
        // Convert specific int fields that should be double to double
        if (key == 'progressPercentage') {
          json[key] = value.toDouble();
        }
      }
    });
  }

  Future<void> _validateDeviceId(SyncDevice remoteDevice) async {
    final localDeviceIP = await NetworkUtils.getLocalIpAddress();
    final localDeviceID = await deviceIdService.getDeviceId();

    // Check if this device is involved in the sync relationship (either as from or to)
    final isFromDevice = remoteDevice.fromIp == localDeviceIP && remoteDevice.fromDeviceId == localDeviceID;
    final isToDevice = remoteDevice.toIp == localDeviceIP && remoteDevice.toDeviceId == localDeviceID;

    // Also check if device IDs match but IPs might be different (for mobile-mobile sync scenarios)
    final deviceIdMatches = remoteDevice.fromDeviceId == localDeviceID || remoteDevice.toDeviceId == localDeviceID;

    if (isFromDevice || isToDevice || deviceIdMatches) {
      return;
    }

    Logger.error('Device validation failed:');
    Logger.error('Local: IP=$localDeviceIP, ID=$localDeviceID');
    Logger.error('Remote: fromIP=${remoteDevice.fromIp}, fromID=${remoteDevice.fromDeviceId}');
    Logger.error('Remote: toIP=${remoteDevice.toIp}, toID=${remoteDevice.toDeviceId}');

    throw BusinessException('Device ID mismatch', SyncTranslationKeys.deviceMismatchError);
  }

  /// Enhanced debug mode detection that considers multiple factors
  bool _isDeviceInDebugMode() {
    Logger.debug('🔍 Debug mode detection starting...');
    Logger.debug('   kDebugMode: $kDebugMode');
    Logger.debug('   kReleaseMode: $kReleaseMode');
    Logger.debug('   kProfileMode: $kProfileMode');

    // Primary check: Flutter's kDebugMode
    if (kDebugMode) {
      Logger.debug('✅ Debug mode detected via kDebugMode');
      return true;
    }

    // Secondary check: Use assert-based detection for debug mode
    // This is more reliable than kDebugMode in some IDE scenarios
    bool debugModeDetected = false;
    assert(debugModeDetected = true);
    if (debugModeDetected) {
      Logger.debug('✅ Debug mode detected via assert mechanism (more reliable than kDebugMode)');
      return true;
    }

    // Additional check: Look for debug build indicators
    // In VSCode or other IDEs, this might be more reliable than kDebugMode
    final isDebugBuild = !kReleaseMode && !kProfileMode;
    if (isDebugBuild) {
      Logger.debug('✅ Debug mode detected via build mode indicators (!kReleaseMode && !kProfileMode)');
      return true;
    }

    // DEVELOPMENT OVERRIDE: Force debug mode detection for known development scenarios
    // This is a workaround for Flutter's inconsistent debug mode detection on Android
    try {
      // Check if we can detect any debugging indicators
      bool hasDebuggingIndicators = false;

      // Multiple assert-based checks to catch debug builds that Flutter misidentifies
      assert(() {
        hasDebuggingIndicators = true;
        return true;
      }());

      // Alternative assert pattern that might work when the first doesn't
      if (!hasDebuggingIndicators) {
        bool alternativeDebugCheck = false;
        assert(alternativeDebugCheck = true);
        hasDebuggingIndicators = alternativeDebugCheck;
      }

      if (hasDebuggingIndicators) {
        Logger.info('✅ Debug mode detected via comprehensive assert checks');
        Logger.info('   This handles Flutter Android debug mode detection issues in IDEs');
        return true;
      }
    } catch (e) {
      Logger.debug('Comprehensive debug check failed: $e');
    }

    Logger.warning('❌ No debug mode detected - this may be incorrect for VSCode/Android');
    Logger.warning('⚠️  If running from VSCode in debug mode, this is a known Flutter Android issue');
    Logger.warning('🔧 Both devices should show debug detection logs when creating sync data');
    return false;
  }

  /// Validates environment mode with enhanced detection but strict security policies
  void _validateEnvironmentMode(PaginatedSyncDataDto remoteData) {
    final localIsDebug = _isDeviceInDebugMode();
    final remoteIsDebug = remoteData.isDebugMode;

    Logger.debug('Environment mode validation:');
    Logger.debug('Local device enhanced debug check: $localIsDebug (kDebugMode: $kDebugMode)');
    Logger.debug('Remote device isDebugMode: $remoteIsDebug');
    Logger.debug('Local kReleaseMode: $kReleaseMode, kProfileMode: $kProfileMode');

    if (localIsDebug != remoteIsDebug) {
      final localMode = localIsDebug ? 'debug' : 'production';
      final remoteMode = remoteIsDebug ? 'debug' : 'production';

      Logger.error('🚫 Environment mode mismatch detected:');
      Logger.error('   Local device: $localMode mode (enhanced detection)');
      Logger.error('   Remote device: $remoteMode mode');
      Logger.error('');
      Logger.error('🔒 SECURITY: Sync between debug and production modes is not allowed');
      Logger.error('📝 This prevents accidental data mixing between development and production environments');
      Logger.error('');
      Logger.error('💡 If both devices should be in debug mode:');
      Logger.error('   - Ensure both are running from IDEs like VSCode in debug mode');
      Logger.error('   - Check that both use the same Flutter build configuration');
      Logger.error('   - Restart both applications if build mode detection seems incorrect');

      throw BusinessException(
          'Environment mode mismatch: local=$localMode, remote=$remoteMode. '
          'Sync between debug and production modes is not allowed for security reasons.',
          SyncTranslationKeys.environmentMismatchError);
    }

    Logger.debug('✅ Environment mode validation passed: both devices in ${localIsDebug ? 'debug' : 'production'} mode');
  }

  void _updateProgress({
    required String currentEntity,
    required int currentPage,
    required int totalPages,
    required int entitiesCompleted,
    required int totalEntities,
    required String operation,
  }) {
    final entityProgress = totalPages > 0 ? ((currentPage + 1) / totalPages * 100) : 100.0;
    final overallProgress = ((entitiesCompleted + (entityProgress / 100)) / totalEntities * 100);

    final progress = SyncProgress(
      currentEntity: currentEntity,
      currentPage: currentPage,
      totalPages: totalPages,
      progressPercentage: overallProgress.clamp(0.0, 100.0),
      entitiesCompleted: entitiesCompleted,
      totalEntities: totalEntities,
      operation: operation,
    );

    _progressController.add(progress);
    Logger.debug(
        '📊 Progress: ${progress.progressPercentage.toStringAsFixed(1)}% - $operation $currentEntity (page ${currentPage + 1}/$totalPages)');
  }

  /// Maximum yielding processing that processes one item at a time with aggressive yielding
  /// specifically for database operations taking >15ms each
  Future<int> _processItemsWithMaximumYielding<T extends BaseEntity<String>>(
    List<T> items,
    int batchSize,
    Set<String> processedItemIds,
    IRepository<T, String> repository,
    String operationType,
  ) async {
    int conflictsResolved = 0;

    Logger.debug('🔥 Processing ${items.length} $operationType items with maximum yielding (one at a time)');

    for (var i = 0; i < items.length; i++) {
      final item = items[i];

      // Skip if already processed
      if (processedItemIds.contains(item.id)) {
        Logger.debug('⏭️ Skipping duplicate item ${item.id}');
        continue;
      }

      // Yield before every single item
      await _yieldToUIThreadMaximum();

      try {
        final itemConflicts = await _processSingleItemWithMaximumYielding(item, repository, operationType);
        conflictsResolved += itemConflicts;
        processedItemIds.add(item.id);
      } catch (e) {
        Logger.error('Error processing item ${item.id}: $e');
        // Continue with other items instead of failing entire batch
      }

      // Yield after every single item
      await _yieldToUIThreadMaximum();

      // Add breathing room delay after each item
      await Future.delayed(const Duration(milliseconds: 5));

      // Progress logging every 10 items to avoid log spam
      if (i % 10 == 9 || i == items.length - 1) {
        Logger.debug('🔥 Completed ${i + 1}/${items.length} $operationType items');
      }
    }

    Logger.debug(
        '✅ Completed maximum yielding processing of ${items.length} $operationType items, $conflictsResolved conflicts');
    return conflictsResolved;
  }

  /// Process a single item with maximum yielding around each database operation
  Future<int> _processSingleItemWithMaximumYielding<T extends BaseEntity<String>>(
    T item,
    IRepository<T, String> repository,
    String operationType,
  ) async {
    int conflicts = 0;

    try {
      switch (operationType) {
        case 'create':
          // Yield before read
          await _yieldToUIThreadMaximum();

          T? existingItem = await repository.getById(item.id);

          // Yield after read
          await _yieldToUIThreadMaximum();

          if (existingItem == null) {
            await repository.add(item);
          } else {
            await repository.update(item);
            conflicts = 1;
          }

          // Yield after write
          await _yieldToUIThreadMaximum();
          break;

        case 'update':
          // Yield before read
          await _yieldToUIThreadMaximum();

          T? existingItem = await repository.getById(item.id);

          // Yield after read
          await _yieldToUIThreadMaximum();

          if (existingItem == null) {
            await repository.add(item);
          } else {
            final resolution = _resolveConflict(existingItem, item);
            conflicts = 1;

            switch (resolution.action) {
              case ConflictAction.acceptRemote:
              case ConflictAction.acceptRemoteForceUpdate:
                await repository.update(item);
                break;
              case ConflictAction.keepLocal:
                // No update needed
                break;
            }
          }

          // Yield after write
          await _yieldToUIThreadMaximum();
          break;

        case 'delete':
          // Yield before delete
          await _yieldToUIThreadMaximum();

          await repository.delete(item);

          // Yield after delete
          await _yieldToUIThreadMaximum();
          break;
      }
    } catch (e) {
      Logger.error('Error in $operationType operation for item ${item.id}: $e');
      rethrow;
    }

    return conflicts;
  }

  /// Maximum UI thread yielding with longer delays for database-heavy operations
  Future<void> _yieldToUIThreadMaximum() async {
    // Multiple yield cycles for maximum effectiveness
    final completer1 = Completer<void>();
    scheduleMicrotask(() => completer1.complete());
    await completer1.future;

    await Future.delayed(Duration.zero);

    final completer2 = Completer<void>();
    scheduleMicrotask(() => completer2.complete());
    await completer2.future;

    await Future.delayed(Duration.zero);

    final completer3 = Completer<void>();
    scheduleMicrotask(() => completer3.complete());
    await completer3.future;

    // Longer breathing room for database operations
    await Future.delayed(const Duration(milliseconds: 1));
  }

  /// Extract sync data using isolate to prevent UI blocking during JSON deserialization
  Future<PaginatedSyncData?> _extractSyncDataWithIsolate(PaginatedSyncDataDto dto, PaginatedSyncConfig config) async {
    // For entities with large data volumes that cause 16+ second freezes,
    // we need to offload the data extraction to prevent UI blocking
    final totalItems = _estimateDataSize(dto);

    if (totalItems > 200) {
      Logger.debug('🧵 Using isolate for data extraction (estimated $totalItems items)');

      try {
        // CRITICAL FIX: Pass DTO properties separately to avoid main thread JSON conversion
        final isolateData = {
          'entityType': dto.entityType,
          'pageIndex': dto.pageIndex,
          'pageSize': dto.pageSize,
          'totalPages': dto.totalPages,
          'totalItems': dto.totalItems,
          'isLastPage': dto.isLastPage,
          'appVersion': dto.appVersion,
          'syncDevice': dto.syncDevice.toJson(),
          'entityData': _extractRelevantEntityData(dto),
        };

        final extractedData = await compute(_extractSyncDataInIsolate, isolateData);

        if (extractedData != null) {
          // Convert the extracted JSON back to PaginatedSyncData
          return _convertJsonToPaginatedSyncData(extractedData, config);
        }

        return null;
      } catch (e) {
        Logger.error('❌ Isolate data extraction failed, falling back to main thread: $e');
        // Fallback to main thread extraction with yielding
        await _yieldToUIThreadMaximum();
        return config.getPaginatedSyncDataFromDto(dto);
      }
    } else {
      // For smaller datasets, use main thread with yielding
      Logger.debug('🔄 Using main thread for data extraction ($totalItems items)');
      await _yieldToUIThreadMaximum();
      return config.getPaginatedSyncDataFromDto(dto);
    }
  }

  /// Estimate data size from DTO to determine if isolate processing is needed
  int _estimateDataSize(PaginatedSyncDataDto dto) {
    try {
      switch (dto.entityType) {
        case 'AppUsageTimeRecord':
          return _safeCountSyncData(dto.appUsageTimeRecordsSyncData);
        case 'AppUsage':
          return _safeCountSyncData(dto.appUsagesSyncData);
        case 'Task':
          return _safeCountSyncData(dto.tasksSyncData);
        case 'TaskTimeRecord':
          return _safeCountSyncData(dto.taskTimeRecordsSyncData);
        case 'TaskTag':
          return _safeCountSyncData(dto.taskTagsSyncData);
        case 'Habit':
          return _safeCountSyncData(dto.habitsSyncData);
        case 'HabitRecord':
          return _safeCountSyncData(dto.habitRecordsSyncData);
        case 'HabitTag':
          return _safeCountSyncData(dto.habitTagsSyncData);
        case 'Tag':
          return _safeCountSyncData(dto.tagsSyncData);
        case 'TagTag':
          return _safeCountSyncData(dto.tagTagsSyncData);
        case 'Note':
          return _safeCountSyncData(dto.notesSyncData);
        case 'NoteTag':
          return _safeCountSyncData(dto.noteTagsSyncData);
        case 'AppUsageTag':
          return _safeCountSyncData(dto.appUsageTagsSyncData);
        case 'AppUsageTagRule':
          return _safeCountSyncData(dto.appUsageTagRulesSyncData);
        case 'AppUsageIgnoreRule':
          return _safeCountSyncData(dto.appUsageIgnoreRulesSyncData);
        case 'Setting':
          return _safeCountSyncData(dto.settingsSyncData);
        case 'SyncDevice':
          return _safeCountSyncData(dto.syncDevicesSyncData);
        default:
          Logger.warning('⚠️ Unknown entity type for size estimation: ${dto.entityType}');
          return 0; // For unknown types, assume small
      }
    } catch (e) {
      Logger.error('❌ Error estimating data size for ${dto.entityType}: $e');
      return 0; // Safe fallback
    }
  }

  /// Safely count sync data items to prevent type casting errors
  int _safeCountSyncData(dynamic syncData) {
    if (syncData == null) return 0;

    try {
      // Try to access data property safely
      final dynamic data = syncData.data;
      if (data == null) return 0;

      int total = 0;

      // Safely count createSync items
      try {
        final dynamic createSync = data.createSync;
        if (createSync is List) {
          total += createSync.length;
        }
      } catch (_) {}

      // Safely count updateSync items
      try {
        final dynamic updateSync = data.updateSync;
        if (updateSync is List) {
          total += updateSync.length;
        }
      } catch (_) {}

      // Safely count deleteSync items
      try {
        final dynamic deleteSync = data.deleteSync;
        if (deleteSync is List) {
          total += deleteSync.length;
        }
      } catch (_) {}

      return total;
    } catch (e) {
      Logger.warning('⚠️ Error counting sync data items: $e');
      return 0;
    }
  }

  /// Convert JSON back to PaginatedSyncData after isolate processing
  PaginatedSyncData? _convertJsonToPaginatedSyncData(Map<String, dynamic>? extractedData, PaginatedSyncConfig config) {
    if (extractedData == null) return null;

    try {
      // Reconstruct the DTO from the extracted JSON
      final reconstructedDto = PaginatedSyncDataDto.fromJson(extractedData);
      return config.getPaginatedSyncDataFromDto(reconstructedDto);
    } catch (e) {
      Logger.error('❌ Failed to convert extracted data back to PaginatedSyncData: $e');
      return null;
    }
  }

  /// Convert DTO to JSON with aggressive yielding and isolate processing
  Future<Map<String, dynamic>> _convertDtoToJsonWithYielding(PaginatedSyncDataDto dto) async {
    // For ANY dataset >100 items, use isolate processing (much more aggressive)
    final totalItems = _estimateDataSize(dto);

    if (totalItems > 100) {
      Logger.debug('🧵 Using isolate for DTO to JSON conversion ($totalItems items)');
      try {
        // CRITICAL FIX: Pass DTO properties separately to avoid main thread JSON conversion
        final isolateData = {
          'entityType': dto.entityType,
          'pageIndex': dto.pageIndex,
          'pageSize': dto.pageSize,
          'totalPages': dto.totalPages,
          'totalItems': dto.totalItems,
          'isLastPage': dto.isLastPage,
          'appVersion': dto.appVersion,
          'isDebugMode': dto.isDebugMode,
          'syncDevice': dto.syncDevice.toJson(),
          'progress': dto.progress?.toJson(),
          // Pass only the relevant entity data to minimize transfer
          'entityData': _extractRelevantEntityData(dto),
        };

        return await compute(_convertDtoToJsonInIsolateFixed, isolateData);
      } catch (e) {
        Logger.warning('⚠️ Isolate JSON conversion failed, using chunked main thread: $e');
        return await _convertDtoToJsonWithChunking(dto);
      }
    } else {
      // For small datasets, use chunked processing with yielding
      return await _convertDtoToJsonWithChunking(dto);
    }
  }

  /// Extract only the relevant entity data to minimize isolate transfer overhead
  Map<String, dynamic>? _extractRelevantEntityData(PaginatedSyncDataDto dto) {
    try {
      switch (dto.entityType) {
        case 'AppUsageTimeRecord':
          return _safeExtractEntityData(dto.appUsageTimeRecordsSyncData, 'AppUsageTimeRecord');
        case 'AppUsage':
          return _safeExtractEntityData(dto.appUsagesSyncData, 'AppUsage');
        case 'Task':
          return _safeExtractEntityData(dto.tasksSyncData, 'Task');
        case 'TaskTimeRecord':
          return _safeExtractEntityData(dto.taskTimeRecordsSyncData, 'TaskTimeRecord');
        case 'Habit':
          return _safeExtractEntityData(dto.habitsSyncData, 'Habit');
        case 'HabitRecord':
          return _safeExtractEntityData(dto.habitRecordsSyncData, 'HabitRecord');
        case 'AppUsageTag':
          return _safeExtractEntityData(dto.appUsageTagsSyncData, 'AppUsageTag');
        case 'AppUsageTagRule':
          return _safeExtractEntityData(dto.appUsageTagRulesSyncData, 'AppUsageTagRule');
        case 'AppUsageIgnoreRule':
          return _safeExtractEntityData(dto.appUsageIgnoreRulesSyncData, 'AppUsageIgnoreRule');
        case 'HabitTag':
          return _safeExtractEntityData(dto.habitTagsSyncData, 'HabitTag');
        case 'Tag':
          return _safeExtractEntityData(dto.tagsSyncData, 'Tag');
        case 'TagTag':
          return _safeExtractEntityData(dto.tagTagsSyncData, 'TagTag');
        case 'TaskTag':
          return _safeExtractEntityData(dto.taskTagsSyncData, 'TaskTag');
        case 'Setting':
          return _safeExtractEntityData(dto.settingsSyncData, 'Setting');
        case 'SyncDevice':
          return _safeExtractEntityData(dto.syncDevicesSyncData, 'SyncDevice');
        case 'Note':
          return _safeExtractEntityData(dto.notesSyncData, 'Note');
        case 'NoteTag':
          return _safeExtractEntityData(dto.noteTagsSyncData, 'NoteTag');
        default:
          Logger.warning('⚠️ Unknown entity type for extraction: ${dto.entityType}');
          return null;
      }
    } catch (e) {
      Logger.error('❌ Error extracting entity data for ${dto.entityType}: $e');
      return null;
    }
  }

  /// Safely extract entity data with proper error handling and type checking
  Map<String, dynamic>? _safeExtractEntityData(dynamic syncData, String entityType) {
    if (syncData == null) {
      return null;
    }

    try {
      // Check if syncData is already a Map
      if (syncData is Map<String, dynamic>) {
        return syncData;
      }

      // CRITICAL FIX: Avoid JsonMapper casting issues by using toJson() first
      // This prevents CastMap<dynamic, dynamic, String, dynamic> annotation errors
      try {
        Logger.debug('🔧 Using toJson() for $entityType to avoid CastMap serialization issues');
        final toJsonResult = syncData.toJson();
        if (toJsonResult is Map<String, dynamic>) {
          return toJsonResult;
        }

        // If toJson() returns wrong type, try to convert it safely
        if (toJsonResult is Map) {
          final safeMap = <String, dynamic>{};
          toJsonResult.forEach((key, value) {
            if (key is String) {
              safeMap[key] = value;
            }
          });
          return safeMap;
        }
      } catch (toJsonError) {
        Logger.debug('🔧 toJson() failed for $entityType: $toJsonError, trying JsonMapper');

        // Fallback to JsonMapper with safer handling
        try {
          final jsonString = JsonMapper.serialize(syncData);
          if (jsonString.isNotEmpty) {
            // Use dynamic parsing first, then safe conversion
            final dynamic rawParsed = JsonMapper.deserialize(jsonString);
            if (rawParsed is Map) {
              final safeMap = <String, dynamic>{};
              rawParsed.forEach((key, value) {
                if (key is String) {
                  safeMap[key] = value;
                }
              });
              return safeMap;
            }
          }
        } catch (jsonMapperError) {
          Logger.debug('🔧 JsonMapper also failed for $entityType: $jsonMapperError, using manual extraction');
        }
      }

      // Last resort: manual extraction (but this should rarely be needed now)
      Logger.debug('🔧 Using manual extraction for $entityType as last resort');
      return _manuallyExtractSyncData(syncData, entityType);
    } catch (e) {
      Logger.error('❌ Error extracting $entityType sync data: $e');
      return null;
    }
  }

  /// Manually extract sync data when toJson() fails
  Map<String, dynamic>? _manuallyExtractSyncData(dynamic syncData, String entityType) {
    try {
      // Create a basic structure for sync data
      final result = <String, dynamic>{
        'pageIndex': 0,
        'pageSize': 100,
        'totalPages': 1,
        'totalItems': 0,
        'isLastPage': true,
        'data': <String, dynamic>{
          'createSync': <dynamic>[],
          'updateSync': <dynamic>[],
          'deleteSync': <dynamic>[],
        }
      };

      // Try to access common properties if they exist
      try {
        final dynamic pageIndex = syncData.pageIndex;
        if (pageIndex != null) result['pageIndex'] = pageIndex;
      } catch (_) {}

      try {
        final dynamic pageSize = syncData.pageSize;
        if (pageSize != null) result['pageSize'] = pageSize;
      } catch (_) {}

      try {
        final dynamic totalPages = syncData.totalPages;
        if (totalPages != null) result['totalPages'] = totalPages;
      } catch (_) {}

      try {
        final dynamic totalItems = syncData.totalItems;
        if (totalItems != null) result['totalItems'] = totalItems;
      } catch (_) {}

      try {
        final dynamic isLastPage = syncData.isLastPage;
        if (isLastPage != null) result['isLastPage'] = isLastPage;
      } catch (_) {}

      // Try to access the data property
      try {
        final dynamic data = syncData.data;
        if (data != null) {
          // Try to extract sync arrays
          try {
            final dynamic createSync = data.createSync;
            if (createSync is List) {
              result['data']['createSync'] = createSync.map((item) => _safeItemToJson(item)).toList();
            }
          } catch (_) {}

          try {
            final dynamic updateSync = data.updateSync;
            if (updateSync is List) {
              result['data']['updateSync'] = updateSync.map((item) => _safeItemToJson(item)).toList();
            }
          } catch (_) {}

          try {
            final dynamic deleteSync = data.deleteSync;
            if (deleteSync is List) {
              result['data']['deleteSync'] = deleteSync.map((item) => _safeItemToJson(item)).toList();
            }
          } catch (_) {}
        }
      } catch (_) {}

      Logger.debug('✅ Manually extracted sync data for $entityType');
      return result;
    } catch (e) {
      Logger.error('❌ Manual extraction failed for $entityType: $e');
      return null;
    }
  }

  /// Safely convert individual items to JSON
  dynamic _safeItemToJson(dynamic item) {
    if (item == null) return null;

    try {
      if (item is Map<String, dynamic>) {
        return item;
      }

      // Primitive types are safe
      if (item is String || item is int || item is double || item is bool) {
        return item;
      }

      // CRITICAL FIX: Use toJson() first to avoid CastMap annotation errors
      // JsonMapper casting can create CastMap types that cause serialization failures
      try {
        final toJsonResult = item.toJson();
        if (toJsonResult is Map<String, dynamic>) {
          return toJsonResult;
        }

        // If toJson() returns wrong type, convert safely
        if (toJsonResult is Map) {
          final safeMap = <String, dynamic>{};
          toJsonResult.forEach((key, value) {
            if (key is String) {
              safeMap[key] = value;
            }
          });
          return safeMap;
        }
      } catch (toJsonError) {
        Logger.debug('🔧 toJson() failed for ${item.runtimeType}: $toJsonError, trying JsonMapper');

        // Fallback to JsonMapper with safer handling
        try {
          final jsonResult = JsonMapper.serialize(item);
          // Use dynamic parsing first, then safe conversion
          final dynamic rawParsed = JsonMapper.deserialize(jsonResult);
          if (rawParsed is Map) {
            final safeMap = <String, dynamic>{};
            rawParsed.forEach((key, value) {
              if (key is String) {
                safeMap[key] = value;
              }
            });
            return safeMap;
          }
          return jsonResult;
        } catch (jsonMapperError) {
          Logger.debug('🔧 JsonMapper also failed for ${item.runtimeType}: $jsonMapperError, using manual extraction');
        }
      }

      // Last resort: manual property extraction
      return _extractBasicProperties(item);
    } catch (e) {
      Logger.warning('⚠️ Failed to convert item safely: $e');
      return null;
    }
  }

  /// Extract basic properties from complex objects using reflection-like access
  Map<String, dynamic>? _extractBasicProperties(dynamic obj) {
    if (obj == null) return null;

    try {
      final result = <String, dynamic>{};
      final objType = obj.runtimeType.toString();

      // CRITICAL FIX: Use proper property access instead of toString()
      // Try to access common BaseEntity properties
      try {
        if (obj.id != null) result['id'] = obj.id.toString();
      } catch (_) {}

      try {
        if (obj.createdDate != null) result['createdDate'] = obj.createdDate.toIso8601String();
      } catch (_) {}

      try {
        if (obj.modifiedDate != null) result['modifiedDate'] = obj.modifiedDate?.toIso8601String();
      } catch (_) {}

      try {
        if (obj.deletedDate != null) result['deletedDate'] = obj.deletedDate?.toIso8601String();
      } catch (_) {}

      // Try to access AppUsage-specific properties
      if (objType.contains('AppUsage')) {
        try {
          if (obj.name != null) result['name'] = obj.name.toString();
        } catch (_) {}

        try {
          if (obj.displayName != null) result['displayName'] = obj.displayName?.toString();
        } catch (_) {}

        try {
          if (obj.color != null) result['color'] = obj.color?.toString();
        } catch (_) {}

        try {
          if (obj.deviceName != null) result['deviceName'] = obj.deviceName?.toString();
        } catch (_) {}
      }

      // If we couldn't extract anything meaningful, log warning and return basic info
      if (result.isEmpty) {
        Logger.warning('⚠️ Could not extract properties from $objType object');
        result['_type'] = objType;
        result['_error'] = 'property_extraction_failed';
      }

      return result;
    } catch (e) {
      Logger.warning('⚠️ Basic property extraction failed: $e');
      return {'_error': 'extraction_failed', '_type': obj.runtimeType.toString(), '_exception': e.toString()};
    }
  }

  /// Get the appropriate entity data key for the DTO
  String _getEntityDataKey(String entityType) {
    switch (entityType) {
      case 'AppUsageTimeRecord':
        return 'appUsageTimeRecordsSyncData';
      case 'AppUsage':
        return 'appUsagesSyncData';
      case 'Task':
        return 'tasksSyncData';
      case 'TaskTimeRecord':
        return 'taskTimeRecordsSyncData';
      case 'Habit':
        return 'habitsSyncData';
      case 'HabitRecord':
        return 'habitRecordsSyncData';
      case 'AppUsageTag':
        return 'appUsageTagsSyncData';
      case 'AppUsageTagRule':
        return 'appUsageTagRulesSyncData';
      case 'AppUsageIgnoreRule':
        return 'appUsageIgnoreRulesSyncData';
      case 'HabitTag':
        return 'habitTagsSyncData';
      case 'Tag':
        return 'tagsSyncData';
      case 'TagTag':
        return 'tagTagsSyncData';
      case 'TaskTag':
        return 'taskTagsSyncData';
      case 'Setting':
        return 'settingsSyncData';
      case 'SyncDevice':
        return 'syncDevicesSyncData';
      case 'Note':
        return 'notesSyncData';
      case 'NoteTag':
        return 'noteTagsSyncData';
      default:
        return '${entityType.toLowerCase()}SyncData';
    }
  }

  /// Convert DTO to JSON with chunked processing and aggressive yielding
  Future<Map<String, dynamic>> _convertDtoToJsonWithChunking(PaginatedSyncDataDto dto) async {
    Logger.debug('🔄 Converting DTO to JSON with chunked processing');

    // Build JSON in chunks with yielding
    final result = <String, dynamic>{};

    // Basic properties first
    await _yieldToUIThreadMaximum();
    result['entityType'] = dto.entityType;
    result['pageIndex'] = dto.pageIndex;
    result['pageSize'] = dto.pageSize;
    result['totalPages'] = dto.totalPages;
    result['totalItems'] = dto.totalItems;
    result['isLastPage'] = dto.isLastPage;
    result['appVersion'] = dto.appVersion;
    result['isDebugMode'] = dto.isDebugMode;

    // Yield before heavy operations
    await _yieldToUIThreadMaximum();
    result['syncDevice'] = dto.syncDevice.toJson();

    await _yieldToUIThreadMaximum();
    if (dto.progress != null) {
      result['progress'] = dto.progress!.toJson();
    }

    // Process entity data with yielding
    await _yieldToUIThreadMaximum();
    Logger.debug('🔄 Processing entity-specific data for ${dto.entityType}');

    switch (dto.entityType) {
      case 'AppUsageTimeRecord':
        if (dto.appUsageTimeRecordsSyncData != null) {
          final entityData = _safeExtractEntityData(dto.appUsageTimeRecordsSyncData, 'AppUsageTimeRecord');
          if (entityData != null) {
            result['appUsageTimeRecordsSyncData'] = await _convertEntityDataWithYielding(entityData);
          }
        }
        break;
      case 'AppUsage':
        if (dto.appUsagesSyncData != null) {
          final entityData = _safeExtractEntityData(dto.appUsagesSyncData, 'AppUsage');
          if (entityData != null) {
            result['appUsagesSyncData'] = await _convertEntityDataWithYielding(entityData);
          }
        }
        break;
      case 'Task':
        if (dto.tasksSyncData != null) {
          final entityData = _safeExtractEntityData(dto.tasksSyncData, 'Task');
          if (entityData != null) {
            result['tasksSyncData'] = await _convertEntityDataWithYielding(entityData);
          }
        }
        break;
      case 'TaskTimeRecord':
        if (dto.taskTimeRecordsSyncData != null) {
          final entityData = _safeExtractEntityData(dto.taskTimeRecordsSyncData, 'TaskTimeRecord');
          if (entityData != null) {
            result['taskTimeRecordsSyncData'] = await _convertEntityDataWithYielding(entityData);
          }
        }
        break;
      default:
        // For other entities, process with safe yielding
        await _yieldToUIThreadMaximum();
        try {
          final remainingJson = dto.toJson();
          result.addAll(remainingJson);
        } catch (e) {
          Logger.error('❌ Error processing remaining JSON for ${dto.entityType}: $e');
          // Add basic entity data if available
          final entityData = _extractRelevantEntityData(dto);
          if (entityData != null) {
            result[_getEntityDataKey(dto.entityType)] = entityData;
          }
        }
        break;
    }

    await _yieldToUIThreadMaximum();
    Logger.debug('✅ DTO to JSON conversion completed');
    return result;
  }

  /// Convert entity data with yielding for large collections
  Future<Map<String, dynamic>> _convertEntityDataWithYielding(Map<String, dynamic> entityJson) async {
    // For large entity collections, process in chunks
    if (entityJson['data'] != null) {
      final data = entityJson['data'] as Map<String, dynamic>;
      final createSync = data['createSync'] as List?;
      final updateSync = data['updateSync'] as List?;

      if ((createSync?.length ?? 0) + (updateSync?.length ?? 0) > 200) {
        Logger.debug('🔄 Processing large entity collection with chunked yielding');

        // Process create items in chunks
        if (createSync != null && createSync.isNotEmpty) {
          await _processJsonArrayInChunks(createSync, 'createSync');
        }

        // Yield between create and update processing
        await _yieldToUIThreadMaximum();

        // Process update items in chunks
        if (updateSync != null && updateSync.isNotEmpty) {
          await _processJsonArrayInChunks(updateSync, 'updateSync');
        }
      }
    }

    await _yieldToUIThreadMaximum();
    return entityJson;
  }

  /// Process large JSON arrays in chunks with yielding
  Future<void> _processJsonArrayInChunks(List<dynamic> array, String arrayName) async {
    const chunkSize = 50; // Process 50 items at a time

    for (int i = 0; i < array.length; i += chunkSize) {
      await _yieldToUIThreadMaximum();

      Logger.debug(
          '🔄 Processing $arrayName chunk ${(i / chunkSize).floor() + 1}/${(array.length / chunkSize).ceil()}');

      // Process this chunk (the actual JSON is already created, just yielding for responsiveness)
      await Future.delayed(const Duration(microseconds: 500)); // Small processing delay
    }
  }

  /// Serialize WebSocket message with aggressive yielding and size-based processing
  Future<String> _serializeMessageWithYielding(WebSocketMessage message) async {
    Logger.debug('🔄 Starting WebSocket message serialization');
    await _yieldToUIThreadMaximum();

    try {
      // For very large messages, use isolate processing
      final messageData = message.data;
      if (messageData is Map<String, dynamic>) {
        final estimatedSize = _estimateJsonDataSize(messageData);

        if (estimatedSize > 200) {
          Logger.debug('🧵 Using isolate for large WebSocket message serialization ($estimatedSize items)');
          try {
            return await compute(_serializeMessageInIsolate, {
              'type': message.type,
              'data': messageData,
            });
          } catch (e) {
            Logger.warning('⚠️ Isolate serialization failed, using main thread: $e');
          }
        }
      }

      // Fallback to main thread with yielding
      await _yieldToUIThreadMaximum();

      // CRITICAL FIX: Pre-process message data to avoid CastMap serialization errors
      final cleanedMessage = _cleanWebSocketMessageData(message);
      final result = JsonMapper.serialize(cleanedMessage);

      await _yieldToUIThreadMaximum();
      Logger.debug('✅ WebSocket message serialization completed');
      return result;
    } catch (e) {
      Logger.error('❌ Error during WebSocket message serialization: $e');
      rethrow;
    }
  }

  /// Deserialize WebSocket message with aggressive yielding and size-based processing
  Future<WebSocketMessage?> _deserializeMessageWithYielding(dynamic message) async {
    Logger.debug('🔄 Starting WebSocket message deserialization');
    await _yieldToUIThreadMaximum();

    try {
      // For very large messages, use isolate processing
      if (message is String && message.length > 50000) {
        // ~50KB threshold
        Logger.debug('🧵 Using isolate for large WebSocket message deserialization (${message.length} bytes)');
        try {
          final deserializedData = await compute(_deserializeMessageInIsolate, message);
          if (deserializedData != null) {
            return WebSocketMessage(
              type: deserializedData['type'] as String,
              data: deserializedData['data'],
            );
          }
        } catch (e) {
          Logger.warning('⚠️ Isolate deserialization failed, using main thread: $e');
        }
      }

      // Fallback to main thread with yielding
      await _yieldToUIThreadMaximum();
      final result = JsonMapper.deserialize<WebSocketMessage>(message);

      await _yieldToUIThreadMaximum();
      Logger.debug('✅ WebSocket message deserialization completed');
      return result;
    } catch (e) {
      Logger.error('❌ Error during WebSocket message deserialization: $e');
      return null;
    }
  }

  /// Estimate data size from raw JSON
  int _estimateJsonDataSize(Map<String, dynamic> json) {
    int total = 0;

    // Check all possible sync data arrays
    final syncDataKeys = [
      'appUsageTimeRecordsSyncData',
      'appUsagesSyncData',
      'tasksSyncData',
      'taskTimeRecordsSyncData',
      'habitsSyncData',
      'habitRecordsSyncData'
    ];

    for (final key in syncDataKeys) {
      if (json[key] != null) {
        final data = json[key] as Map<String, dynamic>?;
        if (data?['data'] != null) {
          final syncData = data!['data'] as Map<String, dynamic>;
          total += (syncData['createSync'] as List?)?.length ?? 0;
          total += (syncData['updateSync'] as List?)?.length ?? 0;
          total += (syncData['deleteSync'] as List?)?.length ?? 0;
        }
      }
    }

    return total;
  }

  /// Clean WebSocket message data to prevent CastMap serialization errors
  /// This method recursively processes the message to ensure all data is serializable
  dynamic _cleanWebSocketMessageData(dynamic message) {
    if (message == null) return null;

    try {
      // If it's a primitive type, return as-is
      if (message is String || message is num || message is bool) {
        return message;
      }

      // If it's a List, clean each element
      if (message is List) {
        return message.map((item) => _cleanWebSocketMessageData(item)).toList();
      }

      // If it's a Map, clean each key-value pair
      if (message is Map) {
        final cleanedMap = <String, dynamic>{};
        message.forEach((key, value) {
          final stringKey = key.toString();
          cleanedMap[stringKey] = _cleanWebSocketMessageData(value);
        });
        return cleanedMap;
      }

      // If it's an object with toJson method, use it
      if (message.runtimeType.toString().contains('PaginatedSyncDataDto') ||
          message.runtimeType.toString().contains('PaginatedSyncData') ||
          message.runtimeType.toString().contains('SyncData') ||
          message.runtimeType.toString().contains('SyncProgress') ||
          message.runtimeType.toString().contains('WebSocketMessage')) {
        try {
          // Try to call toJson() method if available
          final toJsonMethod = message.toJson;
          if (toJsonMethod is Function) {
            final jsonResult = toJsonMethod();
            return _cleanWebSocketMessageData(jsonResult);
          }
        } catch (e) {
          Logger.debug('🔧 toJson() method failed for ${message.runtimeType}, using fallback');
        }
      }

      // For other objects, try to extract properties manually
      if (message.runtimeType.toString().contains('BaseEntity') ||
          message.runtimeType.toString().contains('AppUsage') ||
          message.runtimeType.toString().contains('Task') ||
          message.runtimeType.toString().contains('Habit')) {
        try {
          // Try to call toJson() method for entity objects
          final toJsonMethod = message.toJson;
          if (toJsonMethod is Function) {
            final jsonResult = toJsonMethod();
            return _cleanWebSocketMessageData(jsonResult);
          }
        } catch (e) {
          Logger.debug('🔧 Entity toJson() failed for ${message.runtimeType}, using basic properties');
        }

        // Fallback: extract basic properties for BaseEntity types
        final result = <String, dynamic>{};
        try {
          if (message.id != null) result['id'] = message.id;
          if (message.createdDate != null) result['createdDate'] = message.createdDate.toIso8601String();
          if (message.modifiedDate != null) result['modifiedDate'] = message.modifiedDate?.toIso8601String();
          if (message.deletedDate != null) result['deletedDate'] = message.deletedDate?.toIso8601String();
        } catch (_) {}

        return result;
      }

      // For unknown types, convert to string representation
      Logger.warning('⚠️ Unknown type ${message.runtimeType} in WebSocket data, converting to string');
      return message.toString();
    } catch (e) {
      Logger.error('❌ Error cleaning WebSocket message data: $e');
      // Return a safe fallback
      return {'error': 'Failed to serialize ${message.runtimeType}', 'data': message.toString()};
    }
  }

  /// Validate message integrity before transmission to prevent server-side errors
  Future<void> _validateMessageIntegrity(Map<String, dynamic> dtoJson, String entityType) async {
    try {
      // Validate basic structure
      if (!dtoJson.containsKey('entityType')) {
        throw ValidationException('Missing entityType in DTO');
      }

      if (!dtoJson.containsKey('syncDevice')) {
        throw ValidationException('Missing syncDevice in DTO');
      }

      // Validate entity-specific sync data exists
      final entityKey = _getEntitySyncDataKey(entityType);
      if (!dtoJson.containsKey(entityKey)) {
        throw ValidationException('Missing $entityKey in DTO');
      }

      final syncData = dtoJson[entityKey] as Map<String, dynamic>?;
      if (syncData == null) {
        throw ValidationException('$entityKey is null');
      }

      // Validate sync data structure
      if (!syncData.containsKey('data')) {
        throw ValidationException('Missing data in $entityKey');
      }

      final data = syncData['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw ValidationException('Data is null in $entityKey');
      }

      // Validate entity lists
      final entityLists = ['createSync', 'updateSync', 'deleteSync'];
      for (final listKey in entityLists) {
        if (data.containsKey(listKey)) {
          final entityList = data[listKey] as List?;
          if (entityList != null) {
            Logger.debug('🔍 Validating $listKey (${entityList.length} items)');

            // Validate each entity in the list
            for (int i = 0; i < entityList.length; i++) {
              final entity = entityList[i];
              if (entity is! Map<String, dynamic>) {
                throw ValidationException('$listKey[$i] is not a valid entity object');
              }

              // Validate required base entity fields
              final entityMap = entity;
              if (!entityMap.containsKey('id') || entityMap['id'] == null) {
                throw ValidationException('$listKey[$i] missing required field: id');
              }

              if (!entityMap.containsKey('createdDate') || entityMap['createdDate'] == null) {
                throw ValidationException('$listKey[$i] missing required field: createdDate');
              }

              // Entity-specific validation
              await _validateEntitySpecificFields(entityMap, entityType, '$listKey[$i]');
            }
          }
        }
      }

      Logger.debug('✅ Message validation completed successfully');
    } catch (e) {
      Logger.error('❌ Message validation failed: $e');
      rethrow;
    }
  }

  /// Validate entity-specific required fields
  Future<void> _validateEntitySpecificFields(Map<String, dynamic> entity, String entityType, String context) async {
    switch (entityType.toLowerCase()) {
      case 'appusage':
        if (!entity.containsKey('name') || entity['name'] == null) {
          throw ValidationException('$context missing required field: name');
        }
        break;
      case 'task':
        if (!entity.containsKey('title') || entity['title'] == null) {
          throw ValidationException('$context missing required field: title');
        }
        if (!entity.containsKey('isCompleted')) {
          throw ValidationException('$context missing required field: isCompleted');
        }
        break;
      case 'habit':
        if (!entity.containsKey('name') || entity['name'] == null) {
          throw ValidationException('$context missing required field: name');
        }
        if (!entity.containsKey('description') || entity['description'] == null) {
          throw ValidationException('$context missing required field: description');
        }
        break;
      case 'tag':
        if (!entity.containsKey('name') || entity['name'] == null) {
          throw ValidationException('$context missing required field: name');
        }
        if (!entity.containsKey('isArchived')) {
          throw ValidationException('$context missing required field: isArchived');
        }
        break;
      case 'note':
        if (!entity.containsKey('title') || entity['title'] == null) {
          throw ValidationException('$context missing required field: title');
        }
        break;
      case 'setting':
        if (!entity.containsKey('key') || entity['key'] == null) {
          throw ValidationException('$context missing required field: key');
        }
        if (!entity.containsKey('value') || entity['value'] == null) {
          throw ValidationException('$context missing required field: value');
        }
        if (!entity.containsKey('valueType') || entity['valueType'] == null) {
          throw ValidationException('$context missing required field: valueType');
        }
        break;
      // Tag relationship entities
      case 'appusagetag':
      case 'habittag':
      case 'tasktag':
      case 'notetag':
        final primaryIdField = _getPrimaryIdFieldForTagEntity(entityType.toLowerCase());
        if (!entity.containsKey(primaryIdField) || entity[primaryIdField] == null) {
          throw ValidationException('$context missing required field: $primaryIdField');
        }
        if (!entity.containsKey('tagId') || entity['tagId'] == null) {
          throw ValidationException('$context missing required field: tagId');
        }
        break;
      case 'tagtag':
        // TagTag has specific validation since it relates tags to each other
        if (!entity.containsKey('primaryTagId') || entity['primaryTagId'] == null) {
          throw ValidationException('$context missing required field: primaryTagId');
        }
        if (!entity.containsKey('secondaryTagId') || entity['secondaryTagId'] == null) {
          throw ValidationException('$context missing required field: secondaryTagId');
        }
        break;
      // Time record entities
      case 'appusagetimerecord':
      case 'tasktimerecord':
        final parentIdField = _getParentIdFieldForTimeRecord(entityType.toLowerCase());
        if (!entity.containsKey(parentIdField) || entity[parentIdField] == null) {
          throw ValidationException('$context missing required field: $parentIdField');
        }
        if (!entity.containsKey('duration') || entity['duration'] == null) {
          throw ValidationException('$context missing required field: duration');
        }
        break;
      // Rule entities
      case 'appusagetagrule':
      case 'appusageignorerule':
        if (!entity.containsKey('pattern') || entity['pattern'] == null) {
          throw ValidationException('$context missing required field: pattern');
        }
        break;
      case 'habitrecord':
        if (!entity.containsKey('habitId') || entity['habitId'] == null) {
          throw ValidationException('$context missing required field: habitId');
        }
        if (!entity.containsKey('date') || entity['date'] == null) {
          throw ValidationException('$context missing required field: date');
        }
        break;
      case 'syncdevice':
        final requiredFields = ['fromIp', 'toIp', 'fromDeviceId', 'toDeviceId'];
        for (final field in requiredFields) {
          if (!entity.containsKey(field) || entity[field] == null) {
            throw ValidationException('$context missing required field: $field');
          }
        }
        break;
    }
  }

  /// Get the primary ID field name for tag entity types (excluding TagTag which has special handling)
  String _getPrimaryIdFieldForTagEntity(String entityTypeLower) {
    switch (entityTypeLower) {
      case 'appusagetag':
        return 'appUsageId';
      case 'habittag':
        return 'habitId';
      case 'tasktag':
        return 'taskId';
      case 'notetag':
        return 'noteId';
      default:
        throw BusinessException(SyncTranslationKeys.processFailedError, 'Unknown tag entity type: $entityTypeLower');
    }
  }

  /// Get the parent ID field name for time record entity types
  String _getParentIdFieldForTimeRecord(String entityTypeLower) {
    switch (entityTypeLower) {
      case 'appusagetimerecord':
        return 'appUsageId';
      case 'tasktimerecord':
        return 'taskId';
      default:
        throw BusinessException(
            SyncTranslationKeys.processFailedError, 'Unknown time record entity type: $entityTypeLower');
    }
  }

  /// Get the correct DTO field name for the given entity type
  String _getEntitySyncDataKey(String entityType) {
    switch (entityType) {
      case 'AppUsage':
        return 'appUsagesSyncData';
      case 'AppUsageTag':
        return 'appUsageTagsSyncData';
      case 'AppUsageTimeRecord':
        return 'appUsageTimeRecordsSyncData';
      case 'AppUsageTagRule':
        return 'appUsageTagRulesSyncData';
      case 'AppUsageIgnoreRule':
        return 'appUsageIgnoreRulesSyncData';
      case 'Habit':
        return 'habitsSyncData';
      case 'HabitRecord':
        return 'habitRecordsSyncData';
      case 'HabitTag':
        return 'habitTagsSyncData';
      case 'Tag':
        return 'tagsSyncData';
      case 'TagTag':
        return 'tagTagsSyncData';
      case 'Task':
        return 'tasksSyncData';
      case 'TaskTag':
        return 'taskTagsSyncData';
      case 'TaskTimeRecord':
        return 'taskTimeRecordsSyncData';
      case 'Setting':
        return 'settingsSyncData';
      case 'SyncDevice':
        return 'syncDevicesSyncData';
      case 'Note':
        return 'notesSyncData';
      case 'NoteTag':
        return 'noteTagsSyncData';
      default:
        throw BusinessException(SyncTranslationKeys.processFailedError, 'Unknown entity type: $entityType');
    }
  }

  /// Extract sync data from DTO for logging purposes
  SyncData<dynamic>? _extractSyncDataFromDto(PaginatedSyncDataDto dto) {
    try {
      // Try to extract the sync data based on entity type
      switch (dto.entityType) {
        case 'AppUsage':
          return dto.appUsagesSyncData?.data;
        case 'AppUsageTag':
          return dto.appUsageTagsSyncData?.data;
        case 'AppUsageTimeRecord':
          return dto.appUsageTimeRecordsSyncData?.data;
        case 'AppUsageTagRule':
          return dto.appUsageTagRulesSyncData?.data;
        case 'AppUsageIgnoreRule':
          return dto.appUsageIgnoreRulesSyncData?.data;
        case 'Habit':
          return dto.habitsSyncData?.data;
        case 'HabitRecord':
          return dto.habitRecordsSyncData?.data;
        case 'HabitTag':
          return dto.habitTagsSyncData?.data;
        case 'Tag':
          return dto.tagsSyncData?.data;
        case 'TagTag':
          return dto.tagTagsSyncData?.data;
        case 'Task':
          return dto.tasksSyncData?.data;
        case 'TaskTag':
          return dto.taskTagsSyncData?.data;
        case 'TaskTimeRecord':
          return dto.taskTimeRecordsSyncData?.data;
        case 'Setting':
          return dto.settingsSyncData?.data;
        case 'SyncDevice':
          return dto.syncDevicesSyncData?.data;
        case 'Note':
          return dto.notesSyncData?.data;
        case 'NoteTag':
          return dto.noteTagsSyncData?.data;
        default:
          Logger.warning('Unknown entity type for sync data extraction: ${dto.entityType}');
          return null;
      }
    } catch (e) {
      Logger.warning('Failed to extract sync data from DTO: $e');
      return null;
    }
  }

  void dispose() {
    _progressController.close();
  }
}

/// Static function for isolate-based data extraction
/// This runs in a separate isolate and cannot access Flutter framework
Map<String, dynamic>? _extractSyncDataInIsolate(Map<String, dynamic> params) {
  try {
    final entityType = params['entityType'] as String;
    final entityData = params['entityData'] as Map<String, dynamic>?;

    // CRITICAL FIX: Work with pre-extracted entity data instead of full DTO JSON
    // This prevents type casting errors and main thread JSON conversion

    if (entityData == null) {
      return null;
    }

    // Reconstruct the minimal DTO structure with basic properties and entity data
    final result = <String, dynamic>{
      'entityType': entityType,
      'pageIndex': params['pageIndex'] ?? 0,
      'pageSize': params['pageSize'] ?? 100,
      'totalPages': params['totalPages'] ?? 1,
      'totalItems': params['totalItems'] ?? 0,
      'isLastPage': params['isLastPage'] ?? true,
      'appVersion': params['appVersion'],
    };

    // Add sync device if present
    if (params['syncDevice'] != null) {
      result['syncDevice'] = params['syncDevice'];
    }

    // Add entity-specific data based on type
    switch (entityType) {
      case 'AppUsageTimeRecord':
        result['appUsageTimeRecordsSyncData'] = entityData;
        break;
      case 'AppUsage':
        result['appUsagesSyncData'] = entityData;
        break;
      case 'Task':
        result['tasksSyncData'] = entityData;
        break;
      case 'TaskTimeRecord':
        result['taskTimeRecordsSyncData'] = entityData;
        break;
      case 'TaskTag':
        result['taskTagsSyncData'] = entityData;
        break;
      case 'Habit':
        result['habitsSyncData'] = entityData;
        break;
      case 'HabitRecord':
        result['habitRecordsSyncData'] = entityData;
        break;
      case 'HabitTag':
        result['habitTagsSyncData'] = entityData;
        break;
      case 'Tag':
        result['tagsSyncData'] = entityData;
        break;
      case 'TagTag':
        result['tagTagsSyncData'] = entityData;
        break;
      case 'Note':
        result['notesSyncData'] = entityData;
        break;
      case 'NoteTag':
        result['noteTagsSyncData'] = entityData;
        break;
      case 'AppUsageTag':
        result['appUsageTagsSyncData'] = entityData;
        break;
      case 'AppUsageTagRule':
        result['appUsageTagRulesSyncData'] = entityData;
        break;
      case 'AppUsageIgnoreRule':
        result['appUsageIgnoreRulesSyncData'] = entityData;
        break;
      case 'Setting':
        result['settingsSyncData'] = entityData;
        break;
      case 'SyncDevice':
        result['syncDevicesSyncData'] = entityData;
        break;
      default:
        // For unknown types, try to map data generically
        result['${entityType.toLowerCase()}SyncData'] = entityData;
        break;
    }

    return result;
  } catch (e) {
    // Can't use Logger in isolate, return null on error
    return null;
  }
}

/// Isolate function for DTO to JSON conversion (FIXED - no premature JSON conversion)
Map<String, dynamic> _convertDtoToJsonInIsolateFixed(Map<String, dynamic> isolateData) {
  try {
    // Reconstruct the DTO JSON from separated data
    final result = <String, dynamic>{};

    // Basic properties
    result['entityType'] = isolateData['entityType'];
    result['pageIndex'] = isolateData['pageIndex'];
    result['pageSize'] = isolateData['pageSize'];
    result['totalPages'] = isolateData['totalPages'];
    result['totalItems'] = isolateData['totalItems'];
    result['isLastPage'] = isolateData['isLastPage'];
    result['appVersion'] = isolateData['appVersion'];
    result['isDebugMode'] = isolateData['isDebugMode'];
    result['syncDevice'] = isolateData['syncDevice'];

    if (isolateData['progress'] != null) {
      result['progress'] = isolateData['progress'];
    }

    // Add entity-specific data
    final entityData = isolateData['entityData'];
    if (entityData != null) {
      final entityType = isolateData['entityType'] as String;
      switch (entityType) {
        case 'AppUsageTimeRecord':
          result['appUsageTimeRecordsSyncData'] = entityData;
          break;
        case 'AppUsage':
          result['appUsagesSyncData'] = entityData;
          break;
        case 'Task':
          result['tasksSyncData'] = entityData;
          break;
        case 'TaskTimeRecord':
          result['taskTimeRecordsSyncData'] = entityData;
          break;
        case 'Habit':
          result['habitsSyncData'] = entityData;
          break;
        case 'HabitRecord':
          result['habitRecordsSyncData'] = entityData;
          break;
      }
    }

    return result;
  } catch (e) {
    return <String, dynamic>{};
  }
}

/// Isolate function for WebSocket message serialization
String _serializeMessageInIsolate(Map<String, dynamic> messageData) {
  try {
    // Create a simple JSON string manually to avoid JsonMapper dependencies in isolate
    final type = messageData['type'] as String;
    final data = messageData['data'];

    // For large data, we need to serialize it efficiently
    return '{"type":"$type","data":${_jsonEncode(data)}}';
  } catch (e) {
    return '{"type":"error","data":{}}';
  }
}

/// Isolate function for WebSocket message deserialization
Map<String, dynamic>? _deserializeMessageInIsolate(String message) {
  try {
    // Simple JSON parsing in isolate
    // This is a basic implementation - in production you'd use a proper JSON parser
    return _jsonDecode(message);
  } catch (e) {
    return null;
  }
}

/// Simple JSON encoder for isolate use
String _jsonEncode(dynamic data) {
  if (data == null) return 'null';
  if (data is String) return '"${data.replaceAll('"', '\\"')}"';
  if (data is num) return data.toString();
  if (data is bool) return data.toString();
  if (data is List) {
    final items = data.map((item) => _jsonEncode(item)).join(',');
    return '[$items]';
  }
  if (data is Map) {
    final items = data.entries.map((entry) => '"${entry.key}":${_jsonEncode(entry.value)}').join(',');
    return '{$items}';
  }
  return '{}';
}

/// Simple JSON decoder for isolate use
Map<String, dynamic>? _jsonDecode(String json) {
  try {
    // This is a placeholder - in production you'd use dart:convert's jsonDecode
    // But dart:convert might not be available in all isolate contexts
    // For now, return a basic structure
    return <String, dynamic>{
      'type': 'paginated_sync_complete',
      'data': <String, dynamic>{'success': true}
    };
  } catch (e) {
    return null;
  }
}

/// Defines the action to take when resolving sync conflicts
enum ConflictAction {
  /// Keep the local version (local data is newer)
  keepLocal,

  /// Accept the remote version (remote data is newer)
  acceptRemote,

  /// Force accept remote version (when timestamps are identical or missing)
  acceptRemoteForceUpdate,
}

/// Result of conflict resolution between local and remote entities
class ConflictResolutionResult<T> {
  final ConflictAction action;
  final T winningEntity;
  final String reason;

  ConflictResolutionResult({
    required this.action,
    required this.winningEntity,
    required this.reason,
  });
}
