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
                // Parse capabilities if present
                DeviceCapabilities? capabilities;
                if (data['capabilities'] != null) {
                  capabilities = DeviceCapabilities.fromJson(
                    data['capabilities'] as Map<String, dynamic>
                  );
                }

                // Parse server info if present
                ServerInfo? serverInfo;
                if (data['serverInfo'] != null) {
                  serverInfo = ServerInfo.fromJson(
                    data['serverInfo'] as Map<String, dynamic>
                  );
                }

                final deviceInfo = DeviceInfo(
                  deviceId: data['deviceId'] as String,
                  deviceName: data['deviceName'] as String,
                  appName: data['appName'] as String? ?? 'WHPH',
                  platform: data['platform'] as String? ?? 'unknown',
                  ipAddress: ipAddress,
                  port: port,
                  capabilities: capabilities,
                  serverInfo: serverInfo,
                );

                Logger.info('✅ Device handshake successful: ${deviceInfo.deviceName} (${deviceInfo.deviceId}) - Capabilities: ${deviceInfo.capabilitiesText}');
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

/// Device capabilities for sync operations
class DeviceCapabilities {
  final bool canActAsServer;
  final bool canActAsClient;
  final List<String> supportedModes;
  final List<String> supportedOperations;

  const DeviceCapabilities({
    this.canActAsServer = false,
    this.canActAsClient = false,
    this.supportedModes = const [],
    this.supportedOperations = const [],
  });

  factory DeviceCapabilities.fromJson(Map<String, dynamic> json) {
    return DeviceCapabilities(
      canActAsServer: json['canActAsServer'] as bool? ?? false,
      canActAsClient: json['canActAsClient'] as bool? ?? false,
      supportedModes: (json['supportedModes'] as List<dynamic>?)
          ?.cast<String>() ?? const [],
      supportedOperations: (json['supportedOperations'] as List<dynamic>?)
          ?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canActAsServer': canActAsServer,
      'canActAsClient': canActAsClient,
      'supportedModes': supportedModes,
      'supportedOperations': supportedOperations,
    };
  }

  @override
  String toString() => 'DeviceCapabilities(server: $canActAsServer, client: $canActAsClient, modes: $supportedModes)';
}

/// Server information for active servers
class ServerInfo {
  final bool isServerActive;
  final int serverPort;
  final int activeConnections;

  const ServerInfo({
    required this.isServerActive,
    required this.serverPort,
    this.activeConnections = 0,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      isServerActive: json['isServerActive'] as bool? ?? false,
      serverPort: json['serverPort'] as int? ?? 44040,
      activeConnections: json['activeConnections'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isServerActive': isServerActive,
      'serverPort': serverPort,
      'activeConnections': activeConnections,
    };
  }

  @override
  String toString() => 'ServerInfo(active: $isServerActive, port: $serverPort, connections: $activeConnections)';
}

/// Information about a discovered WHPH device with enhanced capabilities
class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String appName;
  final String platform;
  final String ipAddress;
  final int port;
  final DateTime discoveredAt;
  final DeviceCapabilities? capabilities;
  final ServerInfo? serverInfo;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.appName,
    required this.platform,
    required this.ipAddress,
    required this.port,
    DateTime? discoveredAt,
    this.capabilities,
    this.serverInfo,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  /// Check if this device can act as a server
  bool get canActAsServer => capabilities?.canActAsServer ?? false;

  /// Check if this device can act as a client
  bool get canActAsClient => capabilities?.canActAsClient ?? false;

  /// Check if server is currently active
  bool get isServerActive => serverInfo?.isServerActive ?? false;

  /// Get display text for device capabilities
  String get capabilitiesText {
    final caps = <String>[];
    if (canActAsServer) caps.add('Server');
    if (canActAsClient) caps.add('Client');
    return caps.isEmpty ? 'Unknown' : caps.join(' & ');
  }

  @override
  String toString() => 'DeviceInfo(name: $deviceName, id: $deviceId, platform: $platform, address: $ipAddress:$port, capabilities: $capabilitiesText)';

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
