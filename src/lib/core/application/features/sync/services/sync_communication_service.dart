import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Implementation of sync communication service for WebSocket-based sync operations
class SyncCommunicationService implements ISyncCommunicationService {
  static const int _maxRetries = 3;
  static const int _baseTimeoutSeconds = 15;
  static const int _websocketPort = 44040;

  SyncCommunicationService() {
    Logger.info('🚀 SyncCommunicationService initialized with ENHANCED Task serialization debugging');
  }

  @override
  Future<SyncCommunicationResponse> sendPaginatedDataToDevice(String ipAddress, PaginatedSyncDataDto dto) async {
    final entityType = dto.entityType;
    final pageIndex = dto.pageIndex;
    final startTime = DateTime.now();
    int attempt = 0;

    Logger.info('📡 Starting paginated sync transmission to $ipAddress:$_websocketPort');
    Logger.debug('🔍 Sending: entity=$entityType, page=$pageIndex');

    while (attempt < _maxRetries) {
      WebSocket? socket;
      try {
        final timeout = Duration(seconds: _baseTimeoutSeconds * (attempt + 1));
        socket = await WebSocket.connect(getWebSocketUrl(ipAddress)).timeout(timeout);

        final completer = Completer<SyncCommunicationResponse>();
        Timer? timeoutTimer;

        timeoutTimer = Timer(timeout, () {
          if (!completer.isCompleted) {
            Logger.error(
                '⏰ WebSocket timeout after ${timeout.inSeconds} seconds (attempt ${attempt + 1}/$_maxRetries)');
            completer.complete(SyncCommunicationResponse(
              success: false,
              isComplete: true,
              error: 'Operation failed',
            ));
            socket?.close();
          }
        });

        // Convert DTO to JSON with yielding
        final startJsonTime = DateTime.now();
        Logger.debug('🔄 Converting DTO to JSON for transmission');
        await _yieldToUIThread();

        final dtoJson = await convertDtoToJson(dto);
        final jsonTime = DateTime.now().difference(startJsonTime).inMilliseconds;
        Logger.debug('✅ DTO to JSON conversion completed in ${jsonTime}ms');

        await _yieldToUIThread();
        Logger.debug('🔄 Serializing WebSocket message');

        final message = WebSocketMessage(type: 'paginated_sync', data: dtoJson);
        final serializedMessage = await serializeMessage(message);

        await _yieldToUIThread();

        // Validate message integrity before sending
        if (!_validateMessageIntegrity(dtoJson, entityType)) {
          Logger.error('❌ Pre-transmission validation failed');
          throw Exception('Pre-transmission validation failed');
        }

        final transmissionStartTime = DateTime.now();
        Logger.debug('🔄 Sending message via WebSocket (${serializedMessage.length} bytes)');

        socket.add(serializedMessage);

        // Listen for response
        await for (final message in socket) {
          try {
            final responseTime = DateTime.now().difference(transmissionStartTime).inMilliseconds;
            Logger.debug(
                '📨 Received WebSocket response (${message.toString().length} bytes) - Response time: ${responseTime}ms');
            await _yieldToUIThread();

            final receivedMessage = await _deserializeMessage(message);

            if (receivedMessage == null) {
              Logger.error('❌ Failed to deserialize WebSocket message');
              completer.complete(SyncCommunicationResponse(
                success: false,
                isComplete: true,
                error: 'Operation failed',
              ));
              break;
            }

            Logger.debug('✓ Successfully deserialized message type: ${receivedMessage.type}');
            await _yieldToUIThread();

            if (receivedMessage.type == 'paginated_sync_complete' || receivedMessage.type == 'paginated_sync') {
              timeoutTimer.cancel();

              if (receivedMessage.data is! Map<String, dynamic>) {
                Logger.error('❌ Invalid response data structure');
                completer.complete(SyncCommunicationResponse(
                  success: false,
                  isComplete: true,
                  error: 'Operation failed',
                ));
                break;
              }

              final responseData = receivedMessage.data;
              final success = responseData['success'] as bool? ?? false;
              final isComplete = responseData['isComplete'] as bool? ?? true; // Default to complete

              if (success) {
                final totalTime = DateTime.now().difference(startTime).inMilliseconds;
                Logger.info('✅ Paginated sync transmission successful (${totalTime}ms total)');
                if (!isComplete) {
                  Logger.info('🔄 Server indicates bidirectional sync needed (isComplete: false)');
                }

                // Extract response data if available
                PaginatedSyncDataDto? serverResponseData;
                final paginatedSyncDataDto = responseData['paginatedSyncDataDto'];
                if (paginatedSyncDataDto != null) {
                  try {
                    serverResponseData = PaginatedSyncDataDto.fromJson(paginatedSyncDataDto as Map<String, dynamic>);
                    Logger.info('📨 Received server response data with ${serverResponseData.entityType} entities');
                  } catch (e) {
                    Logger.error('❌ Failed to parse server response data: $e');
                  }
                }

                completer.complete(SyncCommunicationResponse(
                  success: true,
                  isComplete: isComplete,
                  responseData: serverResponseData,
                ));
              } else {
                final error = responseData['error'] as String? ?? 'Unknown error';
                Logger.error('❌ Server reported sync failure: $error');
                completer.complete(SyncCommunicationResponse(
                  success: false,
                  isComplete: true, // Doesn't matter if failed
                  error: error,
                ));
              }
              break;
            } else if (receivedMessage.type == 'error') {
              timeoutTimer.cancel();
              final error = receivedMessage.data?['message'] ?? 'Unknown error';
              Logger.error('❌ Server error during sync: $error');
              completer.complete(SyncCommunicationResponse(
                success: false,
                isComplete: true,
                error: 'Operation failed',
              ));
              break;
            }
          } catch (e) {
            Logger.error('❌ Error processing WebSocket response: $e');
            completer.complete(SyncCommunicationResponse(
              success: false,
              isComplete: true,
              error: 'Operation failed',
            ));
            break;
          }
        }

        return await completer.future;
      } catch (e) {
        attempt++;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        Logger.warning('⚠️ WebSocket attempt $attempt failed after ${totalTime}ms: $e');

        await socket?.close();

        if (attempt >= _maxRetries) {
          Logger.error('❌ All WebSocket attempts failed. Final error: $e');
          return SyncCommunicationResponse(
            success: false,
            isComplete: true,
            error: 'All retry attempts failed: $e',
          );
        }

        if (attempt < _maxRetries) {
          final backoffDelay = Duration(seconds: attempt * 2);
          Logger.debug('⏳ Waiting ${backoffDelay.inSeconds}s before retry...');
          await Future.delayed(backoffDelay);
        }
      }
    }

    return SyncCommunicationResponse(
      success: false,
      isComplete: true,
      error: 'Sync operation failed',
    );
  }

