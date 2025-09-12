import 'dart:io';

/// Service interface for discovering and managing network interfaces across platforms
abstract class INetworkInterfaceService {
  /// Get all available local IP addresses from active network interfaces
  /// Excludes loopback and invalid addresses
  Future<List<String>> getLocalIPAddresses();

  /// Get detailed information about active network interfaces
  Future<List<NetworkInterfaceInfo>> getActiveNetworkInterfaces();

  /// Check if an IP address is valid for local network communication
  bool isValidLocalIPAddress(String ipAddress);

  /// Get preferred IP addresses sorted by connection quality/type
  /// WiFi and Ethernet interfaces are preferred over others
  Future<List<String>> getPreferredIPAddresses();
}

/// Information about a network interface
class NetworkInterfaceInfo {
  final String name;
  final String ipAddress;
  final InternetAddressType addressType;
  final bool isWiFi;
  final bool isEthernet;
  final int priority; // Higher number = higher priority

  const NetworkInterfaceInfo({
    required this.name,
    required this.ipAddress,
    required this.addressType,
    required this.isWiFi,
    required this.isEthernet,
    required this.priority,
  });

  @override
  String toString() => 'NetworkInterfaceInfo(name: $name, ip: $ipAddress, wifi: $isWiFi, ethernet: $isEthernet, priority: $priority)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkInterfaceInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          ipAddress == other.ipAddress;

  @override
  int get hashCode => Object.hash(name, ipAddress);
}