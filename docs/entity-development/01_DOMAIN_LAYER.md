# Phase 1: Domain Layer

## Overview

The domain layer defines your entity's structure, serialization, and
relationships. All entities follow the `BaseEntity<String>` pattern for UUID
primary keys.

## Entity Class Structure

**Location**: `lib/core/domain/features/<feature>/<entity_name>.dart`

### Template

```dart
import 'package:acore/domain/entities/base_entity.dart';
import 'package:dart_json_mapper/dart_json_mapper.dart' show JsonMapper, JsonSerializable;

@JsonSerializable()
class YourEntity extends BaseEntity<String> {
  final String field1;
  final String? nullableField;
  final double order;
  final bool isBuiltIn;

  YourEntity({
    required super.id,
    required super.createdDate,
    required super.modifiedDate,
    required this.field1,
    this.nullableField,
    required this.order,
    required this.isBuiltIn,
    super.deletedDate,
  });

  // copyWith with sentinel pattern
  static const _copyWithSentinel = Object();

  YourEntity copyWith({
    Object? field1 = _copyWithSentinel,
    Object? nullableField = _copyWithSentinel,
    Object? order = _copyWithSentinel,
    Object? isBuiltIn = _copyWithSentinel,
    super.id,
    super.createdDate,
    super.modifiedDate,
    super.deletedDate,
  }) => YourEntity(
    id: id == _copyWithSentinel ? this.id : id as String,
    createdDate: createdDate == _copyWithSentinel ? this.createdDate : createdDate as DateTime,
    modifiedDate: modifiedDate == _copyWithSentinel ? this.modifiedDate : modifiedDate as DateTime,
    deletedDate: deletedDate == _copyWithSentinel ? this.deletedDate : deletedDate as DateTime?,
    field1: field1 == _copyWithSentinel ? this.field1 : field1 as String,
    nullableField: nullableField == _copyWithSentinel ? this.nullableField : nullableField as String?,
    order: order == _copyWithSentinel ? this.order : order as double,
    isBuiltIn: isBuiltIn == _copyWithSentinel ? this.isBuiltIn : isBuiltIn as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdDate': createdDate.toIso8601String(),
    'modifiedDate': modifiedDate.toIso8601String(),
    if (deletedDate != null) 'deletedDate': deletedDate!.toIso8601String(),
    'field1': field1,
    'nullableField': nullableField,
    'order': order,
    'isBuiltIn': isBuiltIn,
  };

  factory YourEntity.fromJson(Map<String, dynamic> json) => YourEntity(
    id: json['id'] as String,
    createdDate: DateTime.parse(json['createdDate'] as String),
    modifiedDate: DateTime.parse(json['modifiedDate'] as String),
    deletedDate: json['deletedDate'] != null ? DateTime.parse(json['deletedDate'] as String) : null,
    field1: json['field1'] as String,
    nullableField: json['nullableField'] as String?,
    order: json['order'] as double,
    isBuiltIn: json['isBuiltIn'] as bool,
  );
}
```

### Key Conventions

- **Extend `BaseEntity<String>`**: UUID primary key
- **`@JsonSerializable()` annotation**: Required for mapper code generation
- **All fields `final`**: Ensures immutability
- **`deletedDate` optional**: Supports soft-delete pattern
- **Sentinel pattern in `copyWith`**: Distinguishes "field not provided" from
  "field set to null"

### Column Type Mapping

| Dart Type  | Drift Column     | Notes                              |
| ---------- | ---------------- | ---------------------------------- |
| `String`   | `TextColumn`     | Use `.nullable()` for optional     |
| `DateTime` | `DateTimeColumn` | Stored as INTEGER (Unix timestamp) |
| `double`   | `RealColumn`     | For floating-point values          |
| `int`      | `IntColumn`      | For integer values                 |
| `bool`     | `BoolColumn`     | Stored as INTEGER 0/1              |

## Constants File (Optional)

If your entity has built-in values or shared constants:

**Location**: `lib/core/domain/features/<feature>/<entity_name>_constants.dart`

```dart
class YourEntityConstants {
  // Built-in IDs (device-shared for sync)
  static const String builtinOneId = 'entity-builtin-one';
  static const String builtinTwoId = 'entity-builtin-two';

  // Default values
  static const String defaultColor = '9E9E9E';
  static const double defaultOrder = 0.0;

  // Helper functions
  static bool isSpecialId(String? id) => id == builtinOneId || id == builtinTwoId;
}
```

### When to Use Constants

- **Built-in entities**: Use fixed UUIDs so sync doesn't duplicate across
  devices
- **Default values**: Centralize configuration (colors, orders, limits)
- **Helper functions**: Common business logic checks

## Foreign Key Relationships

If your entity is referenced by another entity (e.g., Task has statusId):

**Location**: `lib/core/domain/features/<parent_entity>/<parent_entity>.dart`

```dart
class ParentEntity extends BaseEntity<String> {
  // ... existing fields
  final String? yourEntityId;  // ← Add nullable FK reference

  ParentEntity({
    // ...
    this.yourEntityId,
  });

  @override
  Map<String, dynamic> toJson() => {
    // ...
    'yourEntityId': yourEntityId,
  };

  factory ParentEntity.fromJson(Map<String, dynamic> json) => ParentEntity(
    // ...
    yourEntityId: json['yourEntityId'] as String?,
  );

  // copyWith update:
  static const _copyWithSentinel = Object();

  ParentEntity copyWith({
    Object? yourEntityId = _copyWithSentinel,
    // ...
  }) => ParentEntity(
    // ...
    yourEntityId: yourEntityId == _copyWithSentinel ? this.yourEntityId : yourEntityId as String?,
  );
}
```

### FK Best Practices

- **Make nullable initially**: Allows backfill in migration
- **Use consistent naming**: `<entity>Id` for the field
- **Update parent's logic**: Commands should handle the new FK

## Next Steps

After defining your entity class:

→ [Phase 2: Persistence Layer](./02_PERSISTENCE_LAYER.md)

---

**See also**: [Common Patterns](./08_COMMON_PATTERNS.md) for the BaseEntity and
sentinel copyWith patterns.
