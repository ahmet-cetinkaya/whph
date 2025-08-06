import 'dart:io';
import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/src/presentation/api/controllers/paginated_sync_controller.dart';
import 'package:whph/src/core/application/shared/models/websocket_request.dart';
import 'package:whph/src/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

const int webSocketPort = 44040;

// Web socket server events
final streamController = StreamController<Map<String, dynamic>>.broadcast();
Stream<Map<String, dynamic>> get serverEvents => streamController.stream;

void startWebSocketServer() async {
  try {
    Logger.info('📡 Attempting to start WebSocket server on port $webSocketPort...');

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      webSocketPort,
    );

    Logger.info('✅ WebSocket Server successfully started on port $webSocketPort');
    Logger.info('🌐 WebSocket Server listening on all IPv4 interfaces (0.0.0.0:$webSocketPort)');
    Logger.info('📱 Ready to receive sync requests from other devices');

    // Handle incoming connections
    await for (HttpRequest req in server) {
      try {
        if (req.headers.value('upgrade')?.toLowerCase() == 'websocket') {
          final ws = await WebSocketTransformer.upgrade(req);
          Logger.info(
              '🔗 WebSocket connection established from ${req.connectionInfo?.remoteAddress}:${req.connectionInfo?.remotePort}');

          ws.listen(
            (data) async {
              Logger.debug('📨 Received message: $data');
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              Logger.error('❌ Connection error: $e');
              ws.close();
            },
            onDone: () {
              Logger.debug('🔚 Connection closed normally');
            },
            cancelOnError: true,
          );
        } else {
          req.response
            ..statusCode = HttpStatus.upgradeRequired
            ..headers.add('Upgrade', 'websocket')
            ..headers.add('Connection', 'Upgrade')
            ..write('WebSocket upgrade required')
            ..close();
        }
      } catch (e) {
        Logger.error('⚠️ Request handling error: $e');
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    }
  } catch (e) {
    Logger.error('💥 WebSocket server failed to start on port $webSocketPort: $e');
    rethrow;
  }
}

Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
  try {
    Logger.debug('Received message: $message');

    WebSocketMessage? parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
    if (parsedMessage == null) {
      throw FormatException('Error parsing WebSocket message');
    }

    switch (parsedMessage.type) {
      case 'test':
        // Send test response
        socket.add(JsonMapper.serialize(WebSocketMessage(
          type: 'test_response',
          data: {
            'success': true,
            'timestamp': DateTime.now().toIso8601String(),
          },
        )));
        break;

      case 'paginated_sync':
        Logger.info('🔄 Processing paginated sync request...');
        final paginatedSyncData = parsedMessage.data;
        if (paginatedSyncData == null) {
          throw FormatException('Paginated sync message missing data');
        }

        Logger.debug(
            '📊 Paginated sync data received for entity: ${(paginatedSyncData as Map<String, dynamic>)['entityType']}');
        final paginatedController = PaginatedSyncController();
        try {
          final response = await paginatedController.paginatedSync(PaginatedSyncDataDto.fromJson(paginatedSyncData));
          Logger.info('✅ Paginated sync processing completed successfully');

          WebSocketMessage responseMessage = WebSocketMessage(type: 'paginated_sync_complete', data: {
            'paginatedSyncDataDto': response.paginatedSyncDataDto?.toJson(),
            'success': true,
            'isComplete': response.isComplete,
            'timestamp': DateTime.now().toIso8601String()
          });
          socket.add(JsonMapper.serialize(responseMessage));
          Logger.info('📤 Paginated sync response sent to client');

          // CRITICAL FIX: Add proper delay to ensure response is fully transmitted before close
          await Future.delayed(const Duration(milliseconds: 1000));
          await socket.close();
        } catch (e, stackTrace) {
          Logger.error('Paginated sync processing failed: $e');
          Logger.error('Stack trace: $stackTrace');

          // Enhanced error response with debugging information (excluding stack trace for security)
          final errorData = <String, dynamic>{
            'success': false,
            'message': e.toString(),
            'type': e.runtimeType.toString(),
            'timestamp': DateTime.now().toIso8601String(),
            'entityType': (parsedMessage.data as Map<String, dynamic>?)?.containsKey('entityType') == true
                ? (parsedMessage.data as Map<String, dynamic>)['entityType']
                : 'unknown',
            'metadata': <String, dynamic>{},
          };

          // Add specific error details based on error type
          if (e is FormatException) {
            errorData['metadata']['errorCategory'] = 'JSON_PARSING';
            errorData['metadata']['source'] = e.source;
            errorData['metadata']['offset'] = e.offset;
          } else if (e is ArgumentError) {
            errorData['metadata']['errorCategory'] = 'ARGUMENT_ERROR';
            errorData['metadata']['invalidValue'] = e.invalidValue?.toString();
            errorData['metadata']['name'] = e.name;
          } else if (e is StateError) {
            errorData['metadata']['errorCategory'] = 'STATE_ERROR';
          } else if (e.toString().contains('Unable to instantiate')) {
            errorData['metadata']['errorCategory'] = 'ENTITY_INSTANTIATION';
            // Try to extract entity name and missing arguments
            final instantiationMatch = RegExp(r"Unable to instantiate class '(\w+)'").firstMatch(e.toString());
            if (instantiationMatch != null) {
              errorData['metadata']['failedEntityClass'] = instantiationMatch.group(1);
            }
            final argumentsMatch = RegExp(r'with null named arguments \[(.*?)\]').firstMatch(e.toString());
            if (argumentsMatch != null) {
              errorData['metadata']['missingArguments'] = argumentsMatch.group(1)?.split(', ');
            }
          } else {
            errorData['metadata']['errorCategory'] = 'UNKNOWN';
          }

          // Try to capture the problematic entity data if available
          try {
            final paginatedSyncData = parsedMessage.data;
            if (paginatedSyncData is Map<String, dynamic>) {
              errorData['metadata']['pageIndex'] = paginatedSyncData['pageIndex'];
              errorData['metadata']['pageSize'] = paginatedSyncData['pageSize'];
              errorData['metadata']['totalItems'] = paginatedSyncData['totalItems'];

              // Try to identify the first problematic entity
              final entityTypeKey = '${paginatedSyncData['entityType']}sSyncData';
              final syncDataMap = paginatedSyncData[entityTypeKey] as Map<String, dynamic>?;
              if (syncDataMap?['data'] is Map<String, dynamic>) {
                final dataMap = syncDataMap!['data'] as Map<String, dynamic>;
                for (final listKey in ['createSync', 'updateSync', 'deleteSync']) {
                  final entityList = dataMap[listKey] as List?;
                  if (entityList != null && entityList.isNotEmpty) {
                    errorData['metadata']['sampleEntityData'] = entityList.first;
                    break;
                  }
                }
              }
            }
          } catch (metadataError) {
            errorData['metadata']['metadataExtractionError'] = metadataError.toString();
          }

          WebSocketMessage errorMessage = WebSocketMessage(type: 'paginated_sync_error', data: errorData);
          socket.add(JsonMapper.serialize(errorMessage));
          // Close the socket after sending an error to clean up resources
          await socket.close();
        }
        break;

      default:
        socket.add(JsonMapper.serialize(WebSocketMessage(type: 'error', data: {'message': 'Unknown message type'})));
        await socket.close();
        break;
    }
  } catch (e) {
    Logger.error('Error processing WebSocket message: $e');
    socket.add(JsonMapper.serialize(WebSocketMessage(type: 'error', data: {'message': e.toString()})));
    await socket.close();
    rethrow;
  }
}