  @override
  Future<Map<String, dynamic>> convertDtoToJson(PaginatedSyncDataDto dto) async {
    try {
      // Add specific debugging for Task entity
      if (dto.entityType == 'Task' || dto.tasksSyncData != null) {
        Logger.debug('🎯 TASK DTO CONVERSION: entityType=${dto.entityType}');
        if (dto.tasksSyncData != null) {
          final taskCount = dto.tasksSyncData!.data.getTotalItemCount();
          Logger.debug('🎯 TASK DTO has $taskCount items to convert');
        } else {
          Logger.debug('🎯 TASK DTO tasksSyncData is null');
        }
      }

      // Estimate data size to determine processing strategy
      final totalItems = _estimateDataSize(dto);

      if (totalItems > 100) {
        Logger.debug('🧵 Using isolate for DTO to JSON conversion ($totalItems items)');
        try {
          // Use isolate for large datasets
          final isolateData = <String, dynamic>{
            'entityType': dto.entityType,
            'pageIndex': dto.pageIndex,
            'pageSize': dto.pageSize,
            'totalPages': dto.totalPages,
            'totalItems': dto.totalItems,
            'isLastPage': dto.isLastPage,
            'appVersion': dto.appVersion,
            'isDebugMode': dto.isDebugMode,
          };

          // Add non-nullable sync device
          isolateData['syncDevice'] = dto.syncDevice;

          // Add progress if not null
          if (dto.progress != null) {
            isolateData['progress'] = dto.progress;
          }

          // Add entity-specific data
          _addEntityDataToIsolateData(isolateData, dto);

          return await compute(_convertDtoToJsonInIsolate, isolateData);
        } catch (e) {
          Logger.warning('⚠️ Isolate conversion failed, using main thread with chunking: $e');
          return await _convertDtoToJsonWithChunking(dto);
        }
      } else {
        // Use main thread with yielding for smaller datasets
        return await _convertDtoToJsonWithChunking(dto);
      }
    } catch (e, stackTrace) {
      Logger.error('❌ DTO to JSON conversion failed: $e');
      Logger.error('❌ Stack trace: $stackTrace');

      if (dto.entityType == 'Task' || dto.tasksSyncData != null) {
        Logger.error('🎯 CRITICAL: Task DTO conversion failed - this is the root cause!');
      }

      rethrow;
    }
  }

