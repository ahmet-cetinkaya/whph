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
}
