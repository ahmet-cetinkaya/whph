import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

@jsonSerializable
class TaskStatus extends BaseEntity<String> {
  /// Display name. Empty for un-renamed built-ins, which are resolved to a
  /// localized label at display time. Becomes a user-owned literal after rename.
  String name;

  /// Optional hex color for the status column.
  String? color;

  /// Column/group order.
  double order;

  /// Built-in statuses (todo & done) cannot be deleted.
  bool isBuiltIn;

  /// Exactly one status carries this flag; it maps to [Task.completedAt].
  bool isDoneStatus;

  TaskStatus({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.name,
    this.color,
    this.order = 0.0,
    this.isBuiltIn = false,
    this.isDoneStatus = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'name': name,
        'color': color,
        'order': order,
        'isBuiltIn': isBuiltIn,
        'isDoneStatus': isDoneStatus,
      };

  factory TaskStatus.fromJson(Map<String, dynamic> json) {
    try {
      final idValue = json['id'];
      if (idValue == null || idValue is! String) {
        throw FormatException('Missing or invalid id field');
      }

      final createdDateValue = json['createdDate'];
      if (createdDateValue == null || createdDateValue is! String) {
        throw FormatException('Missing or invalid createdDate field');
      }

      double order = 0.0;
      final orderValue = json['order'];
      if (orderValue is num) {
        order = orderValue.toDouble();
      }

      final modifiedDate = json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null;
      final deletedDate = json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null;

      return TaskStatus(
        id: idValue,
        createdDate: DateTime.parse(createdDateValue),
        modifiedDate: modifiedDate,
        deletedDate: deletedDate,
        name: json['name'] as String? ?? '',
        color: json['color'] as String?,
        order: order,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        isDoneStatus: json['isDoneStatus'] as bool? ?? false,
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Failed to parse TaskStatus: ${e.toString()}');
    }
  }
}
