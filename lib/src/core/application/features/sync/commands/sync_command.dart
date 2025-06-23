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
import 'package:whph/src/presentation/ui/shared/utils/network_utils.dart';
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
    if (request.syncDataDto != null) {
      await _checkVersion(request.syncDataDto!.appVersion);
      await _validateDeviceId(request.syncDataDto!.syncDevice);
    }

    List<SyncDevice> syncDevices;
    if (request.syncDataDto != null) {
      syncDevices = [request.syncDataDto!.syncDevice];
    } else {
      syncDevices = await syncDeviceRepository.getAll();
    }

    bool allDevicesSynced = true;
    DateTime? oldestLastSyncDate;

    for (SyncDevice syncDevice in syncDevices) {
      try {
        SyncDataDto combinedData = await _prepareSyncData(syncDevice);
        WebSocketMessage message = WebSocketMessage(type: 'sync', data: combinedData);
        String jsonData = JsonMapper.serialize(message);

        final response = SyncCommandResponse(syncDataDto: combinedData);
        if (request.syncDataDto != null) {
          bool syncSuccess = await _processIncomingData(request.syncDataDto!);
          if (syncSuccess) {
            await _saveSyncDevice(request.syncDataDto!.syncDevice);
            return response;
          }
          throw BusinessException('Failed to process sync data', SyncTranslationKeys.processFailedError);
        } else {
          try {
            await _sendDataToWebSocket(syncDevice.fromIp, jsonData);
            await _saveSyncDevice(syncDevice);

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
      await _cleanupSoftDeletedData(oldestLastSyncDate);
    }

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

  Future<void> _saveSyncDevice(SyncDevice sync) async {
    sync.lastSyncDate = DateTime.now().toUtc();
    await syncDeviceRepository.update(sync);
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
      await Future.wait(_syncConfigs.map((config) {
        final syncData = config.getSyncDataFromDto(syncDataDto);
        if (syncData != null) {
          return _processSyncDataBatch(syncData, config.repository);
        }
        return Future.value(); // Skip if no sync data
      }));
      return true;
    } catch (e) {
      Logger.error('Error processing incoming data: $e');
      return false;
    }
  }

  Future<void> _processSyncDataBatch<T extends BaseEntity<String>>(
      SyncData<T> syncData, IRepository<T, String> repository) async {
    try {
      const batchSize = 100;

      // Process creates and updates together
      final upsertItems = [...syncData.createSync, ...syncData.updateSync];

      if (upsertItems.isNotEmpty) {
        await _processBatchOperation(
          upsertItems,
          (item) async {
            try {
              // First try to get the existing item
              T? existingItem = await repository.getById(item.id);
              if (existingItem != null) {
                // If item exists, update it
                await repository.update(item);
              } else {
                // If item doesn't exist, add it
                await repository.add(item);
              }
            } catch (e) {
              Logger.error('Error processing item ${item.id}: $e');
              rethrow;
            }
          },
          batchSize,
        );
      }

      // Process deletes separately
      if (syncData.deleteSync.isNotEmpty) {
        await _processBatchOperation(
          syncData.deleteSync,
          (item) => repository.delete(item),
          batchSize,
        );
      }
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
}
