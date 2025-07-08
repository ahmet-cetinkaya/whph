import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/src/core/application/features/sync/models/sync_data.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/presentation/ui/shared/utils/network_utils.dart';
import 'package:whph/src/core/application/shared/models/websocket_request.dart';
import 'package:whph/src/core/application/features/sync/models/sync_data_dto.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:acore/acore.dart' hide IRepository;
import 'package:whph/src/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_ignore_rule.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/src/core/domain/features/app_usages/app_usage_tag_rule.dart';
import 'package:whph/src/core/domain/features/habits/habit.dart';
import 'package:whph/src/core/domain/features/habits/habit_record.dart';
import 'package:whph/src/core/domain/features/habits/habit_tag.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/core/domain/features/sync/sync_device.dart';
import 'package:whph/src/core/domain/features/tags/tag.dart';
import 'package:whph/src/core/domain/features/tags/tag_tag.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/core/domain/features/tasks/task_tag.dart';
import 'package:whph/src/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/src/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/src/core/application/features/sync/constants/sync_translation_keys.dart';
import 'package:whph/src/core/domain/features/notes/note.dart';
import 'package:whph/src/core/domain/features/notes/note_tag.dart';

class SyncCommand implements IRequest<SyncCommandResponse> {
  final SyncDataDto? syncDataDto;

  SyncCommand({this.syncDataDto});
}

@jsonSerializable
class SyncCommandResponse {
  SyncDataDto? syncDataDto;

  SyncCommandResponse({this.syncDataDto});
}

class SyncConfig<T extends BaseEntity<String>> {
  final String name;
  final IRepository<T, String> repository;
  final Future<SyncData<T>> Function(DateTime) getSyncData;
  final SyncData<T>? Function(SyncDataDto) getSyncDataFromDto;

  SyncConfig({
    required this.name,
    required this.repository,
    required this.getSyncData,
    required this.getSyncDataFromDto,
  });
}

class SyncCommandHandler implements IRequestHandler<SyncCommand, SyncCommandResponse> {
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

  late final List<SyncConfig> _syncConfigs;

  SyncCommandHandler({
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
      SyncConfig<AppUsage>(
        name: 'AppUsage',
        repository: appUsageRepository,
        getSyncData: appUsageRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.appUsagesSyncData,
      ),
      SyncConfig<AppUsageTag>(
        name: 'AppUsageTag',
        repository: appUsageTagRepository,
        getSyncData: appUsageTagRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.appUsageTagsSyncData,
      ),
      SyncConfig<AppUsageTimeRecord>(
        name: 'AppUsageTimeRecord',
        repository: appUsageTimeRecordRepository,
        getSyncData: appUsageTimeRecordRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.appUsageTimeRecordsSyncData,
      ),
      SyncConfig<AppUsageTagRule>(
        name: 'AppUsageTagRule',
        repository: appUsageTagRuleRepository,
        getSyncData: appUsageTagRuleRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.appUsageTagRulesSyncData,
      ),
      SyncConfig<Habit>(
        name: 'Habit',
        repository: habitRepository,
        getSyncData: habitRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.habitsSyncData,
      ),
      SyncConfig<HabitRecord>(
        name: 'HabitRecord',
        repository: habitRecordRepository,
        getSyncData: habitRecordRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.habitRecordsSyncData,
      ),
      SyncConfig<HabitTag>(
        name: 'HabitTag',
        repository: habitTagRepository,
        getSyncData: habitTagRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.habitTagsSyncData,
      ),
      SyncConfig<Tag>(
        name: 'Tag',
        repository: tagRepository,
        getSyncData: tagRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.tagsSyncData,
      ),
      SyncConfig<TagTag>(
        name: 'TagTag',
        repository: tagTagRepository,
        getSyncData: tagTagRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.tagTagsSyncData,
      ),
      SyncConfig<Task>(
        name: 'Task',
        repository: taskRepository,
        getSyncData: taskRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.tasksSyncData,
      ),
      SyncConfig<TaskTag>(
        name: 'TaskTag',
        repository: taskTagRepository,
        getSyncData: taskTagRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.taskTagsSyncData,
      ),
      SyncConfig<TaskTimeRecord>(
        name: 'TaskTimeRecord',
        repository: taskTimeRecordRepository,
        getSyncData: taskTimeRecordRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.taskTimeRecordsSyncData,
      ),
      SyncConfig<Setting>(
        name: 'Setting',
        repository: settingRepository,
        getSyncData: settingRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.settingsSyncData,
      ),
      SyncConfig<SyncDevice>(
        name: 'SyncDevice',
        repository: syncDeviceRepository,
        getSyncData: syncDeviceRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.syncDevicesSyncData,
      ),
      SyncConfig<Note>(
        name: 'Note',
        repository: noteRepository,
        getSyncData: noteRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.notesSyncData,
      ),
      SyncConfig<NoteTag>(
        name: 'NoteTag',
        repository: noteTagRepository,
        getSyncData: noteTagRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.noteTagsSyncData,
      ),
      SyncConfig<AppUsageIgnoreRule>(
        name: 'AppUsageIgnoreRule',
        repository: appUsageIgnoreRuleRepository,
        getSyncData: appUsageIgnoreRuleRepository.getSyncData,
        getSyncDataFromDto: (dto) => dto.appUsageIgnoreRulesSyncData,
      ),
    ];
  }

