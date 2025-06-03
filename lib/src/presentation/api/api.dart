import 'dart:io';
import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/src/presentation/api/controllers/sync_controller.dart';
import 'package:whph/src/core/application/shared/models/websocket_request.dart';
import 'package:whph/src/core/application/features/sync/models/sync_data_dto.dart';

const int webSocketPort = 44040;

// Web socket server events
final streamController = StreamController<Map<String, dynamic>>.broadcast();
Stream<Map<String, dynamic>> get serverEvents => streamController.stream;

void startWebSocketServer() async {
  try {
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      webSocketPort,
    );

    if (kDebugMode) debugPrint('WebSocket Server starting on port $webSocketPort');

    // Handle incoming connections
    await for (HttpRequest req in server) {
      try {
        if (req.headers.value('upgrade')?.toLowerCase() == 'websocket') {
          final ws = await WebSocketTransformer.upgrade(req);

          ws.listen(
            (data) async {
              if (kDebugMode) debugPrint('Received message: $data');
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              if (kDebugMode) debugPrint('Connection error: $e');
              ws.close();
            },
            onDone: () {
              if (kDebugMode) debugPrint('Connection closed normally');
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
        if (kDebugMode) debugPrint('Request handling error: $e');
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('WebSocket server failed to start on port $webSocketPort: $e');
    rethrow;
  }
}

Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
  try {
    if (kDebugMode) debugPrint('Received message: $message');

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

      case 'sync':
        final syncData = parsedMessage.data;
        if (syncData == null) {
          throw FormatException('Sync message missing data');
        }

        final controller = SyncController();
        try {
          final response = await controller.sync(SyncDataDto.fromJson(syncData as Map<String, dynamic>));

          WebSocketMessage responseMessage = WebSocketMessage(type: 'sync_complete', data: {
            'syncDataDto': response.syncDataDto,
            'success': true,
            'timestamp': DateTime.now().toIso8601String()
          });
          socket.add(JsonMapper.serialize(responseMessage));

          // Add a small delay before closing the connection
          await Future.delayed(const Duration(milliseconds: 500));
          await socket.close();
        } catch (e) {
          WebSocketMessage errorMessage =
              WebSocketMessage(type: 'sync_error', data: {'success': false, 'message': e.toString()});
          socket.add(JsonMapper.serialize(errorMessage));
          await socket.close();
        }
        break;

      default:
        socket.add(JsonMapper.serialize(WebSocketMessage(type: 'error', data: {'message': 'Unknown message type'})));
        await socket.close();
        break;
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Error processing WebSocket message: $e');
    socket.add(JsonMapper.serialize(WebSocketMessage(type: 'error', data: {'message': e.toString()})));
    await socket.close();
    rethrow;
  }
}
