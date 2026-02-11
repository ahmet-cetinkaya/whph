import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:acore/acore.dart';

enum TagType {
  label,
  context,
  project;

  String get value {
    switch (this) {
      case TagType.label:
        return 'label';
      case TagType.context:
        return 'context';
      case TagType.project:
        return 'project';
    }
  }

  static TagType fromString(String value) {
    return TagType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TagType.label,
    );
  }
}

@jsonSerializable
class Tag extends BaseEntity<String> {
  String name;
  bool isArchived;
  String? color;
  TagType type;

  Tag({
    required super.id,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
    required this.name,
    this.isArchived = false,
    this.color,
    this.type = TagType.label,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'name': name,
        'isArchived': isArchived,
        'color': color,
        'type': type.value,
      };

  factory Tag.fromJson(Map<String, dynamic> json) {
    // Handle type field that can be either String (from JSON) or int (from database)
    final dynamic typeValue = json['type'];
    TagType type = TagType.label;

    if (typeValue is int) {
      // Type is stored as int in database (enum index: 0=label, 1=context, 2=project)
      if (typeValue >= 0 && typeValue < TagType.values.length) {
        type = TagType.values[typeValue];
      }
    } else if (typeValue is String) {
      // Type is a String from JSON serialization
      type = TagType.fromString(typeValue);
    }

    return Tag(
      id: json['id'] as String,
      createdDate: DateTime.parse(json['createdDate'] as String),
      modifiedDate: json['modifiedDate'] != null ? DateTime.parse(json['modifiedDate'] as String) : null,
      deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
      name: json['name'] as String,
      isArchived: json['isArchived'] as bool? ?? false,
      color: json['color'] as String?,
      type: type,
    );
  }
}