  @override
  Future<SyncCommandResponse> call(SyncCommand request) async {
    Logger.info('🚀 Starting sync operation');

    if (request.syncDataDto != null) {
      Logger.info('📨 Processing incoming sync data from remote device');
      await _checkVersion(request.syncDataDto!.appVersion);
      await _validateDeviceId(request.syncDataDto!.syncDevice);
    }

    List<SyncDevice> syncDevices;
    if (request.syncDataDto != null) {
      // Incoming sync data - process it (all platforms can receive)
      syncDevices = [request.syncDataDto!.syncDevice];
    } else {
      // Outgoing sync initiation - only Android can initiate
      if (!PlatformUtils.isMobile) {
        Logger.info('🖥️ Desktop platform detected - sync initiation disabled (passive mode only)');
        Logger.info('📱 Only Android devices can initiate sync operations');
        return SyncCommandResponse();
      }

      Logger.info('📱 Android platform detected - proceeding with sync initiation');

      // When initiating sync, find devices where this device participates and sync with the remote counterpart
      final localDeviceId = await deviceIdService.getDeviceId();
      final localIP = await NetworkUtils.getLocalIpAddress();
      final allDevices = await syncDeviceRepository.getAll();

      Logger.debug('🔍 Local device details - ID: $localDeviceId, IP: $localIP');
      Logger.debug('📋 All sync devices found: ${allDevices.length}');

      for (final device in allDevices) {
        Logger.debug(
            '   Device ${device.id}: From ${device.fromIp}:${device.fromDeviceId} → To ${device.toIp}:${device.toDeviceId}');
      }

      // Filter to include devices where this device is either fromDeviceId OR toDeviceId
      // This allows any device to initiate sync with its counterpart
      syncDevices = allDevices
          .where((device) => device.fromDeviceId == localDeviceId || device.toDeviceId == localDeviceId)
          .toList();

      Logger.info(
          '📱 Found ${allDevices.length} total sync devices, filtering to ${syncDevices.length} devices where this device participates');

      if (syncDevices.isEmpty) {
        Logger.info(
            '🔍 No remote devices found to sync with - this device is not configured for any sync relationships');
        return SyncCommandResponse();
      }

      for (final device in syncDevices) {
        final isFromDevice = device.fromDeviceId == localDeviceId;
        final remoteIp = isFromDevice ? device.toIp : device.fromIp;
        final remoteDeviceId = isFromDevice ? device.toDeviceId : device.fromDeviceId;
        Logger.debug('✅ Will sync with device ${device.id}: Remote IP $remoteIp, Remote Device ID $remoteDeviceId');
      }
    }

    bool allDevicesSynced = true;
    DateTime? oldestLastSyncDate;

    for (SyncDevice syncDevice in syncDevices) {
      try {
        Logger.info('🔄 Processing sync with device: ${syncDevice.id}');

        SyncDataDto combinedData = await _prepareSyncData(syncDevice);
        WebSocketMessage message = WebSocketMessage(type: 'sync', data: combinedData);
        String jsonData = JsonMapper.serialize(message);

        if (request.syncDataDto != null) {
          // Mobile/receiving device: Process incoming sync data and send back response
          Logger.info('⬇️ Processing incoming sync data from remote device');

          // Store original lastSyncDate before processing incoming data
          final originalLastSyncDate = request.syncDataDto!.syncDevice.lastSyncDate;
          Logger.debug('📅 Storing original lastSyncDate for response preparation: $originalLastSyncDate');

          bool syncSuccess = await _processIncomingData(request.syncDataDto!);
          if (syncSuccess) {
            Logger.info('📊 Incoming data processed successfully, preparing response with local changes');

            // Create a fresh SyncDevice object for response preparation
            // Simply swap the from/to relationships to create the return path
            final localSyncDevice = SyncDevice(
              id: request.syncDataDto!.syncDevice.id, // Use the same sync device ID
              fromIp: request.syncDataDto!.syncDevice.toIp, // Swap IPs for response
              toIp: request.syncDataDto!.syncDevice.fromIp,
              fromDeviceId: request.syncDataDto!.syncDevice.toDeviceId, // Swap device IDs for response
              toDeviceId: request.syncDataDto!.syncDevice.fromDeviceId,
              name: request.syncDataDto!.syncDevice.name,
              lastSyncDate: originalLastSyncDate, // Use original date to include local changes
              createdDate: request.syncDataDto!.syncDevice.createdDate,
            );

            Logger.debug('🔄 Preparing response data using swapped sync device for return path');
            Logger.debug(
                '📱 Response sync device - From: ${localSyncDevice.fromIp}:${localSyncDevice.fromDeviceId} To: ${localSyncDevice.toIp}:${localSyncDevice.toDeviceId}');

            final responseData = await _prepareSyncData(localSyncDevice);

            // Now update the sync device timestamp after preparing response
            await _saveSyncDevice(request.syncDataDto!.syncDevice);

            Logger.info('✅ Successfully processed incoming sync data, sending response data back');
            return SyncCommandResponse(syncDataDto: responseData);
          }
          throw BusinessException('Failed to process sync data', SyncTranslationKeys.processFailedError);
        } else {
          // Initiating device: Send sync data to the counterpart device
          try {
            Logger.info('⬆️ Sending sync data to device ${syncDevice.id}');

            // Determine the target IP based on which device this is in the sync relationship
            final localDeviceId = await deviceIdService.getDeviceId();
            final isFromDevice = syncDevice.fromDeviceId == localDeviceId;
            final targetIp = isFromDevice ? syncDevice.toIp : syncDevice.fromIp;
            final remoteDeviceId = isFromDevice ? syncDevice.toDeviceId : syncDevice.fromDeviceId;

            Logger.debug('🎯 Targeting IP: $targetIp (local device $localDeviceId → remote device $remoteDeviceId)');

            // Test connectivity before sending data
            Logger.debug('🔍 Testing connectivity to $targetIp...');
            final portTest = await NetworkUtils.testPortConnectivity(targetIp);
            Logger.debug('📡 Port connectivity test result: ${portTest ? 'SUCCESS' : 'FAILED'}');

            if (!portTest) {
              Logger.warning('⚠️ Port connectivity test failed for $targetIp:44040. Proceeding anyway...');
            }

            await _sendDataToWebSocket(targetIp, jsonData);
            await _saveSyncDevice(syncDevice);
            Logger.info('✅ Successfully completed bidirectional sync with device ${syncDevice.id}');

            oldestLastSyncDate = oldestLastSyncDate == null
                ? syncDevice.lastSyncDate
                : (syncDevice.lastSyncDate!.isBefore(oldestLastSyncDate)
                    ? syncDevice.lastSyncDate
                    : oldestLastSyncDate);
          } catch (e) {
            Logger.error('Failed to sync with device ${syncDevice.id}: $e');
            allDevicesSynced = false;
            continue; // Continue with next device even if this one fails
          }
        }
      } catch (e) {
        Logger.error('Failed to sync with device ${syncDevice.id}: $e');
        allDevicesSynced = false;
      }
    }

    if (allDevicesSynced && oldestLastSyncDate != null) {
      Logger.info('🧹 Cleaning up soft-deleted data older than: $oldestLastSyncDate');
      await _cleanupSoftDeletedData(oldestLastSyncDate);
    }

    Logger.info('🏁 Sync operation completed successfully');
    return SyncCommandResponse();
  }

