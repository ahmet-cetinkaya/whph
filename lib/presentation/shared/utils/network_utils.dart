import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:whph/application/shared/models/websocket_request.dart';

class NetworkUtils {
  static const int webSocketPort = 4040;
  static const Duration connectionTimeout = Duration(seconds: 2);

  static Future<String?> getLocalIpAddress() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
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
                if (kDebugMode) print('DEBUG: Found local IP: ${addr.address} on interface: ${interface.name}');
                return addr.address;
              }
            }
          }
        }

        // If not found, check all interfaces
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (_isValidLocalNetworkIP(addr.address)) {
              if (kDebugMode) print('DEBUG: Found fallback IP: ${addr.address} on interface: ${interface.name}');
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to get local IP: $e');
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
      } catch (e) {
        if (kDebugMode) print('DEBUG: Test message failed: $e');
      }

      await ws.close();
      return true;
    } catch (e) {
      if (kDebugMode) print('DEBUG: WebSocket connection failed: $e');
      return false;
    }
  }
}
