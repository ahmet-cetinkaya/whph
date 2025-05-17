import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';

@jsonSerializable
abstract class BaseEntity<TId> {
  TId id;
  DateTime createdDate;
  DateTime? modifiedDate;
  DateTime? deletedDate;

  BaseEntity({required this.id, required this.createdDate, this.modifiedDate, this.deletedDate});

  /// Returns the createdDate value from entity in local time zone
  DateTime getLocalCreatedDate() {
    return DateTimeHelper.toLocalDateTime(createdDate);
  }

  /// Returns the modifiedDate value from entity in local time zone
  DateTime? getLocalModifiedDate() {
    return modifiedDate != null ? DateTimeHelper.toLocalDateTime(modifiedDate) : null;
  }

  /// Returns the deletedDate value from entity in local time zone
  DateTime? getLocalDeletedDate() {
    return deletedDate != null ? DateTimeHelper.toLocalDateTime(deletedDate) : null;
  }
}