  Future<SyncDataDto> _prepareSyncData(SyncDevice syncDevice) async {
    // For initial sync (when lastSyncDate is null), use a very old date to get all records
    // For subsequent syncs, use the actual lastSyncDate
    final DateTime lastSyncDate;
    if (syncDevice.lastSyncDate == null) {
      // Use a date far in the past for initial sync to get all existing data
      lastSyncDate = DateTime(1900, 1, 1);
      Logger.debug('🆕 Initial sync detected - using very old date to get all data');
    } else {
      lastSyncDate = syncDevice.lastSyncDate!;
      Logger.debug('🔄 Incremental sync - using lastSyncDate: $lastSyncDate');
    }

    Logger.debug('🔄 Preparing sync data for device: ${syncDevice.id}');
    Logger.debug('📅 Using effective lastSyncDate: $lastSyncDate');
    Logger.debug('📊 Total sync configs: ${_syncConfigs.length}');

    final syncDataResults = await Future.wait(_syncConfigs.map((config) => config.getSyncData(lastSyncDate)));

    for (int i = 0; i < _syncConfigs.length; i++) {
      final config = _syncConfigs[i];
      final result = syncDataResults[i];

      Logger.debug(
          '📋 ${config.name}: createSync=${result.createSync.length}, updateSync=${result.updateSync.length}, deleteSync=${result.deleteSync.length}');
    }

    final dto = SyncDataDto(
      appVersion: AppInfo.version,
      syncDevice: syncDevice,
      appUsagesSyncData: syncDataResults[0] as SyncData<AppUsage>,
      appUsageTagsSyncData: syncDataResults[1] as SyncData<AppUsageTag>,
      appUsageTimeRecordsSyncData: syncDataResults[2] as SyncData<AppUsageTimeRecord>,
      appUsageTagRulesSyncData: syncDataResults[3] as SyncData<AppUsageTagRule>,
      habitsSyncData: syncDataResults[4] as SyncData<Habit>,
      habitRecordsSyncData: syncDataResults[5] as SyncData<HabitRecord>,
      habitTagsSyncData: syncDataResults[6] as SyncData<HabitTag>,
      tagsSyncData: syncDataResults[7] as SyncData<Tag>,
      tagTagsSyncData: syncDataResults[8] as SyncData<TagTag>,
      tasksSyncData: syncDataResults[9] as SyncData<Task>,
      taskTagsSyncData: syncDataResults[10] as SyncData<TaskTag>,
      taskTimeRecordsSyncData: syncDataResults[11] as SyncData<TaskTimeRecord>,
      settingsSyncData: syncDataResults[12] as SyncData<Setting>,
      syncDevicesSyncData: syncDataResults[13] as SyncData<SyncDevice>,
      notesSyncData: syncDataResults[14] as SyncData<Note>,
      noteTagsSyncData: syncDataResults[15] as SyncData<NoteTag>,
      appUsageIgnoreRulesSyncData: syncDataResults[16] as SyncData<AppUsageIgnoreRule>,
    );

    return dto;
  }

