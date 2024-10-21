import 'package:dart_json_mapper/dart_json_mapper.dart';

@jsonSerializable
class SyncQrCodeMessage {
  final String localIP;
  final String deviceName;

  SyncQrCodeMessage({required this.localIP, required this.deviceName});
}
