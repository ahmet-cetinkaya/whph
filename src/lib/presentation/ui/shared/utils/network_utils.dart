import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:whph/corePackages/acore/lib/acore.dart' show PlatformUtils;
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/shared/utils/logger.dart';

class NetworkUtils {
  static const int webSocketPort = 44040;
  static const Duration connectionTimeout = Duration(seconds: 2);

  /// Get primary local IP address (backward compatibility)
  static Future<String?> getLocalIpAddress() async {
    final addresses = await getLocalIpAddresses();
    return addresses.isNotEmpty ? addresses.first : null;
  }

  /// Get all local IP addresses from available network interfaces
  static Future<List<String>> getLocalIpAddresses() async {
    final List<String> addresses = [];
    
    try {
      if (PlatformUtils.isMobile) {
        // Use NetworkInfo Plus for mobile devices
        final info = NetworkInfo();
        String? wifiIP = await info.getWifiIP();
        if (wifiIP != null && _isValidLocalNetworkIP(wifiIP)) {
          addresses.add(wifiIP);
        }
      }
      
      // For all platforms, also use NetworkInterface for comprehensive detection
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      // Collect all valid local network IPs with priority ordering
      final prioritizedIPs = <String, int>{};

      for (final interface in interfaces) {
        final lowerName = interface.name.toLowerCase();
        int priority = 50; // Default priority

        // Assign priority based on interface type
        if (lowerName.contains('eth') || lowerName.contains('ethernet')) {
          priority = 95; // Highest for Ethernet
        } else if (lowerName.contains('wlan') || lowerName.contains('wi-fi') || lowerName.contains('wifi')) {
          priority = 90; // High for WiFi
        }

        for (final addr in interface.addresses) {
          if (_isValidLocalNetworkIP(addr.address)) {
            // Boost priority for common local network ranges
            int finalPriority = priority;
            if (addr.address.startsWith('192.168.')) {
              finalPriority += 10;
            } else if (addr.address.startsWith('10.')) {
              finalPriority += 5;
            }

            prioritizedIPs[addr.address] = finalPriority;
          }
        }
      }

      // Sort by priority and add to addresses list
      final sortedEntries = prioritizedIPs.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedEntries) {
        if (!addresses.contains(entry.key)) {
          addresses.add(entry.key);
        }
      }

      Logger.debug('Found ${addresses.length} local network addresses: ${addresses.join(', ')}');
    } catch (e) {
      Logger.error('Failed to get local IP addresses: $e');
    }
    
    return addresses;
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

  /// Test multiple IP addresses concurrently and return successful ones
  static Future<List<String>> testMultipleAddresses(
    List<String> ipAddresses, {
    int port = webSocketPort,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (ipAddresses.isEmpty) return [];

    Logger.debug('Testing connectivity to ${ipAddresses.length} addresses concurrently');
    
    final futures = ipAddresses.map((ip) => _testSingleAddress(ip, port, timeout)).toList();
    
    try {
      final results = await Future.wait(futures);
      final successful = <String>[];
      
      for (int i = 0; i < results.length; i++) {
        if (results[i]) {
          successful.add(ipAddresses[i]);
        }
      }
      
      Logger.debug('Connectivity test completed: ${successful.length}/${ipAddresses.length} addresses reachable');
      return successful;
    } catch (e) {
      Logger.error('Error during multi-address connectivity testing: $e');
      return [];
    }
  }

  /// Test single address connectivity (internal helper)
  static Future<bool> _testSingleAddress(String ip, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
