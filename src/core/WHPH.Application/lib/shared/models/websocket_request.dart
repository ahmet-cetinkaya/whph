import 'package:dart_json_mapper/dart_json_mapper.dart';

@jsonSerializable
class WebSocketMessage {
  final String type;
  final dynamic data;

  WebSocketMessage({required this.type, required this.data});

  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
      };

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      data: json['data'],
    );
  }
}
