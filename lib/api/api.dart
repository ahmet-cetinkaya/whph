import 'dart:io';
import 'dart:convert';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:whph/api/controllers/sync_controller.dart';
import 'package:whph/application/features/shared/models/websocket_request.dart';
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

Future<void> _handleWebSocketMessage(message, WebSocket socket) async {
  if (kDebugMode) print('Received from client: $message');

  WebSocketMessage? parsedMessage = JsonMapper.deserialize<WebSocketMessage>(message);
  if (parsedMessage == null) throw Exception('Error parsing JSON data: $message');

  switch (parsedMessage.type) {
    case 'sync':
      var controller = SyncController();
      var syncDataDto = SyncDataDto.fromJson(parsedMessage.data);
      var response = await controller.sync(syncDataDto);

      if (kDebugMode) print('Sending response: ${JsonMapper.serialize(response)}');
      WebSocketMessage responseMessage = WebSocketMessage(type: 'sync', data: response);
      socket.add(JsonMapper.serialize(responseMessage));
      break;

    default:
      socket.add(jsonEncode({'error': 'Unknown message type'}));
      throw Exception('Unknown message type');
  }
}