  @override
  Future<String> serializeMessage(WebSocketMessage message) async {
    Logger.debug('🔄 Starting WebSocket message serialization');
    await _yieldToUIThread();

    try {
      // For large messages, use isolate processing
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
      await _yieldToUIThread();

      // Clean message data to avoid serialization errors
      final cleanedMessage = _cleanWebSocketMessageData(message);
      final result = JsonMapper.serialize(cleanedMessage);

      Logger.debug('✅ WebSocket message serialization completed');
      return result;
    } catch (e) {
      Logger.error('❌ WebSocket message serialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isDeviceReachable(String ipAddress) async {
    try {
      final socket = await WebSocket.connect(getWebSocketUrl(ipAddress)).timeout(const Duration(seconds: 5));
      await socket.close();
      return true;
    } catch (e) {
      Logger.debug('🔍 Device $ipAddress is not reachable: $e');
      return false;
    }
  }

  @override
  String getWebSocketUrl(String ipAddress) {
    return 'ws://$ipAddress:$_websocketPort';
  }

  @override
  Future<bool> handleConnectionError(String ipAddress, Exception error) async {
    Logger.warning('⚠️ WebSocket connection error to $ipAddress: $error');

    // Basic retry logic with exponential backoff
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(seconds: (i + 1) * 2));

      if (await isDeviceReachable(ipAddress)) {
        Logger.info('✅ Connection to $ipAddress recovered after ${i + 1} retries');
        return true;
      }
    }

    Logger.error('❌ Failed to recover connection to $ipAddress after 3 retries');
    return false;
  }

  // Private helper methods

  Future<void> _yieldToUIThread() async {
    await Future.delayed(Duration.zero);
  }

