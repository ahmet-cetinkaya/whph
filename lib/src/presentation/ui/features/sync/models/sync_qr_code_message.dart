import 'package:dart_json_mapper/dart_json_mapper.dart';

@jsonSerializable
class SyncQrCodeMessage {
  final String localIP;
  final String deviceName;
  final String deviceId;
  final String platform; // 'desktop', 'android', 'ios'

  SyncQrCodeMessage({
    required this.localIP,
    required this.deviceName,
    required this.deviceId,
    required this.platform,
  });

  factory SyncQrCodeMessage.fromJson(Map<String, dynamic> json) {
    return SyncQrCodeMessage(
      localIP: json['localIP'] as String,
      deviceName: json['deviceName'] as String,
      deviceId: json['deviceId'] as String,
      platform: json['platform'] as String? ?? 'unknown', // Default for backward compatibility
    );
  }

  Map<String, dynamic> toJson() => {
        'localIP': localIP,
        'deviceName': deviceName,
        'deviceId': deviceId,
        'platform': platform,
      };

  /// Convert to CSV format: localIP,deviceName,deviceId,platform
  String toCsv() {
    return '$localIP,$deviceName,$deviceId,$platform';
  }

  /// Parse from CSV format: localIP,deviceName,deviceId,platform
  factory SyncQrCodeMessage.fromCsv(String csv) {
    final parts = csv.split(',');
    if (parts.length < 3) {
      throw ArgumentError('Invalid CSV format. Expected at least 3 parts separated by commas.');
    }

    return SyncQrCodeMessage(
      localIP: parts[0].trim(),
      deviceName: parts[1].trim(),
      deviceId: parts[2].trim(),
      platform: parts.length >= 4 ? parts[3].trim() : 'unknown', // Backward compatibility
    );
  }
}
