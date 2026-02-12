import 'package:dart_json_mapper/dart_json_mapper.dart';

@jsonSerializable
class SyncQrCodeMessage {
  final String localIP;
  final String deviceName;
  final String deviceId;
  final String platform; // 'desktop', 'android', 'ios'
  final List<String>? ipAddresses; // Multiple IP addresses for enhanced discovery
  final int port; // Port number for connection

  SyncQrCodeMessage({
    required this.localIP,
    required this.deviceName,
    required this.deviceId,
    required this.platform,
    this.ipAddresses,
    this.port = 44040, // Default WebSocket port
  });

  factory SyncQrCodeMessage.fromJson(Map<String, dynamic> json) {
    return SyncQrCodeMessage(
      localIP: json['localIP'] as String,
      deviceName: json['deviceName'] as String,
      deviceId: json['deviceId'] as String,
      platform: json['platform'] as String? ?? 'unknown', // Default for backward compatibility
      ipAddresses: (json['ipAddresses'] as List<dynamic>?)?.cast<String>(),
      port: json['port'] as int? ?? 44040, // Default port for backward compatibility
    );
  }

  Map<String, dynamic> toJson() => {
        'localIP': localIP,
        'deviceName': deviceName,
        'deviceId': deviceId,
        'platform': platform,
        if (ipAddresses != null) 'ipAddresses': ipAddresses,
        'port': port,
      };

  /// Convert to CSV format: localIP,deviceName,deviceId,platform,port,ipAddresses...
  String toCsv() {
    final baseInfo = '$localIP,$deviceName,$deviceId,$platform,$port';
    if (ipAddresses != null && ipAddresses!.isNotEmpty) {
      return '$baseInfo,${ipAddresses!.join(';')}';
    }
    return baseInfo;
  }

  /// Parse from CSV format: localIP,deviceName,deviceId,platform[,port[,ipAddresses]]
  factory SyncQrCodeMessage.fromCsv(String csv) {
    final parts = csv.split(',');
    if (parts.length < 3) {
      throw ArgumentError('Invalid CSV format. Expected at least 3 parts separated by commas.');
    }

    List<String>? ipAddresses;
    if (parts.length >= 6) {
      // Multiple IP addresses separated by semicolons
      ipAddresses = parts[5].split(';').map((ip) => ip.trim()).where((ip) => ip.isNotEmpty).toList();
    }

    return SyncQrCodeMessage(
      localIP: parts[0].trim(),
      deviceName: parts[1].trim(),
      deviceId: parts[2].trim(),
      platform: parts.length >= 4 ? parts[3].trim() : 'unknown', // Backward compatibility
      port: parts.length >= 5 ? int.tryParse(parts[4].trim()) ?? 44040 : 44040,
      ipAddresses: ipAddresses,
    );
  }

  /// Get all available IP addresses for connection attempts
  /// Returns ipAddresses if available, otherwise falls back to localIP
  List<String> get allIPAddresses {
    if (ipAddresses != null && ipAddresses!.isNotEmpty) {
      return ipAddresses!;
    }
    return [localIP];
  }
}
