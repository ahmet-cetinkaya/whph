import 'dart:io';
import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/main.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';

const int webSocketPort = 44040;

final streamController = StreamController<Map<String, dynamic>>.broadcast();
Stream<Map<String, dynamic>> get serverEvents => streamController.stream;

void startWebSocketServer() async {
  try {
    Logger.info('Attempting to start WebSocket server on port $webSocketPort...');

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      webSocketPort,
      shared: true,
    );

    Logger.info('WebSocket Server successfully started on port $webSocketPort');
    Logger.info('WebSocket Server listening on all IPv4 interfaces (0.0.0.0:$webSocketPort)');
    Logger.info('Ready to receive sync requests from other devices');

    await for (HttpRequest req in server) {
      try {
        if (req.headers.value('upgrade')?.toLowerCase() == 'websocket') {
          final ws = await WebSocketTransformer.upgrade(req);
          Logger.info(
              'WebSocket connection established from ${req.connectionInfo?.remoteAddress}:${req.connectionInfo?.remotePort}');

          ws.listen(
            (data) async {
              await _handleWebSocketMessage(data.toString(), ws);
            },
            onError: (e) {
              Logger.error('Connection error: $e');
              ws.close();
            },
            onDone: () {
              Logger.debug('Connection closed normally');
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
        Logger.error('Request handling error: $e');
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
        socket.add(JsonMapper.serialize(WebSocketMessage(
          type: 'test_response',
          data: {
            'success': true,
            'timestamp': DateTime.now().toIso8601String(),
          },
        )));
        break;

      case 'device_info':
        Logger.info('Processing device info request...');
        try {
          final deviceIdService = container.resolve<IDeviceIdService>();
          final deviceId = await deviceIdService.getDeviceId();
          final deviceName = await DeviceInfoHelper.getDeviceName();

          socket.add(JsonMapper.serialize(WebSocketMessage(
            type: 'device_info_response',
            data: {
              'success': true,
              'deviceId': deviceId,
              'deviceName': deviceName,
              'appName': 'WHPH',
              'appVersion': AppInfo.version,
              'platform': Platform.isAndroid
                  ? 'android'
                  : Platform.isIOS
                      ? 'ios'
                      : Platform.isLinux
                          ? 'linux'
                          : Platform.isWindows
                              ? 'windows'
                              : Platform.isMacOS
                                  ? 'macos'
                                  : 'unknown',
              'timestamp': DateTime.now().toIso8601String(),
            },
          )));
        } catch (e) {
          Logger.error('Failed to get device info: $e');
          socket.add(JsonMapper.serialize(WebSocketMessage(
            type: 'device_info_response',
            data: {
              'success': false,
              'error': e.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          )));
        }
        break;

      case 'connection_test':
        socket.add(JsonMapper.serialize(WebSocketMessage(
          type: 'connection_test_response',
          data: {
            'success': true,
            'timestamp': DateTime.now().toIso8601String(),
          },
        )));
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