  int _estimateDataSize(PaginatedSyncDataDto dto) {
    int total = 0;
    // Add logic to estimate data size based on DTO contents
    // This is a simplified estimation
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

  void _addEntityDataToIsolateData(Map<String, dynamic> isolateData, PaginatedSyncDataDto dto) {
    // Add entity-specific sync data to isolate data
    if (dto.appUsagesSyncData != null) {
      isolateData['appUsagesSyncData'] = dto.appUsagesSyncData;
    }
    if (dto.habitsSyncData != null) {
      isolateData['habitsSyncData'] = dto.habitsSyncData;
    }
    if (dto.tasksSyncData != null) {
      isolateData['tasksSyncData'] = dto.tasksSyncData;
    }
    if (dto.appUsageTagsSyncData != null) {
      isolateData['appUsageTagsSyncData'] = dto.appUsageTagsSyncData;
    }
    if (dto.appUsageTimeRecordsSyncData != null) {
      isolateData['appUsageTimeRecordsSyncData'] = dto.appUsageTimeRecordsSyncData;
    }
    if (dto.appUsageTagRulesSyncData != null) {
      isolateData['appUsageTagRulesSyncData'] = dto.appUsageTagRulesSyncData;
    }
    if (dto.appUsageIgnoreRulesSyncData != null) {
      isolateData['appUsageIgnoreRulesSyncData'] = dto.appUsageIgnoreRulesSyncData;
    }
    if (dto.habitRecordsSyncData != null) {
      isolateData['habitRecordsSyncData'] = dto.habitRecordsSyncData;
    }
    if (dto.habitTagsSyncData != null) {
      isolateData['habitTagsSyncData'] = dto.habitTagsSyncData;
    }
    if (dto.tagsSyncData != null) {
      isolateData['tagsSyncData'] = dto.tagsSyncData;
    }
    if (dto.tagTagsSyncData != null) {
      isolateData['tagTagsSyncData'] = dto.tagTagsSyncData;
    }
    if (dto.taskTagsSyncData != null) {
      isolateData['taskTagsSyncData'] = dto.taskTagsSyncData;
    }
    if (dto.taskTimeRecordsSyncData != null) {
      isolateData['taskTimeRecordsSyncData'] = dto.taskTimeRecordsSyncData;
    }
    if (dto.settingsSyncData != null) {
      isolateData['settingsSyncData'] = dto.settingsSyncData;
    }
    if (dto.syncDevicesSyncData != null) {
      isolateData['syncDevicesSyncData'] = dto.syncDevicesSyncData;
    }
    if (dto.notesSyncData != null) {
      isolateData['notesSyncData'] = dto.notesSyncData;
    }
    if (dto.noteTagsSyncData != null) {
      isolateData['noteTagsSyncData'] = dto.noteTagsSyncData;
    }
  }

  Future<Map<String, dynamic>> _convertDtoToJsonWithChunking(PaginatedSyncDataDto dto) async {
    Logger.debug('🔄 Converting DTO to JSON with chunked processing');

    final result = <String, dynamic>{};

    // Basic properties first
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

    // Serialize complex objects
    result['syncDevice'] = JsonMapper.toMap(dto.syncDevice);

    if (dto.progress != null) {
      result['progress'] = JsonMapper.toMap(dto.progress);
    }

    // Add entity-specific data with yielding
    await _addEntityDataWithYielding(result, dto);

    Logger.debug('✅ DTO to JSON chunked conversion completed');
    return result;
  }

  Future<void> _addEntityDataWithYielding(Map<String, dynamic> result, PaginatedSyncDataDto dto) async {
    if (dto.appUsagesSyncData != null) {
      await _yieldToUIThread();
      result['appUsagesSyncData'] = JsonMapper.toMap(dto.appUsagesSyncData);
    }

    if (dto.habitsSyncData != null) {
      await _yieldToUIThread();
      final itemCount = dto.habitsSyncData!.data.getTotalItemCount();
      Logger.debug('📤 Serializing Habit data with $itemCount items');
      result['habitsSyncData'] = JsonMapper.toMap(dto.habitsSyncData);
      Logger.debug('📤 Habit data serialized successfully');
    } else {
      Logger.debug('📤 No Habit data to serialize for entityType: ${dto.entityType}');
    }

    if (dto.tasksSyncData != null) {
      await _yieldToUIThread();
      final itemCount = dto.tasksSyncData!.data.getTotalItemCount();
      Logger.debug('📤 Serializing Task data with $itemCount items');

      try {
        // Add detailed debugging for Task serialization
        final syncData = dto.tasksSyncData!.data;
        Logger.debug(
            '📤 Task data details: creates=${syncData.createSync.length}, updates=${syncData.updateSync.length}, deletes=${syncData.deleteSync.length}');

        // Test serialization of individual Task items first
        if (syncData.createSync.isNotEmpty) {
          Logger.debug('📤 Testing createSync[0] serialization...');
          final firstTask = syncData.createSync.first;
          Logger.debug('📤 First Task ID: ${firstTask.id}, Title: "${firstTask.title}"');
          try {
            final taskJson = JsonMapper.toMap(firstTask);
            Logger.debug('📤 First Task serialized successfully: ${taskJson?.keys.join(', ') ?? 'null'}');
          } catch (taskError) {
            Logger.error('❌ Failed to serialize first Task: $taskError');
            Logger.error(
                '❌ Task details - Priority: ${firstTask.priority}, ReminderTime: ${firstTask.plannedDateReminderTime}, RecurrenceType: ${firstTask.recurrenceType}');
          }
        }

        if (syncData.updateSync.isNotEmpty) {
          Logger.debug('📤 Testing updateSync[0] serialization...');
          final firstUpdateTask = syncData.updateSync.first;
          Logger.debug('📤 First Update Task ID: ${firstUpdateTask.id}, Title: "${firstUpdateTask.title}"');
          try {
            final taskJson = JsonMapper.toMap(firstUpdateTask);
            Logger.debug('📤 First Update Task serialized successfully: ${taskJson?.keys.join(', ') ?? 'null'}');
          } catch (taskError) {
            Logger.error('❌ Failed to serialize first Update Task: $taskError');
            Logger.error(
                '❌ Task details - Priority: ${firstUpdateTask.priority}, ReminderTime: ${firstUpdateTask.plannedDateReminderTime}, RecurrenceType: ${firstUpdateTask.recurrenceType}');
          }
        }

        // Now attempt full tasksSyncData serialization
        Logger.debug('📤 Attempting full tasksSyncData serialization...');
        result['tasksSyncData'] = JsonMapper.toMap(dto.tasksSyncData);
        Logger.debug('📤 ✅ Task data serialized successfully');
      } catch (e, stackTrace) {
        Logger.error('❌ CRITICAL ERROR: Task data serialization failed: $e');
        Logger.error('❌ Stack trace: $stackTrace');

        // Try to provide fallback data
        result['tasksSyncData'] = {
          'data': {'createSync': [], 'updateSync': [], 'deleteSync': []},
          'pageIndex': dto.tasksSyncData!.pageIndex,
          'pageSize': dto.tasksSyncData!.pageSize,
          'totalPages': dto.tasksSyncData!.totalPages,
          'totalItems': 0,
          'isLastPage': dto.tasksSyncData!.isLastPage,
          'entityType': dto.tasksSyncData!.entityType
        };
        Logger.warning('⚠️ Using fallback empty Task data due to serialization error');
      }
    } else {
      Logger.debug('📤 No Task data to serialize for entityType: ${dto.entityType}');
    }

    if (dto.appUsageTagsSyncData != null) {
      await _yieldToUIThread();
      result['appUsageTagsSyncData'] = JsonMapper.toMap(dto.appUsageTagsSyncData);
    }

    if (dto.appUsageTimeRecordsSyncData != null) {
      await _yieldToUIThread();
      result['appUsageTimeRecordsSyncData'] = JsonMapper.toMap(dto.appUsageTimeRecordsSyncData);
    }

    if (dto.appUsageTagRulesSyncData != null) {
      await _yieldToUIThread();
      result['appUsageTagRulesSyncData'] = JsonMapper.toMap(dto.appUsageTagRulesSyncData);
    }

    if (dto.appUsageIgnoreRulesSyncData != null) {
      await _yieldToUIThread();
      result['appUsageIgnoreRulesSyncData'] = JsonMapper.toMap(dto.appUsageIgnoreRulesSyncData);
    }

    if (dto.habitRecordsSyncData != null) {
      await _yieldToUIThread();
      result['habitRecordsSyncData'] = JsonMapper.toMap(dto.habitRecordsSyncData);
    }

    if (dto.habitTagsSyncData != null) {
      await _yieldToUIThread();
      result['habitTagsSyncData'] = JsonMapper.toMap(dto.habitTagsSyncData);
    }

    if (dto.tagsSyncData != null) {
      await _yieldToUIThread();
      result['tagsSyncData'] = JsonMapper.toMap(dto.tagsSyncData);
    }

    if (dto.tagTagsSyncData != null) {
      await _yieldToUIThread();
      result['tagTagsSyncData'] = JsonMapper.toMap(dto.tagTagsSyncData);
    }

    if (dto.taskTagsSyncData != null) {
      await _yieldToUIThread();
      result['taskTagsSyncData'] = JsonMapper.toMap(dto.taskTagsSyncData);
    }

    if (dto.taskTimeRecordsSyncData != null) {
      await _yieldToUIThread();
      result['taskTimeRecordsSyncData'] = JsonMapper.toMap(dto.taskTimeRecordsSyncData);
    }

    if (dto.settingsSyncData != null) {
      await _yieldToUIThread();
      result['settingsSyncData'] = JsonMapper.toMap(dto.settingsSyncData);
    }

    if (dto.syncDevicesSyncData != null) {
      await _yieldToUIThread();
      result['syncDevicesSyncData'] = JsonMapper.toMap(dto.syncDevicesSyncData);
    }

    if (dto.notesSyncData != null) {
      await _yieldToUIThread();
      result['notesSyncData'] = JsonMapper.toMap(dto.notesSyncData);
    }

    if (dto.noteTagsSyncData != null) {
      await _yieldToUIThread();
      result['noteTagsSyncData'] = JsonMapper.toMap(dto.noteTagsSyncData);
    }
  }

  int _estimateJsonDataSize(Map<String, dynamic> data) {
    // Simple estimation based on number of top-level keys and nested structures
    int size = data.length;
    for (final value in data.values) {
      if (value is List) {
        size += value.length;
      } else if (value is Map) {
        size += value.length;
      }
    }
    return size;
  }

  WebSocketMessage _cleanWebSocketMessageData(WebSocketMessage message) {
    // Create a cleaned version of the message to avoid serialization issues
    final cleanedData = _deepCleanMap(message.data);
    return WebSocketMessage(type: message.type, data: cleanedData);
  }

  dynamic _deepCleanMap(dynamic data) {
    if (data is Map) {
      final cleaned = <String, dynamic>{};
      for (final entry in data.entries) {
        cleaned[entry.key.toString()] = _deepCleanMap(entry.value);
      }
      return cleaned;
    } else if (data is List) {
      return data.map(_deepCleanMap).toList();
    }
    return data;
  }

  bool _validateMessageIntegrity(Map<String, dynamic> data, String entityType) {
    try {
      // Basic validation
      if (data.isEmpty) return false;
      if (!data.containsKey('entityType')) return false;
      if (data['entityType'] != entityType) return false;

      Logger.debug('✅ Message integrity validation passed');
      return true;
    } catch (e) {
      Logger.error('❌ Message integrity validation failed: $e');
      return false;
    }
  }

  Future<WebSocketMessage?> _deserializeMessage(dynamic message) async {
    try {
      await _yieldToUIThread();

      final messageString = message.toString();
      final messageMap = json.decode(messageString) as Map<String, dynamic>;

      return WebSocketMessage(
        type: messageMap['type'] as String,
        data: messageMap['data'],
      );
    } catch (e) {
      Logger.error('❌ Failed to deserialize WebSocket message: $e');
      return null;
    }
  }

  // Static isolate functions
  static Map<String, dynamic> _convertDtoToJsonInIsolate(Map<String, dynamic> isolateData) {
    // Convert DTO data in isolate context
    // Reconstruct the PaginatedSyncDataDto from the isolateData map and convert to JSON

    final result = <String, dynamic>{}; // Map to return as JSON

    // Basic properties first
    result['entityType'] = isolateData['entityType'];
    result['pageIndex'] = isolateData['pageIndex'];
    result['pageSize'] = isolateData['pageSize'];
    result['totalPages'] = isolateData['totalPages'];
    result['totalItems'] = isolateData['totalItems'];
    result['isLastPage'] = isolateData['isLastPage'];
    result['appVersion'] = isolateData['appVersion'];
    result['isDebugMode'] = isolateData['isDebugMode'];

    // Add sync device which is non-nullable
    result['syncDevice'] = _serializeEntity(isolateData['syncDevice']);

    // Add progress if present
    if (isolateData.containsKey('progress') && isolateData['progress'] != null) {
      result['progress'] = _serializeEntity(isolateData['progress']);
    }

    // Add entity-specific data with proper serialization
    _addSerializedEntityData(result, isolateData);

    return result;
  }

    // Helper method to serialize entities in isolate
  static dynamic _serializeEntity(dynamic entity) {
    if (entity == null) return null;
    
    // Handle simple types directly
    if (entity is String || entity is num || entity is bool) {
      return entity;
    }
    
    // Handle DateTime by converting to ISO string
    if (entity is DateTime) {
      return entity.toIso8601String();
    }
    
    // Handle maps by recursively serializing their values
    if (entity is Map<String, dynamic>) {
      final result = <String, dynamic>{};
      for (final entry in entity.entries) {
        result[entry.key] = _serializeEntity(entry.value);
      }
      return result;
    }
    
    // Handle lists by serializing each element
    if (entity is List) {
      return entity.map(_serializeEntity).toList();
    }

    // For complex objects, we need to make sure they are properly serializable in isolate context
    // Convert known object types to basic types that can be transferred between isolates
    // This is important because only specific data types can be transferred between isolates
    if (entity is BaseEntity) {
      // Convert BaseEntity to a basic Map structure
      final entityMap = <String, dynamic>{};
      entityMap['id'] = entity.id;
      entityMap['createdDate'] = entity.createdDate?.toIso8601String();
      entityMap['modifiedDate'] = entity.modifiedDate?.toIso8601String();
      entityMap['deletedDate'] = entity.deletedDate?.toIso8601String();
      
      // Add specific properties based on entity type
      if (entity is Task) {
        entityMap['title'] = entity.title;
        entityMap['description'] = entity.description;
        entityMap['priority'] = entity.priority?.index;
        entityMap['plannedDate'] = entity.plannedDate?.toIso8601String();
        entityMap['deadlineDate'] = entity.deadlineDate?.toIso8601String();
        entityMap['estimatedTime'] = entity.estimatedTime;
        entityMap['isCompleted'] = entity.isCompleted;
        entityMap['parentTaskId'] = entity.parentTaskId;
        entityMap['order'] = entity.order;
        entityMap['plannedDateReminderTime'] = entity.plannedDateReminderTime?.index;
        entityMap['deadlineDateReminderTime'] = entity.deadlineDateReminderTime?.index;
        entityMap['recurrenceType'] = entity.recurrenceType?.index;
        entityMap['recurrenceInterval'] = entity.recurrenceInterval;
        entityMap['recurrenceDaysString'] = entity.recurrenceDaysString;
        entityMap['recurrenceStartDate'] = entity.recurrenceStartDate?.toIso8601String();
        entityMap['recurrenceEndDate'] = entity.recurrenceEndDate?.toIso8601String();
        entityMap['recurrenceCount'] = entity.recurrenceCount;
        entityMap['recurrenceParentId'] = entity.recurrenceParentId;
      } else if (entity is HabitRecord) {
        entityMap['habitId'] = entity.habitId;
        entityMap['occurredAt'] = entity.occurredAt?.toIso8601String();
      }
      // Add more entity types as needed
      
      return entityMap;
    }

    // For any other object type, try to convert to string as a last resort
    // but this is not ideal for actual data processing
    return entity.toString();
  }

  // Helper method to add serialized entity data
  static void _addSerializedEntityData(Map<String, dynamic> result, Map<String, dynamic> isolateData) {
    // Add each entity-specific sync data if present
    if (isolateData.containsKey('appUsagesSyncData') && isolateData['appUsagesSyncData'] != null) {
      result['appUsagesSyncData'] = _serializeEntity(isolateData['appUsagesSyncData']);
    }
    if (isolateData.containsKey('habitsSyncData') && isolateData['habitsSyncData'] != null) {
      result['habitsSyncData'] = _serializeEntity(isolateData['habitsSyncData']);
    }
    if (isolateData.containsKey('tasksSyncData') && isolateData['tasksSyncData'] != null) {
      result['tasksSyncData'] = _serializeEntity(isolateData['tasksSyncData']);
    }
    if (isolateData.containsKey('appUsageTagsSyncData') && isolateData['appUsageTagsSyncData'] != null) {
      result['appUsageTagsSyncData'] = _serializeEntity(isolateData['appUsageTagsSyncData']);
    }
    if (isolateData.containsKey('appUsageTimeRecordsSyncData') && isolateData['appUsageTimeRecordsSyncData'] != null) {
      result['appUsageTimeRecordsSyncData'] = _serializeEntity(isolateData['appUsageTimeRecordsSyncData']);
    }
    if (isolateData.containsKey('appUsageTagRulesSyncData') && isolateData['appUsageTagRulesSyncData'] != null) {
      result['appUsageTagRulesSyncData'] = _serializeEntity(isolateData['appUsageTagRulesSyncData']);
    }
    if (isolateData.containsKey('appUsageIgnoreRulesSyncData') && isolateData['appUsageIgnoreRulesSyncData'] != null) {
      result['appUsageIgnoreRulesSyncData'] = _serializeEntity(isolateData['appUsageIgnoreRulesSyncData']);
    }
    if (isolateData.containsKey('habitRecordsSyncData') && isolateData['habitRecordsSyncData'] != null) {
      result['habitRecordsSyncData'] = _serializeEntity(isolateData['habitRecordsSyncData']);
    }
    if (isolateData.containsKey('habitTagsSyncData') && isolateData['habitTagsSyncData'] != null) {
      result['habitTagsSyncData'] = _serializeEntity(isolateData['habitTagsSyncData']);
    }
    if (isolateData.containsKey('tagsSyncData') && isolateData['tagsSyncData'] != null) {
      result['tagsSyncData'] = _serializeEntity(isolateData['tagsSyncData']);
    }
    if (isolateData.containsKey('tagTagsSyncData') && isolateData['tagTagsSyncData'] != null) {
      result['tagTagsSyncData'] = _serializeEntity(isolateData['tagTagsSyncData']);
    }
    if (isolateData.containsKey('taskTagsSyncData') && isolateData['taskTagsSyncData'] != null) {
      result['taskTagsSyncData'] = _serializeEntity(isolateData['taskTagsSyncData']);
    }
    if (isolateData.containsKey('taskTimeRecordsSyncData') && isolateData['taskTimeRecordsSyncData'] != null) {
      result['taskTimeRecordsSyncData'] = _serializeEntity(isolateData['taskTimeRecordsSyncData']);
    }
    if (isolateData.containsKey('settingsSyncData') && isolateData['settingsSyncData'] != null) {
      result['settingsSyncData'] = _serializeEntity(isolateData['settingsSyncData']);
    }
    if (isolateData.containsKey('syncDevicesSyncData') && isolateData['syncDevicesSyncData'] != null) {
      result['syncDevicesSyncData'] = _serializeEntity(isolateData['syncDevicesSyncData']);
    }
    if (isolateData.containsKey('notesSyncData') && isolateData['notesSyncData'] != null) {
      result['notesSyncData'] = _serializeEntity(isolateData['notesSyncData']);
    }
    if (isolateData.containsKey('noteTagsSyncData') && isolateData['noteTagsSyncData'] != null) {
      result['noteTagsSyncData'] = _serializeEntity(isolateData['noteTagsSyncData']);
    }
  }

  static String _serializeMessageInIsolate(Map<String, dynamic> messageData) {
    try {
      // Extract the type and data from messageData
      final type = messageData['type'] as String;
      final data = messageData['data'];
      
      // Create the WebSocketMessage instance
      final message = WebSocketMessage(
        type: type,
        data: data,
      );
      
      // Serialize using JsonMapper, but handle any potential errors
      final result = JsonMapper.serialize(message);
      return result;
    } catch (e) {
      // If serialization fails, return an error message
      // In a real scenario, we might want to handle this differently
      return JsonMapper.serialize(WebSocketMessage(
        type: 'error',
        data: {'message': 'Serialization failed in isolate: $e'}
      ));
    }
  }
}
