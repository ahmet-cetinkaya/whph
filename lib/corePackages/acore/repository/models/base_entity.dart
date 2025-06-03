import 'package:dart_json_mapper/dart_json_mapper.dart';

@jsonSerializable
abstract class BaseEntity<TId> {
  TId id;
  DateTime createdDate;
  DateTime? modifiedDate;
  DateTime? deletedDate;

  BaseEntity({required this.id, required this.createdDate, this.modifiedDate, this.deletedDate});

  bool get isDeleted => deletedDate != null;
}
