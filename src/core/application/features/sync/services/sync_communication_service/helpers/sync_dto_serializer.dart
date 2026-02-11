import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:domain/shared/utils/logger.dart';

/// Handles DTO-to-JSON conversion for sync operations with isolate support
class SyncDtoSerializer {
  /// Converts a PaginatedSyncDataDto to JSON format with proper yielding for UI responsiveness
  Future<Map<String, dynamic>> convertDtoToJson(PaginatedSyncDataDto dto) async {
    try {
      final totalItems = _estimateDataSize(dto);

      if (totalItems > 100) {
        DomainLogger.debug('Using isolate for DTO to JSON conversion ($totalItems items)');
        try {
          final isolateData = _prepareIsolateData(dto);
          return await compute(_convertDtoToJsonInIsolate, isolateData);
        } catch (e) {
          DomainLogger.warning('Isolate conversion failed, using main thread with chunking: $e');
          return await _convertDtoToJsonWithChunking(dto);
        }
      } else {
        return await _convertDtoToJsonWithChunking(dto);
      }
    } catch (e, stackTrace) {
      DomainLogger.error('DTO to JSON conversion failed', error: e, stackTrace: stackTrace);

      if (dto.entityType == 'Task' || dto.tasksSyncData != null) {
        DomainLogger.error('CRITICAL: Task DTO conversion failed - this is the root cause!');
      }

      rethrow;
    }
  }

  /// Estimates total data size for choosing processing strategy
  int _estimateDataSize(PaginatedSyncDataDto dto) {
    int total = 0;
    total += dto.appUsagesSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.habitsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.tasksSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.appUsageTagsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.appUsageTimeRecordsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.appUsageTagRulesSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.appUsageIgnoreRulesSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.habitRecordsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.habitTagsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.tagsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.tagTagsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.taskTagsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.taskTimeRecordsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.settingsSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.syncDevicesSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.notesSyncData?.data.getTotalItemCount() ?? 0;
    total += dto.noteTagsSyncData?.data.getTotalItemCount() ?? 0;
    return total;
  }

  /// Prepares isolate data by pre-serializing complex objects
  Map<String, dynamic> _prepareIsolateData(PaginatedSyncDataDto dto) {
    final isolateData = <String, dynamic>{
      'entityType': dto.entityType,
      'pageIndex': dto.pageIndex,
      'pageSize': dto.pageSize,
      'totalPages': dto.totalPages,
      'totalItems': dto.totalItems,
      'isLastPage': dto.isLastPage,
      'appVersion': dto.appVersion,
      'isDebugMode': dto.isDebugMode,
      'syncDevice': dto.syncDevice.toJson(),
    };

    if (dto.progress != null) {
      isolateData['progress'] = dto.progress!.toJson();
    }

    _addEntityDataToIsolateData(isolateData, dto);
    return isolateData;
  }

  /// Pre-serializes entity data for isolate processing
  void _addEntityDataToIsolateData(Map<String, dynamic> isolateData, PaginatedSyncDataDto dto) {
    if (dto.appUsagesSyncData != null) {
      isolateData['appUsagesSyncData'] = dto.appUsagesSyncData!.toJson();
    }
    if (dto.habitsSyncData != null) {
      isolateData['habitsSyncData'] = dto.habitsSyncData!.toJson();
    }
    if (dto.tasksSyncData != null) {
      isolateData['tasksSyncData'] = dto.tasksSyncData!.toJson();
    }
    if (dto.appUsageTagsSyncData != null) {
      isolateData['appUsageTagsSyncData'] = dto.appUsageTagsSyncData!.toJson();
    }
    if (dto.appUsageTimeRecordsSyncData != null) {
      isolateData['appUsageTimeRecordsSyncData'] = dto.appUsageTimeRecordsSyncData!.toJson();
    }
    if (dto.appUsageTagRulesSyncData != null) {
      isolateData['appUsageTagRulesSyncData'] = dto.appUsageTagRulesSyncData!.toJson();
    }
    if (dto.appUsageIgnoreRulesSyncData != null) {
      isolateData['appUsageIgnoreRulesSyncData'] = dto.appUsageIgnoreRulesSyncData!.toJson();
    }
    if (dto.habitRecordsSyncData != null) {
      isolateData['habitRecordsSyncData'] = dto.habitRecordsSyncData!.toJson();
    }
    if (dto.habitTagsSyncData != null) {
      isolateData['habitTagsSyncData'] = dto.habitTagsSyncData!.toJson();
    }
    if (dto.tagsSyncData != null) {
      isolateData['tagsSyncData'] = dto.tagsSyncData!.toJson();
    }
    if (dto.tagTagsSyncData != null) {
      isolateData['tagTagsSyncData'] = dto.tagTagsSyncData!.toJson();
    }
    if (dto.taskTagsSyncData != null) {
      isolateData['taskTagsSyncData'] = dto.taskTagsSyncData!.toJson();
    }
    if (dto.taskTimeRecordsSyncData != null) {
      isolateData['taskTimeRecordsSyncData'] = dto.taskTimeRecordsSyncData!.toJson();
    }
    if (dto.settingsSyncData != null) {
      isolateData['settingsSyncData'] = dto.settingsSyncData!.toJson();
    }
    if (dto.syncDevicesSyncData != null) {
      isolateData['syncDevicesSyncData'] = dto.syncDevicesSyncData!.toJson();
    }
    if (dto.notesSyncData != null) {
      isolateData['notesSyncData'] = dto.notesSyncData!.toJson();
    }
    if (dto.noteTagsSyncData != null) {
      isolateData['noteTagsSyncData'] = dto.noteTagsSyncData!.toJson();
    }
  }

