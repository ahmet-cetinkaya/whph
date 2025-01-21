import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/api/controllers/sync_controller.dart';
import 'package:whph/application/shared/models/websocket_request.dart';
import 'package:whph/application/features/sync/models/sync_data_dto.dart';

void startWebSocketServer() async {
  var url = Uri(scheme: 'ws', host: '0.0.0.0', port: 4040);
  var server = await HttpServer.bind(url.host, url.port);
  if (kDebugMode) print('WebSocket listening on ${url.scheme}://${url.host}:${url.port}');

  await for (HttpRequest request in server) {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('WebSocket connections only.')
        ..close();
    }

    WebSocket socket = await WebSocketTransformer.upgrade(request);
    if (kDebugMode) print('WebSocket client connected from: ${request.connectionInfo?.remoteAddress}');

    socket.listen((message) async {
      await _handleWebSocketMessage(message, socket);
    }, onError: (error) {
      throw Exception('WebSocket error: $error');
    }, onDone: () {
      if (kDebugMode) print('WebSocket connection closed');
    });
  }
}

Future<void> _handleWebSocketMessage(String message, WebSocket socket) async {
  try {
    if (kDebugMode) print('Parsing WebSocket message: ${message.replaceAll(RegExp(r'\s+'), '')}');

    WebSocketMessage? parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
    if (parsedMessage == null) {
      throw FormatException('Error parsing WebSocket message');
    }

    switch (parsedMessage.type) {
      case 'sync':
        var syncData = parsedMessage.data;
        if (syncData == null) {
          throw FormatException('Sync message missing data');
        }

        var controller = SyncController();
        try {
          var response = await controller.sync(SyncDataDto.fromJson(syncData as Map<String, dynamic>));

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
      print('Error processing WebSocket message: $e');
      print('Stack trace: $stack');
    }
    socket.add(JsonMapper.serialize(WebSocketMessage(type: 'error', data: {'message': e.toString()})));
    await socket.close();
    rethrow;
  }
}
