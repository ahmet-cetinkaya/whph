import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/application/features/shared/models/websocket_request.dart';
import 'package:whph/application/features/sync/models/sync_data_dto.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/domain/features/habits/habit_record.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/features/sync/sync_device.dart';
import 'package:whph/domain/features/tags/tag.dart';
import 'package:whph/domain/features/tags/tag_tag.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/domain/features/tasks/task_tag.dart';
import 'package:whph/persistence/shared/repositories/abstraction/i_repository.dart';

class SyncCommand implements IRequest<SyncCommandResponse> {
  final SyncDataDto? syncDataDto;

  SyncCommand({this.syncDataDto});
}

@jsonSerializable
class SyncCommandResponse {
  SyncDataDto? syncDataDto;

  SyncCommandResponse({this.syncDataDto});
}

class SyncCommandHandler implements IRequestHandler<SyncCommand, SyncCommandResponse> {
  final ISyncDeviceRepository syncDeviceRepository;
  final IAppUsageRepository appUsageRepository;
  final IAppUsageTagRepository appUsageTagRepository;
  final IHabitRepository habitRepository;
  final IHabitRecordRepository habitRecordRepository;
  final ITagRepository tagRepository;
  final ITagTagRepository tagTagRepository;
  final ITaskRepository taskRepository;
  final ITaskTagRepository taskTagRepository;
  final ISettingRepository settingRepository;

  SyncCommandHandler(
      {required this.syncDeviceRepository,
      required this.appUsageRepository,
      required this.appUsageTagRepository,
      required this.habitRepository,
      required this.habitRecordRepository,
      required this.tagRepository,
      required this.tagTagRepository,
      required this.taskRepository,
      required this.taskTagRepository,
      required this.settingRepository});

  @override
  Future<SyncCommandResponse> call(SyncCommand request) async {
    PaginatedList<SyncDevice> syncDevices;
    if (request.syncDataDto != null) {
      syncDevices = PaginatedList(
          items: [request.syncDataDto!.syncDevice], totalItemCount: 1, totalPageCount: 1, pageIndex: 0, pageSize: 1);
    } else {
      syncDevices = await syncDeviceRepository.getList(0, 10);
    }

    do {
      for (SyncDevice syncDevice in syncDevices.items) {
        SyncDataDto combinedData = await _prepareSyncData(syncDevice);
        WebSocketMessage message = WebSocketMessage(type: 'sync', data: combinedData);
        String jsonData = JsonMapper.serialize(message);

        var response = SyncCommandResponse(syncDataDto: combinedData);
        if (request.syncDataDto != null) {
          await _processIncomingData(request.syncDataDto!);
          await _saveSyncDevice(syncDevice);

          return response;
        } else {
          await _sendDataToWebSocket(syncDevice.fromIp, jsonData);
          await _saveSyncDevice(syncDevice);
        }
      }

      if (request.syncDataDto == null) {
        syncDevices = await syncDeviceRepository.getList(syncDevices.pageIndex + 1, syncDevices.pageSize);
      }
    } while (syncDevices.hasNext);

    return SyncCommandResponse();
  }

  Future<SyncDataDto> _prepareSyncData(SyncDevice syncDevice) async {
    SyncData<AppUsage> syncAppUsageData =
        await appUsageRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<AppUsageTag> syncAppUsageTagData =
        await appUsageTagRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<Habit> syncHabitData =
        await habitRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<HabitRecord> syncHabitRecordData =
        await habitRecordRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<Tag> syncTagData = await tagRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<TagTag> syncTagTagData =
        await tagTagRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<Task> syncTaskData = await taskRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<TaskTag> syncTaskTagData =
        await taskTagRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<Setting> syncSettingData =
        await settingRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);
    SyncData<SyncDevice> syncSyncDeviceData =
        await syncDeviceRepository.getSyncData(syncDevice.lastSyncDate ?? syncDevice.createdDate);

