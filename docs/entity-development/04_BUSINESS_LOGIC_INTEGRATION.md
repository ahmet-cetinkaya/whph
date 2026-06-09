# Phase 4: Business Logic Integration (Optional)

## Overview

This phase covers integrating your entity into existing business logic. This
includes adding grouping dimensions, validation rules, or any behavioral changes
to existing features.

**When is this needed?**

- Your entity serves as a grouping dimension (like priority, status, tags)
- Your entity affects validation in existing commands
- Your entity changes how parent entities behave

## Grouping Dimension

If your entity can group parent entities (e.g., tasks grouped by status):

### Add to Sort Fields Enum

**Location**:
`lib/core/application/features/<feature>/models/<feature>_sort_fields.dart`

```dart
enum YourEntitySortFields {
  // ...
  yourNewField,  // ← Add
}
```

### Update Grouping Helper

**Location**:
`lib/core/application/features/<feature>/utils/<entity>_grouping_helper.dart`

```dart
String? getGroupName(ParentEntity entity, YourEntitySortFields sortField) {
  switch (sortField) {
    // ...
    case YourEntitySortFields.yourNewField:
      return entity.fieldValue;  // Return grouping key
  }
}

bool isGroupTranslatable(YourEntitySortFields sortField) {
  switch (sortField) {
    // ...
    case YourEntitySortFields.yourNewField:
      return false;  // IDs are not translation keys
      // OR: return true;  // If using localized keys
  }
}

bool isCrossColumnMovePersistable(YourEntitySortFields sortField) {
  switch (sortField) {
    // ...
    case YourEntitySortFields.yourNewField:
      return true;  // Drag updates the field
  }
}

List<String>? fixedColumnKeysFor(YourEntitySortFields sortField) {
  switch (sortField) {
    // ...
    case YourEntitySortFields.yourNewField:
      return null;  // Data-driven (columns from entity list)
      // OR: return ['key1', 'key2'];  // Fixed columns
  }
}

String? emptyGroupKeyFor(YourEntitySortFields sortField) {
  switch (sortField) {
    // ...
    case YourEntitySortFields.yourNewField:
      return null;  // No empty group needed
      // OR: return 'empty_key';  // Specific empty key
  }
}
```

### Grouping Helper Patterns

| Method                         | Purpose                          | Return Values                                  |
| ------------------------------ | -------------------------------- | ---------------------------------------------- |
| `getGroupName`                 | Extract grouping key from entity | `String?` key or `null`                        |
| `isGroupTranslatable`          | Can key be translated?           | `true` (use i18n) or `false` (raw data)        |
| `isCrossColumnMovePersistable` | Does drag update field?          | `true` or `false`                              |
| `fixedColumnKeysFor`           | Fixed or data-driven columns?    | `List<String>` (fixed) or `null` (data-driven) |
| `emptyGroupKeyFor`             | Key for ungrouped items          | `String` key or `null`                         |

### Data-Driven vs Fixed Columns

**Data-driven** (columns from entity list):

```dart
List<String>? fixedColumnKeysFor(YourEntitySortFields sortField) {
  case YourEntitySortFields.yourNewField:
    return null;  // UI loads entities and builds columns
}
```

**Fixed columns** (predefined):

```dart
List<String>? fixedColumnKeysFor(YourEntitySortFields sortField) {
  case YourEntitySortFields.yourNewField:
    return ['high', 'medium', 'low'];  // Always these columns
}
```

## Validation Rules

If your entity adds validation to existing commands:

**Location**:
`lib/core/application/features/<parent_feature>/commands/save_<parent>_command.dart`

```dart
class SaveParentCommandHandler extends IRequestHandler<SaveParentCommand, ParentEntity> {
  @override
  Future<ParentEntity> call(SaveParentCommand request) async {
    // ... existing logic

    // New validation based on your entity
    if (request.yourEntityId != null) {
      final relatedEntity = await yourEntityRepository.getById(request.yourEntityId!);
      if (relatedEntity == null) {
        throw Exception('Related entity not found');
      }

      if (relatedEntity.isBuiltIn && !relatedEntity.isActive) {
        throw Exception('Cannot use inactive built-in entity');
      }
    }

    // ... save logic
  }
}
```

## Board/Group Creation Handler

If your entity is a grouping dimension, add it to the group creation handler:

**Location**:
`lib/presentation/ui/features/tasks/utils/task_group_creation_handler.dart` (or
equivalent)

```dart
TaskDraft? draftForGroup({
  required String groupKey,
  required YourEntitySortFields groupField,
  required TaskGroupCreationInput input,
}) {
  switch (groupField) {
    // ...
    case YourEntitySortFields.yourNewField:
      return TaskDraft(yourEntityField: groupKey);  // For "add to group"
  }
}
```

## Business Rules in Commands

If your entity affects parent entity behavior:

**Location**:
`lib/core/application/features/<parent_feature>/commands/save_<parent>_command.dart`

```dart
class SaveParentCommandHandler extends IRequestHandler<SaveParentCommand, ParentEntity> {
  @override
  Future<ParentEntity> call(SaveParentCommand request) async {
    // ... fetch existing entity

    // Apply business rule based on your entity
    if (request.yourEntityId != null) {
      final statusEntity = await yourEntityRepository.getById(request.yourEntityId!);

      // Example: done status sets completedAt
      if (statusEntity?.isDoneStatus == true && parent.completedAt == null) {
        parent.completedAt = DateTime.now().toUtc();
      }

      // Example: clears completedAt if not done
      if (statusEntity?.isDoneStatus == false) {
        parent.completedAt = null;
      }
    }

    // ... save logic
  }
}
```

## Next Steps

After business logic integration:

→ [Phase 5: Sync Integration](./05_SYNC_INTEGRATION.md) (recommended)

→ [Phase 6: UI Components](./06_UI_COMPONENTS.md) (optional)

---

**See also**: [Common Patterns](./08_COMMON_PATTERNS.md) for data-driven
grouping patterns.
