import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

enum SettingValueType { string, int, double, bool, json }

@jsonSerializable
class Setting extends BaseEntity<String> {
  String key;
  String value;
  SettingValueType valueType;

  Setting(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
      super.deletedDate,
      required this.key,
      required this.value,
      required this.valueType});

  T getValue<T>() {
    switch (valueType) {
      case SettingValueType.string:
        return value as T;
      case SettingValueType.int:
        return int.parse(value) as T;
      case SettingValueType.double:
        return double.parse(value) as T;
      case SettingValueType.bool:
        return (value == 'true') as T;
      case SettingValueType.json:
        // For JSON, just return the string value since the caller needs to parse it
        return value as T;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'key': key,
        'value': value,
        'valueType': valueType.toString(),
      };

  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      key: json['key'] as String,
      value: json['value'] as String,
      valueType: SettingValueType.values.firstWhere((e) => e.toString() == json['valueType']),
    );
  }
}
