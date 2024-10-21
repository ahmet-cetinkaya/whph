import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

enum SettingValueType { string, int, double, bool }

@jsonSerializable
class Setting extends BaseEntity<String> {
  String key;
  String value;
  SettingValueType valueType;

  Setting(
      {required super.id,
      required super.createdDate,
      super.modifiedDate,
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
      default:
        throw Exception('Invalid SettingType');
    }
  }

  void mapFromInstance(Setting instance) {
    key = instance.key;
    value = instance.value;
    valueType = instance.valueType;
  }
}
