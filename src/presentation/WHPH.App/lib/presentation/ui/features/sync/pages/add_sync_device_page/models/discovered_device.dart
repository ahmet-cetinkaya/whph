/// Represents a discovered device on the network
class DiscoveredDevice {
  final String name;
  final String ipAddress;
  final int port;
  final DateTime lastSeen;
  final String deviceId;
  final String platform;
  final bool isAlreadyAdded;

  const DiscoveredDevice({
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
    required this.deviceId,
    required this.platform,
    this.isAlreadyAdded = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice && runtimeType == other.runtimeType && deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}