  /// Converts DTO with chunked processing on main thread
  Future<Map<String, dynamic>> _convertDtoToJsonWithChunking(PaginatedSyncDataDto dto) async {
    DomainLogger.debug('Converting DTO to JSON with chunked processing');

    final result = <String, dynamic>{};

    await _yieldToUIThread();
    result['entityType'] = dto.entityType;
    result['pageIndex'] = dto.pageIndex;
    result['pageSize'] = dto.pageSize;
    result['totalPages'] = dto.totalPages;
    result['totalItems'] = dto.totalItems;
    result['isLastPage'] = dto.isLastPage;
    result['appVersion'] = dto.appVersion;
    result['isDebugMode'] = dto.isDebugMode;

    await _yieldToUIThread();
    result['syncDevice'] = dto.syncDevice.toJson();

    if (dto.progress != null) {
      result['progress'] = dto.progress!.toJson();
    }

    await _addEntityDataWithYielding(result, dto);

    DomainLogger.debug('DTO to JSON chunked conversion completed');
    return result;
  }

  /// Adds entity data with yielding to prevent UI blocking
  Future<void> _addEntityDataWithYielding(Map<String, dynamic> result, PaginatedSyncDataDto dto) async {
    await _serializeIfNotNull(result, 'appUsagesSyncData', dto.appUsagesSyncData);

    if (dto.habitsSyncData != null) {
      await _yieldToUIThread();
      final itemCount = dto.habitsSyncData!.data.getTotalItemCount();
      DomainLogger.debug('Serializing Habit data with $itemCount items');
      result['habitsSyncData'] = dto.habitsSyncData!.toJson();
      DomainLogger.debug('Habit data serialized successfully');
    } else {
      DomainLogger.debug('No Habit data to serialize for entityType: ${dto.entityType}');
    }

    if (dto.tasksSyncData != null) {
      await _yieldToUIThread();
      await _serializeTaskData(result, dto);
    } else {
      DomainLogger.debug('No Task data to serialize for entityType: ${dto.entityType}');
    }

    await _serializeIfNotNull(result, 'appUsageTagsSyncData', dto.appUsageTagsSyncData);
    await _serializeIfNotNull(result, 'appUsageTimeRecordsSyncData', dto.appUsageTimeRecordsSyncData);
    await _serializeIfNotNull(result, 'appUsageTagRulesSyncData', dto.appUsageTagRulesSyncData);
    await _serializeIfNotNull(result, 'appUsageIgnoreRulesSyncData', dto.appUsageIgnoreRulesSyncData);
    await _serializeIfNotNull(result, 'habitRecordsSyncData', dto.habitRecordsSyncData);
    await _serializeIfNotNull(result, 'habitTagsSyncData', dto.habitTagsSyncData);
    await _serializeIfNotNull(result, 'tagsSyncData', dto.tagsSyncData);
    await _serializeIfNotNull(result, 'tagTagsSyncData', dto.tagTagsSyncData);
    await _serializeIfNotNull(result, 'taskTagsSyncData', dto.taskTagsSyncData);
    await _serializeIfNotNull(result, 'taskTimeRecordsSyncData', dto.taskTimeRecordsSyncData);
    await _serializeIfNotNull(result, 'settingsSyncData', dto.settingsSyncData);
    await _serializeIfNotNull(result, 'syncDevicesSyncData', dto.syncDevicesSyncData);
    await _serializeIfNotNull(result, 'notesSyncData', dto.notesSyncData);
    await _serializeIfNotNull(result, 'noteTagsSyncData', dto.noteTagsSyncData);
  }

  Future<void> _serializeIfNotNull(Map<String, dynamic> result, String key, dynamic syncData) async {
    if (syncData != null) {
      await _yieldToUIThread();
      result[key] = syncData.toJson();
    }
  }

