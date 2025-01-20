import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/repository/abstraction/i_repository.dart' as core;
import 'package:whph/core/acore/repository/models/base_entity.dart';

@jsonSerializable
class SyncData<T extends BaseEntity> {
  List<T> createSync = [];
  List<T> updateSync = [];
  List<T> deleteSync = [];

  SyncData({required this.createSync, required this.updateSync, required this.deleteSync});
}

abstract class IRepository<T extends BaseEntity<TId>, TId> extends core.IRepository<T, TId> {
  Future<SyncData<T>> getSyncData(DateTime lastSyncDate);
  Future<void> hardDeleteSoftDeleted(DateTime beforeDate);
}
