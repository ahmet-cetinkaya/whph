import 'dart:async';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Service for performing device handshake to get device information
class DeviceHandshakeService {
  /// Performs handshake with a device to get its information
  /// Returns null if the device is not a WHPH instance or handshake fails
  Future<DeviceInfo?> getDeviceInfo(String ipAddress, int port) async {
    WebSocketChannel? channel;
    StreamSubscription? subscription;
    try {
      Logger.info('🤝 Attempting handshake with device at $ipAddress:$port');

      // Connect to the device
      final uri = Uri.parse('ws://$ipAddress:$port');
      channel = WebSocketChannel.connect(uri);

      // Set up a completer for the response
      final completer = Completer<DeviceInfo?>();

      // Listen for messages
      subscription = channel.stream.listen(
        (message) {
          try {
            Logger.debug('📨 Received handshake response: $message');
            final response = JsonMapper.deserialize<WebSocketMessage>(message.toString());

            if (response?.type == 'device_info_response') {
              final data = response!.data as Map<String, dynamic>;

              if (data['success'] == true) {
                final deviceInfo = DeviceInfo(
                  deviceId: data['deviceId'] as String,
                  deviceName: data['deviceName'] as String,
                  appName: data['appName'] as String? ?? 'WHPH',
                  platform: data['platform'] as String? ?? 'unknown',
                  ipAddress: ipAddress,
                  port: port,
                );

                Logger.info('✅ Device handshake successful: ${deviceInfo.deviceName} (${deviceInfo.deviceId})');
                if (!completer.isCompleted) {
                  completer.complete(deviceInfo);
                }
              } else {
                Logger.warning('❌ Device handshake failed: ${data['error']}');
                if (!completer.isCompleted) {
                  completer.complete(null);
                }
              }
            } else if (response?.type == 'error') {
              Logger.warning('❌ Device returned error during handshake');
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            }
          } catch (e) {
            Logger.error('❌ Failed to parse handshake response: $e');
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        },
        onError: (error) {
          Logger.error('❌ WebSocket error during handshake: $error');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
        onDone: () {
          Logger.debug('🔚 Handshake WebSocket connection closed');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      // Send device info request
      final request = WebSocketMessage(
        type: 'device_info',
        data: {'timestamp': DateTime.now().toIso8601String()},
      );

      channel.sink.add(JsonMapper.serialize(request));
      Logger.debug('📤 Sent device info request to $ipAddress:$port');

      // Wait for response with timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          Logger.warning('⏰ Device handshake timed out for $ipAddress:$port');
          return null;
        },
      );

      return result;
    } catch (e) {
      Logger.error('❌ Device handshake failed for $ipAddress:$port - $e');
      return null;
    } finally {
      // Clean up subscription
      try {
        await subscription?.cancel();
      } catch (e) {
        Logger.debug('Warning: Failed to cancel subscription during cleanup: $e');
      }

      // Clean up WebSocket
      try {
        await channel?.sink.close();
      } catch (e) {
        Logger.debug('Warning: Failed to close WebSocket during cleanup: $e');
      }
    }
  }

  /// Tests if a device is reachable and is a WHPH instance
  Future<bool> isWHPHDevice(String ipAddress, int port) async {
    final deviceInfo = await getDeviceInfo(ipAddress, port);
    return deviceInfo != null && deviceInfo.appName == 'WHPH';
  }
}

/// Information about a discovered WHPH device
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String appName;
  final String platform;
  final String ipAddress;
  final int port;
  final DateTime discoveredAt;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.appName,
    required this.platform,
    required this.ipAddress,
    required this.port,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  @override
  String toString() => 'DeviceInfo(name: $deviceName, id: $deviceId, platform: $platform, address: $ipAddress:$port)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          ipAddress == other.ipAddress &&
          port == other.port;

  @override
  int get hashCode => Object.hash(deviceId, ipAddress, port);
}
