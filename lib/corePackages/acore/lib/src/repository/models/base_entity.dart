/// Base entity class providing common properties for all entities.
abstract class BaseEntity<TId> {
  BaseEntity({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
    this.deletedDate,
  });

  TId id;
  DateTime createdDate;
  DateTime? modifiedDate;
  DateTime? deletedDate;

  bool get isDeleted => deletedDate != null;
}