    SyncDataDto combinedData = SyncDataDto(
      appUsagesSyncData: syncAppUsageData,
      appUsageTagsSyncData: syncAppUsageTagData,
      habitsSyncData: syncHabitData,
      habitRecordsSyncData: syncHabitRecordData,
      tagsSyncData: syncTagData,
      tagTagsSyncData: syncTagTagData,
      tasksSyncData: syncTaskData,
      taskTagsSyncData: syncTaskTagData,
      settingsSyncData: syncSettingData,
      syncDevicesSyncData: syncSyncDeviceData,
      syncDevice: syncDevice,
    );
    return combinedData;
  }

  Future<void> _saveSyncDevice(SyncDevice sync) async {
    sync.lastSyncDate = DateTime.now();
    await syncDeviceRepository.update(sync);
  }

  Future<void> _sendDataToWebSocket(String ipAddress, String jsonData) async {
    const int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      WebSocket? socket;
      try {
        if (kDebugMode) print('Attempting to connect to WebSocket at ws://$ipAddress:4040 (Attempt ${attempt + 1})');

        // Connect to WebSocket
        socket = await WebSocket.connect('ws://$ipAddress:4040');

        if (kDebugMode) print('Connected to WebSocket at ws://$ipAddress:4040');

        // Send data to WebSocket
        socket.add(jsonData);
        if (kDebugMode) print('Data sent to WebSocket: $jsonData');

        // Listen for a single response from WebSocket
        await for (var message in socket) {
          if (kDebugMode) print('Received message from WebSocket: $message');
          WebSocketMessage? parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
          var parsedData = SyncDataDto.fromJson(parsedMessage!.data['syncDataDto']);
          _processIncomingData(parsedData);
          break;
        }

        socket.close();
        break;
      } catch (e) {
        if (kDebugMode) print('Error during WebSocket communication: $e');

        attempt++;
        if (attempt >= maxRetries) {
          throw BusinessException('Max retries reached. Giving up. Error: $e');
        }

        await Future.delayed(Duration(seconds: 5));
      } finally {
        socket?.close();
      }
    }
  }

  //#region Process incoming data

  Future<void> _processIncomingData(SyncDataDto syncDataDto) async {
    await _processSyncData<AppUsage, String>(
      syncDataDto.appUsagesSyncData,
      appUsageRepository.getById,
      appUsageRepository.add,
      (existingAppUsage, appUsage) => existingAppUsage.mapFromInstance(appUsage),
      appUsageRepository.update,
      appUsageRepository.delete,
    );
    await _processSyncData<AppUsageTag, String>(
      syncDataDto.appUsageTagsSyncData,
      appUsageTagRepository.getById,
      appUsageTagRepository.add,
      (existingAppUsageTag, appUsageTag) => existingAppUsageTag.mapFromInstance(appUsageTag),
      appUsageTagRepository.update,
      appUsageTagRepository.delete,
    );
    await _processSyncData<Habit, String>(
      syncDataDto.habitsSyncData,
      habitRepository.getById,
      habitRepository.add,
      (existingHabit, habit) => existingHabit.mapFromInstance(habit),
      habitRepository.update,
      habitRepository.delete,
    );
    await _processSyncData<HabitRecord, String>(
      syncDataDto.habitRecordsSyncData,
      habitRecordRepository.getById,
      habitRecordRepository.add,
      (existingHabitRecord, habitRecord) => existingHabitRecord.mapFromInstance(habitRecord),
      habitRecordRepository.update,
      habitRecordRepository.delete,
    );
    await _processSyncData<Tag, String>(
      syncDataDto.tagsSyncData,
      tagRepository.getById,
      tagRepository.add,
      (existingTag, tag) => existingTag.mapFromInstance(tag),
      tagRepository.update,
      tagRepository.delete,
    );
    await _processSyncData<TagTag, String>(
      syncDataDto.tagTagsSyncData,
      tagTagRepository.getById,
      tagTagRepository.add,
      (existingTagTag, tagTag) => existingTagTag.mapFromInstance(tagTag),
      tagTagRepository.update,
      tagTagRepository.delete,
    );
    await _processSyncData<Task, String>(
      syncDataDto.tasksSyncData,
      taskRepository.getById,
      taskRepository.add,
      (existingTask, task) => existingTask.mapFromInstance(task),
      taskRepository.update,
      taskRepository.delete,
    );
    await _processSyncData<TaskTag, String>(
      syncDataDto.taskTagsSyncData,
      taskTagRepository.getById,
      taskTagRepository.add,
      (existingTaskTag, taskTag) => existingTaskTag.mapFromInstance(taskTag),
      taskTagRepository.update,
      taskTagRepository.delete,
    );
    await _processSyncData<Setting, String>(
      syncDataDto.settingsSyncData,
      settingRepository.getById,
      settingRepository.add,
      (existingSetting, setting) => existingSetting.mapFromInstance(setting),
      settingRepository.update,
      settingRepository.delete,
    );
    await _processSyncData<SyncDevice, String>(
        syncDataDto.syncDevicesSyncData,
        syncDeviceRepository.getById,
        syncDeviceRepository.add,
        (existingSyncDevice, syncDevice) => existingSyncDevice.mapFromInstance(syncDevice),
        syncDeviceRepository.update,
        syncDeviceRepository.delete);
  }

  Future<void> _processSyncData<T extends BaseEntity<TId>, TId>(
    SyncData<T> syncData,
    Future<T?> Function(TId) getByIdFunction,
    Future<void> Function(T) addFunction,
    void Function(T, T) mapFunction,
    Future<void> Function(T) updateFunction,
    Future<void> Function(T) deleteFunction,
  ) async {
    for (T item in syncData.createSync) {
      await addFunction(item);
    }

    for (T item in syncData.updateSync) {
      T? existingItem = await getByIdFunction(item.id);
      if (existingItem == null) throw BusinessException('${T.toString()} with id ${item.id} not found');
      mapFunction(existingItem, item);
      await updateFunction(item);
    }

    for (T item in syncData.deleteSync) {
      T? existingItem = await getByIdFunction(item.id);
      if (existingItem == null) throw BusinessException('${T.toString()} with id ${item.id} not found');
      await deleteFunction(item);
    }
  }

  //#endregion Process incoming data
}
