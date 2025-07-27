import 'package:dart_json_mapper/dart_json_mapper.dart';

@jsonSerializable
class SyncQrCodeMessage {
  final String localIP;
  final String deviceName;
  final String deviceId;

  SyncQrCodeMessage({
    required this.localIP,
    required this.deviceName,
    required this.deviceId,
  });

  factory SyncQrCodeMessage.fromJson(Map<String, dynamic> json) {
    return SyncQrCodeMessage(
      localIP: json['localIP'] as String,
      deviceName: json['deviceName'] as String,
      deviceId: json['deviceId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'localIP': localIP,
        'deviceName': deviceName,
        'deviceId': deviceId,
      };

  /// Convert to CSV format: localIP,deviceName,deviceId
  String toCsv() {
    return '$localIP,$deviceName,$deviceId';
  }

  /// Parse from CSV format: localIP,deviceName,deviceId
  factory SyncQrCodeMessage.fromCsv(String csv) {
    final parts = csv.split(',');
    if (parts.length != 3) {
      throw ArgumentError('Invalid CSV format. Expected 3 parts separated by commas.');
    }
    
    return SyncQrCodeMessage(
      localIP: parts[0].trim(),
      deviceName: parts[1].trim(),
      deviceId: parts[2].trim(),
    );
  }
}