  Future<void> _saveSyncDevice(SyncDevice syncDevice) async {
    final DateTime now = DateTime.now().toUtc();
    final DateTime? previousSyncDate = syncDevice.lastSyncDate;

    syncDevice.lastSyncDate = now;
    await syncDeviceRepository.update(syncDevice);

    Logger.debug('💾 Updated sync device ${syncDevice.id}: lastSyncDate changed from $previousSyncDate to $now');
  }

  Future<void> _sendDataToWebSocket(String ipAddress, String jsonData) async {
    const int maxRetries = 3;
    const int baseTimeout = 10;
    int attempt = 0;

    while (attempt < maxRetries) {
      WebSocket? socket;
      try {
        socket =
            await WebSocket.connect('ws://$ipAddress:44040').timeout(Duration(seconds: baseTimeout * (attempt + 1)));

        // Create a completer to handle sync completion
        final syncCompleter = Completer<bool>();
        Timer? timeoutTimer;

        // Set up timeout
        timeoutTimer = Timer(Duration(seconds: baseTimeout * (attempt + 1)), () {
          if (!syncCompleter.isCompleted) {
            syncCompleter.complete(false);
            socket?.close();
          }
        });

        // Send our data first
        socket.add(jsonData);

        // Listen to responses
        await for (final message in socket) {
          try {
            final receivedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
            if (receivedMessage?.type == 'sync_complete') {
              timeoutTimer.cancel();

              if (receivedMessage?.data != null) {
                final messageData = receivedMessage!.data as Map<String, dynamic>;
                bool? success = messageData['success'] as bool?;

                if (success == true) {
                  if (messageData['syncDataDto'] != null) {
                    final syncDataDtoJson = messageData['syncDataDto'] as Map<String, dynamic>;
                    final parsedData = SyncDataDto.fromJson(syncDataDtoJson);
                    await _processIncomingData(parsedData);
                  }
                  syncCompleter.complete(true);
                  break; // Exit the stream after successful sync
                }
              }
              syncCompleter.complete(false);
              break;
            } else if (receivedMessage?.type == 'sync_error') {
              timeoutTimer.cancel();
              final messageData = receivedMessage!.data as Map<String, dynamic>;
              String? errorMessage = messageData['message'] as String?;

              if (errorMessage == SyncTranslationKeys.deviceMismatchError) {
                Logger.warning('Device ID mismatch received from server');
                return; // Exit immediately without retrying for device mismatch
              }

              syncCompleter.complete(false);
              break;
            }
          } catch (e) {
            Logger.error('Error processing message: $e');
            syncCompleter.complete(false);
            break;
          }
        }

        // Wait for sync completion or timeout
        bool syncSuccess = await syncCompleter.future;

        // Ensure socket is closed
        await socket.close();

        if (syncSuccess) {
          return;
        } else {
          throw BusinessException('Sync failed', SyncTranslationKeys.syncFailedError);
        }
      } catch (e) {
        Logger.error('Error during WebSocket communication (Attempt ${attempt + 1}): $e');

        // For device mismatch errors, just return without retrying
        if (e is BusinessException && e.errorCode == SyncTranslationKeys.deviceMismatchError) {
          Logger.warning('Device ID mismatch, skipping this device');
          return;
        }

        attempt++;
        if (attempt >= maxRetries) {
          throw BusinessException('Sync failed after retries', SyncTranslationKeys.syncFailedError);
        }

        await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
      } finally {
        await socket?.close();
      }
    }
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

  Future<void> _validateDeviceId(SyncDevice remoteDevice) async {
    final localDeviceIP = await NetworkUtils.getLocalIpAddress();
    final localDeviceID = await deviceIdService.getDeviceId();

    if (remoteDevice.fromIp == localDeviceIP && remoteDevice.fromDeviceId == localDeviceID ||
        remoteDevice.toIp == localDeviceIP && remoteDevice.toDeviceId == localDeviceID) {
      return;
    }

    throw BusinessException('Device ID mismatch', SyncTranslationKeys.deviceMismatchError);
  }

  Future<bool> _processIncomingData(SyncDataDto syncDataDto) async {
    try {
      Logger.info('📥 Processing incoming sync data with ${_syncConfigs.length} entity types');

      int totalProcessed = 0;
      int totalConflictsResolved = 0;

      // Process each entity type sequentially to maintain consistency and ensure proper persistence
      for (int i = 0; i < _syncConfigs.length; i++) {
        final config = _syncConfigs[i];
        final syncData = config.getSyncDataFromDto(syncDataDto);

        if (syncData != null) {
          final itemCount = syncData.createSync.length + syncData.updateSync.length + syncData.deleteSync.length;

          if (itemCount > 0) {
            Logger.debug(
                '🔧 Processing ${config.name}: ${syncData.createSync.length} creates, ${syncData.updateSync.length} updates, ${syncData.deleteSync.length} deletes');

            final conflictCount = await _processSyncDataBatch(syncData, config.repository);
            totalProcessed += itemCount;
            totalConflictsResolved += conflictCount;

            Logger.debug('✅ Completed processing ${config.name}: $itemCount items, $conflictCount conflicts resolved');
          } else {
            Logger.debug('⏭️ Skipping ${config.name}: no changes to process');
          }
        } else {
          Logger.debug('⏭️ Skipping ${config.name}: no sync data available');
        }
      }

      Logger.info('✅ Successfully processed $totalProcessed items with $totalConflictsResolved conflicts resolved');
      return true;
    } catch (e) {
      Logger.error('❌ Error processing incoming data: $e');
      return false;
    }
  }

  Future<int> _processSyncDataBatch<T extends BaseEntity<String>>(
      SyncData<T> syncData, IRepository<T, String> repository) async {
    try {
      const batchSize = 100;
      int conflictsResolved = 0;

      // Process creates and updates with conflict resolution
      final upsertItems = [...syncData.createSync, ...syncData.updateSync];

      if (upsertItems.isNotEmpty) {
        for (var i = 0; i < upsertItems.length; i += batchSize) {
          final end = (i + batchSize < upsertItems.length) ? i + batchSize : upsertItems.length;
          for (final item in upsertItems.sublist(i, end)) {
            try {
              // Get the existing item for conflict detection
              T? existingItem = await repository.getById(item.id);

              if (existingItem == null) {
                // Item doesn't exist locally, add it
                Logger.debug('🆕 Adding new item ${item.id} (${T.toString()})');
                await repository.add(item);
              } else {
                // Check if local item is soft-deleted but remote item is not
                if (existingItem.isDeleted && !item.isDeleted) {
                  Logger.debug(
                      '🔄 Local item ${item.id} is deleted but remote is not - checking timestamps for resurrection');
                  final ConflictResolutionResult<T> resolution = _resolveConflict(existingItem, item);
                  conflictsResolved++;

                  if (resolution.action == ConflictAction.acceptRemote ||
                      resolution.action == ConflictAction.acceptRemoteForceUpdate) {
                    Logger.debug('♻️ Resurrecting deleted item ${item.id} (${T.toString()}) with remote version');
                    await repository.update(item);
                  } else {
                    Logger.debug(
                        '🗑️ Keeping local deleted state for ${item.id} (${T.toString()}) - local deletion is newer');
                  }
                } else if (!existingItem.isDeleted && item.isDeleted) {
                  Logger.debug(
                      '🗑️ Remote item ${item.id} is deleted but local is not - checking timestamps for deletion');
                  final ConflictResolutionResult<T> resolution = _resolveConflict(existingItem, item);
                  conflictsResolved++;

                  if (resolution.action == ConflictAction.acceptRemote ||
                      resolution.action == ConflictAction.acceptRemoteForceUpdate) {
                    Logger.debug('🗑️ Accepting deletion of ${item.id} (${T.toString()}) from remote');
                    await repository.update(item);
                  } else {
                    Logger.debug(
                        '📄 Keeping local non-deleted state for ${item.id} (${T.toString()}) - local modification is newer');
                  }
                } else {
                  // Standard conflict resolution for active items
                  final ConflictResolutionResult<T> resolution = _resolveConflict(existingItem, item);
                  conflictsResolved++; // Count any conflict resolution

                  switch (resolution.action) {
                    case ConflictAction.keepLocal:
                      Logger.debug(
                          '⬅️ Conflict resolved: keeping local version of ${item.id} (${T.toString()}) - local is newer');
                      // Do nothing - keep the local version
                      break;

                    case ConflictAction.acceptRemote:
                      Logger.debug(
                          '➡️ Conflict resolved: accepting remote version of ${item.id} (${T.toString()}) - remote is newer');
                      await repository.update(item);
                      break;

                    case ConflictAction.acceptRemoteForceUpdate:
                      Logger.debug(
                          '🔄 Accepting remote version of ${item.id} (${T.toString()}) - timestamps identical or missing');
                      await repository.update(item);
                      break;
                  }
                }
              }
            } catch (e) {
              Logger.error('Error processing item ${item.id}: $e');
              rethrow;
            }
          }
        }
      }

      // Process deletes separately
      if (syncData.deleteSync.isNotEmpty) {
        await _processBatchOperation(
          syncData.deleteSync,
          (item) => repository.delete(item),
          batchSize,
        );
      }

      return conflictsResolved;
    } catch (e) {
      Logger.error('Error processing batch for ${T.toString()}: $e');
      rethrow;
    }
  }

  Future<void> _processBatchOperation<T>(
    List<T> items,
    Future<void> Function(T) operation,
    int batchSize,
  ) async {
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      try {
        // Process items sequentially in each batch to maintain order
        for (final item in items.sublist(i, end)) {
          await operation(item);
        }
      } catch (e) {
        Logger.error('Error processing batch ${i ~/ batchSize + 1}: $e');
        rethrow;
      }
    }
  }

