import 'package:dart_json_mapper/dart_json_mapper.dart';

@jsonSerializable
class WebSocketMessage {
  final String type;
  final dynamic data;

  WebSocketMessage({required this.type, required this.data});
}
