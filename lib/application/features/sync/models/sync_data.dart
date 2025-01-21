import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class SyncData<T extends BaseEntity> {
  List<T> createSync = [];
  List<T> updateSync = [];
  List<T> deleteSync = [];

  SyncData({
    required this.createSync,
    required this.updateSync,
    required this.deleteSync,
  });

  Map<String, dynamic> toJson() => {
        'createSync': createSync,
        'updateSync': updateSync,
        'deleteSync': deleteSync,
      };

  factory SyncData.fromJson(Map<String, dynamic> json, Type type) {
    return SyncData(
      createSync: (json['createSync'] as List)
          .map((e) => JsonMapper.deserialize<T>(e))
          .whereType<T>() // Filter out null values
          .toList(),
      updateSync: (json['updateSync'] as List).map((e) => JsonMapper.deserialize<T>(e)).whereType<T>().toList(),
      deleteSync: (json['deleteSync'] as List).map((e) => JsonMapper.deserialize<T>(e)).whereType<T>().toList(),
    );
  }
}
