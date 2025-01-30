import 'dart:io';
import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/api/controllers/sync_controller.dart';
import 'package:whph/application/shared/models/websocket_request.dart';
import 'package:whph/application/features/sync/models/sync_data_dto.dart';

const int webSocketPort = 4040;

// Web socket server events
final streamController = StreamController<Map<String, dynamic>>.broadcast();
Stream<Map<String, dynamic>> get serverEvents => streamController.stream;

Future<void> _setupSocketPermissions() async {
  if (Platform.isLinux) {
    try {
      // Try to set socket options for non-root access
      await Process.run('sudo', ['setcap', 'cap_net_bind_service=+ep', Platform.resolvedExecutable]);
    } catch (e) {
      if (kDebugMode) {
        print('WARNING: Could not set socket permissions');
        print('You may need to run: sudo setcap cap_net_bind_service=+ep ${Platform.resolvedExecutable}');
      }
    }
  }
}

void startWebSocketServer() async {
  try {
    await _setupSocketPermissions();

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      webSocketPort,
    );

    if (kDebugMode) {
      print('DEBUG: WebSocket Server starting on port $webSocketPort');
    }

    // Handle incoming connections
    await for (HttpRequest req in server) {
      try {
        if (req.headers.value('upgrade')?.toLowerCase() == 'websocket') {
          final ws = await WebSocketTransformer.upgrade(req);
          if (kDebugMode) print('DEBUG: WebSocket connection established');

          ws.listen(
            (data) async {
              if (kDebugMode) print('DEBUG: Received message: $data');
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              if (kDebugMode) print('DEBUG: Connection error: $e');
              ws.close();
            },
            onDone: () {
              if (kDebugMode) print('DEBUG: Connection closed normally');
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
        if (kDebugMode) print('DEBUG: Request handling error: $e');
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('CRITICAL ERROR: WebSocket server failed to start');
      print('Error: $e');
    }
    rethrow;
  }
}

Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
  try {
    if (kDebugMode) print('DEBUG: Received message: $message');

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
  } catch (e, stack) {
    if (kDebugMode) {
      if (kDebugMode) print('ERROR: Error processing WebSocket message: $e');
      if (kDebugMode) print('DEBUG: Stack trace: $stack');
    }
    socket.add(JsonMapper.serialize(WebSocketMessage(type: 'error', data: {'message': e.toString()})));
    await socket.close();
    rethrow;
  }
}