  /// Serializes task data with detailed debugging
  Future<void> _serializeTaskData(Map<String, dynamic> result, PaginatedSyncDataDto dto) async {
    final itemCount = dto.tasksSyncData!.data.getTotalItemCount();
    DomainLogger.debug('Serializing Task data with $itemCount items');

    try {
      final syncData = dto.tasksSyncData!.data;
      DomainLogger.debug(
          'Task data details: creates=${syncData.createSync.length}, updates=${syncData.updateSync.length}, deletes=${syncData.deleteSync.length}');

      // Test serialization of individual Task items first
      if (syncData.createSync.isNotEmpty) {
        DomainLogger.debug('Testing createSync[0] serialization...');
        final firstTask = syncData.createSync.first;
        DomainLogger.debug('First Task ID: ${firstTask.id}, Title: "${firstTask.title}"');
        try {
          final taskJson = firstTask.toJson();
          DomainLogger.debug('First Task serialized successfully: ${taskJson.keys.join(', ')}');
        } catch (taskError) {
          DomainLogger.error('Failed to serialize first Task: $taskError');
          DomainLogger.error(
              'Task details - Priority: ${firstTask.priority}, ReminderTime: ${firstTask.plannedDateReminderTime}, RecurrenceType: ${firstTask.recurrenceType}');
        }
      }

      if (syncData.updateSync.isNotEmpty) {
        DomainLogger.debug('Testing updateSync[0] serialization...');
        final firstUpdateTask = syncData.updateSync.first;
        DomainLogger.debug('First Update Task ID: ${firstUpdateTask.id}, Title: "${firstUpdateTask.title}"');
        try {
          final taskJson = firstUpdateTask.toJson();
          DomainLogger.debug('First Update Task serialized successfully: ${taskJson.keys.join(', ')}');
        } catch (taskError) {
          DomainLogger.error('Failed to serialize first Update Task: $taskError');
          DomainLogger.error(
              'Task details - Priority: ${firstUpdateTask.priority}, ReminderTime: ${firstUpdateTask.plannedDateReminderTime}, RecurrenceType: ${firstUpdateTask.recurrenceType}');
        }
      }

      // Full tasksSyncData serialization
      DomainLogger.debug('Attempting full tasksSyncData serialization...');
      result['tasksSyncData'] = dto.tasksSyncData!.toJson();
      DomainLogger.debug('Task data serialized successfully');
    } catch (e, stackTrace) {
      DomainLogger.error('CRITICAL ERROR: Task data serialization failed', error: e, stackTrace: stackTrace);

      // Fallback data
      result['tasksSyncData'] = {
        'data': {'createSync': [], 'updateSync': [], 'deleteSync': []},
        'pageIndex': dto.tasksSyncData!.pageIndex,
        'pageSize': dto.tasksSyncData!.pageSize,
        'totalPages': dto.tasksSyncData!.totalPages,
        'totalItems': 0,
        'isLastPage': dto.tasksSyncData!.isLastPage,
        'entityType': dto.tasksSyncData!.entityType
      };

      // Add metric or more aggressive logging here
      DomainLogger.warning('Using fallback empty Task data due to serialization error. '
          'This may result in missing tasks on the target device. '
          'Check previous "CRITICAL ERROR" log for root cause.');
    }
  }

  Future<void> _yieldToUIThread() async {
    await Future.delayed(Duration.zero);
  }

  // Static isolate function for DTO conversion
  static Map<String, dynamic> _convertDtoToJsonInIsolate(Map<String, dynamic> isolateData) {
    try {
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

      if (isolateData.containsKey('progress') && isolateData['progress'] != null) {
        result['progress'] = isolateData['progress'];
      }

      _addSerializedEntityData(result, isolateData);
      return result;
    } catch (e) {
      DomainLogger.error('Isolate DTO conversion failed: $e');
      rethrow;
    }
  }

  // Helper to add pre-serialized entity data
  static void _addSerializedEntityData(Map<String, dynamic> result, Map<String, dynamic> isolateData) {
    const syncDataKeys = [
      'appUsagesSyncData',
      'habitsSyncData',
      'tasksSyncData',
      'appUsageTagsSyncData',
      'appUsageTimeRecordsSyncData',
      'appUsageTagRulesSyncData',
      'appUsageIgnoreRulesSyncData',
      'habitRecordsSyncData',
      'habitTagsSyncData',
      'tagsSyncData',
      'tagTagsSyncData',
      'taskTagsSyncData',
      'taskTimeRecordsSyncData',
      'settingsSyncData',
      'syncDevicesSyncData',
      'notesSyncData',
      'noteTagsSyncData',
    ];

    for (final key in syncDataKeys) {
      if (isolateData.containsKey(key) && isolateData[key] != null) {
        result[key] = isolateData[key];
      }
    }
  }
}
