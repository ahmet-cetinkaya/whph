import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/src/core/application/shared/models/websocket_request.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

class NetworkUtils {
  static const int webSocketPort = 44040;
  static const Duration connectionTimeout = Duration(seconds: 2);

  static Future<String?> getLocalIpAddress() async {
    try {
      if (PlatformUtils.isMobile) {
        // Use NetworkInfo Plus for mobile devices
        final info = NetworkInfo();
        String? wifiIP = await info.getWifiIP();
        return wifiIP;
      } else {
        // Use NetworkInterface for desktop
        final interfaces = await NetworkInterface.list(
          includeLinkLocal: false,
          type: InternetAddressType.IPv4,
        );

        // Check the most probable interfaces first
        for (final interface in interfaces) {
          if (interface.name.toLowerCase().contains('wlan') ||
              interface.name.toLowerCase().contains('wi-fi') ||
              interface.name.toLowerCase().contains('eth')) {
            for (final addr in interface.addresses) {
              // Check for local network IPs (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
              if (_isValidLocalNetworkIP(addr.address)) {
                return addr.address;
              }
            }
          }
        }

        // If not found, check all interfaces
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (_isValidLocalNetworkIP(addr.address)) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      Logger.error('Failed to get local IP: $e');
    }
    return null;
  }

  static bool _isValidLocalNetworkIP(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    // 192.168.x.x
    if (parts[0] == '192' && parts[1] == '168') return true;

    // 10.x.x.x
    if (parts[0] == '10') return true;

    // 172.16-31.x.x
    if (parts[0] == '172') {
      int second = int.tryParse(parts[1]) ?? 0;
      if (second >= 16 && second <= 31) return true;
    }

    return false;
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