  Future<void> _cleanupSoftDeletedData(DateTime oldestLastSyncDate) async {
    Logger.debug(' Cleaning up soft deleted data older than: $oldestLastSyncDate');

    await Future.wait(
        _syncConfigs.map((config) => config.repository.hardDeleteSoftDeleted(oldestLastSyncDate)).toList());
  }

  /// Resolves conflicts between local and remote entities using timestamp-based conflict resolution
  ConflictResolutionResult<T> _resolveConflict<T extends BaseEntity<String>>(T localEntity, T remoteEntity) {
    // Get effective timestamps for comparison (modifiedDate or createdDate as fallback)
    final DateTime localTimestamp = _getEffectiveTimestamp(localEntity);
    final DateTime remoteTimestamp = _getEffectiveTimestamp(remoteEntity);

    // Compare timestamps to determine which version is newer
    if (localTimestamp.isAfter(remoteTimestamp)) {
      // Local entity is newer
      return ConflictResolutionResult(
        action: ConflictAction.keepLocal,
        winningEntity: localEntity,
        reason: 'Local timestamp ($localTimestamp) is newer than remote ($remoteTimestamp)',
      );
    } else if (remoteTimestamp.isAfter(localTimestamp)) {
      // Remote entity is newer
      return ConflictResolutionResult(
        action: ConflictAction.acceptRemote,
        winningEntity: remoteEntity,
        reason: 'Remote timestamp ($remoteTimestamp) is newer than local ($localTimestamp)',
      );
    } else {
      // Timestamps are identical - prefer remote version for consistency
      return ConflictResolutionResult(
        action: ConflictAction.acceptRemoteForceUpdate,
        winningEntity: remoteEntity,
        reason: 'Timestamps are identical ($localTimestamp), preferring remote version for consistency',
      );
    }
  }

  /// Gets the effective timestamp for conflict resolution
  /// Uses modifiedDate if available, otherwise falls back to createdDate
  DateTime _getEffectiveTimestamp<T extends BaseEntity<String>>(T entity) {
    return entity.modifiedDate ?? entity.createdDate;
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
