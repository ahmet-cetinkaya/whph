abstract class BaseEntity<TId> {
  TId id;
  DateTime createdDate;
  DateTime? modifiedDate;

  BaseEntity({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}
