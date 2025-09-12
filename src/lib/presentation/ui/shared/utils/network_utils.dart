import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/main.dart';

class NetworkUtils {
  static const int webSocketPort = 44040;
  static const Duration connectionTimeout = Duration(seconds: 2);

  /// Get primary local IP address (backward compatibility)
  static Future<String?> getLocalIpAddress() async {
    final addresses = await getLocalIpAddresses();
    return addresses.isNotEmpty ? addresses.first : null;
  }

  /// Get all local IP addresses from available network interfaces
  /// Delegates to INetworkInterfaceService to avoid code duplication
  static Future<List<String>> getLocalIpAddresses() async {
    try {
      final networkService = container.resolve<INetworkInterfaceService>();
      return await networkService.getLocalIPAddresses();
    } catch (e) {
      Logger.error('Failed to get local IP addresses via service: $e');
      return [];
    }
  }

  static Future<bool> testWebSocketConnection(String host, {Duration? timeout}) async {
    try {
      Logger.debug('🔍 Testing WebSocket connectivity to $host:$webSocketPort...');
      final wsUrl = 'ws://$host:$webSocketPort';
      final ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 5));

      // Send a test sync message
      try {
        final testMessage = WebSocketMessage(
          type: 'test',
          data: {'timestamp': DateTime.now().toIso8601String()},
        );
        ws.add(JsonMapper.serialize(testMessage));

        await ws
            .timeout(
              const Duration(seconds: 2),
              onTimeout: (_) => throw TimeoutException('No response received'),
            )
            .first;
        Logger.debug('✅ WebSocket connectivity test passed for $host:$webSocketPort');
      } catch (e) {
        Logger.debug('⚠️ Test message failed: $e');
      }

      await ws.close();
      return true;
    } catch (e) {
      Logger.debug('❌ WebSocket connection failed to $host:$webSocketPort: $e');
      return false;
    }
  }

  /// Test network connectivity with simple socket connection
  static Future<bool> testPortConnectivity(String host, {int port = webSocketPort}) async {
    try {
      Logger.debug('🔍 Testing port connectivity to $host:$port...');
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      await socket.close();
      Logger.debug('✅ Port connectivity test passed for $host:$port');
      return true;
    } catch (e) {
      Logger.debug('❌ Port connectivity failed to $host:$port: $e');
      return false;
    }
  }
}
