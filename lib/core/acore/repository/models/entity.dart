abstract class Entity {
  String id;
  DateTime createdDate;
  DateTime? modifiedDate;

  Entity({
    required this.id,
    required this.createdDate,
    this.modifiedDate,
  });
}
