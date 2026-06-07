# Common Patterns & Conventions

## Overview

This document summarizes established patterns and conventions used throughout
the WHPH codebase. Follow these to maintain consistency.

## 1. BaseEntity Pattern

All entities extend `BaseEntity<String>` for UUID primary keys:

```dart
class YourEntity extends BaseEntity<String> {
  // id, createdDate, modifiedDate, deletedDate inherited
}
```

**Benefits**:

- Consistent primary key type (UUID)
- Soft-delete support via `deletedDate`
- Audit trail via `createdDate`/`modifiedDate`

## 2. Sentinel copyWith Pattern

Distinguishes "field not provided" from "field set to null":

```dart
static const _copyWithSentinel = Object();

YourEntity copyWith({
  Object? nullableField = _copyWithSentinel,
}) => YourEntity(
  nullableField: nullableField == _copyWithSentinel
      ? this.nullableField
      : nullableField as String?,
);
```

**Why needed**: Without sentinel, can't tell if caller wanted to set field to
`null` or just didn't provide it.

**Usage**:

```dart
// Field not provided (keep original)
entity.copyWith()  // nullableField stays same

// Set to null (clear value)
entity.copyWith(nullableField: null)  // nullableField becomes null

// Set to value (update value)
entity.copyWith(nullableField: 'new')  // nullableField becomes 'new'
```

## 3. Idempotent Migrations

Make migrations re-runnable with guards:

| Operation    | Guard Pattern                                                         |
| ------------ | --------------------------------------------------------------------- |
| Create table | `CREATE TABLE IF NOT EXISTS`                                          |
| Add column   | `SELECT COUNT(*) FROM pragma_table_info("table") WHERE name="column"` |
| Insert data  | `SELECT COUNT(*) FROM table WHERE id IN (...)`                        |
| Update data  | `WHERE ... IS NULL` (avoid overwriting)                               |

**Example**:

```dart
// Table creation
await db.customStatement('CREATE TABLE IF NOT EXISTS table_name (...)');

// Column addition
final hasColumn = await db.customSelect(
  'SELECT COUNT(*) FROM pragma_table_info("table") WHERE name="column"'
).getSingle();
if (hasColumn.data['count'] == 0) {
  await m.addColumn(schema.table, schema.table.column);
}

// Data insertion
final existing = await db.customSelect(
  'SELECT COUNT(*) FROM table WHERE id IN (?)'
).getSingle();
if (existing.data['count'] == 0) {
  await db.customStatement('INSERT INTO table (...) VALUES (...)');
}
```

## 4. Const Query Constructors

Make query constructors `const` for compiler optimizations:

```dart
class GetListQuery extends IRequest<List<Item>> {
  const GetListQuery();  // ← const
}
```

**Why**: Allows compiler to optimize; avoids lint warnings.

## 5. Nullable Foreign Keys

When adding FKs to existing tables, make them nullable initially:

```dart
TextColumn get yourEntityId => text().nullable()();
```

**Why**: Migration backfills existing rows, so nulls are temporary. Allows safe
schema evolution.

## 6. Repository Test Constructors

Provide `.withDatabase` constructors for testing:

```dart
class DriftYourEntityRepository {
  DriftYourEntityRepository(super.database);

  DriftYourEntityRepository.withDatabase(AppDatabase database) : super(database);
}
```

**Why**: Tests can inject mock/test database instances.

## 7. Ordering Pattern

Use `_orderStep = 1000.0` for persistent reordering:

```dart
void _onReorder(int oldIndex, int newIndex) {
  // Recalculate: order = (i + 1) * _orderStep
  // Result: 1000, 2000, 3000, 4000, ...
}
```

**Benefits**:

- Allows inserting items between existing ones
- No need to re-order all items
- Predictable order values

**Example**: To insert between 2000 and 3000, use 2500.

## 8. Built-in Entity Guards

Protect built-in entities from deletion/mutation:

```dart
if (entity.isBuiltIn) {
  throw Exception('Cannot delete built-in entity');
}
```

**Why**: System entities (defaults) should not be deleted by users.

## 9. Snake_case in SQL, camelCase in Dart

Drift columns use snake_case; domain uses camelCase:

```dart
// Drift table
TextColumn get yourEntityId => text().nullable()();

// Query result
data['your_entity_id']  // snake_case from SQL

// Domain entity
entity.yourEntityId  // camelCase in Dart
```

## 10. Error Handling in Commands

Use exceptions for validation errors:

```dart
if (entity == null) {
  throw Exception('Entity not found');
}

if (entity.isBuiltIn) {
  throw Exception('Cannot modify built-in entity');
}
```

**UI layer catches and displays these errors to users.**

## 11. Drift Column Types

| Dart Type  | Drift Column     | Example             |
| ---------- | ---------------- | ------------------- |
| `String`   | `TextColumn`     | `text()()`          |
| `DateTime` | `DateTimeColumn` | `dateTime()()`      |
| `double`   | `RealColumn`     | `real()()`          |
| `int`      | `IntColumn`      | `integer()()`       |
| `bool`     | `BoolColumn`     | `boolean()()`       |
| Optional   | `.nullable()`    | `text().nullable()` |

## 12. Value Wrapper in Drift

Use `Value` wrapper for companion objects:

```dart
static YourEntityTableCompanion toCompanion(YourEntity entity) {
  return YourEntityTableCompanion(
    id: Value(entity.id),                    // Required field
    nullableField: entity.nullableField != null
        ? Value(entity.nullableField!)
        : const Value.absent(),              // Nullable field
  );
}
```

## 13. CQRS Naming Conventions

| Type    | Pattern                         | Example                           |
| ------- | ------------------------------- | --------------------------------- |
| Command | `Save<Entity>Command`           | `SaveTaskStatusCommand`           |
| Handler | `Save<Entity>CommandHandler`    | `SaveTaskStatusCommandHandler`    |
| Query   | `GetList<Entities>Query`        | `GetListTaskStatusesQuery`        |
| Handler | `GetList<Entities>QueryHandler` | `GetListTaskStatusesQueryHandler` |

## 14. Repository Interface Naming

Repository interfaces extend `IRepository`:

```dart
abstract class IYourEntityRepository extends app.IRepository<YourEntity, String> {}
```

**Inherits**: `save()`, `getById()`, `getList()`, `delete()`, `exists()`

## 15. Sync Configuration Pattern

```dart
_registerConfiguration(PaginatedSyncConfig<YourEntity>(
  name: 'YourEntity',                              // Human-readable
  repository: yourEntityRepository,                 // Repository instance
  getPaginatedSyncDataFromDto: (dto) => dto.<field>SyncData,  // DTO field
  entityType: 'YourEntity',                         // Type identifier
));
```

## 16. Translation Key Structure

Keys follow hierarchical structure:

```dart
class YourEntityTranslationKeys {
  static const String entityNotFound = '<feature>.errors.entity_not_found';
  static const String entitiesSettingsTitle = '<feature>.entities.settings.title';
  static const String entityAddButton = '<feature>.entities.add_button';
}
```

**YAML structure mirrors this**:

```yaml
<feature>:
  errors:
    entity_not_found: "..."
  entities:
    settings:
      title: "..."
    add_button: "..."
```

## 17. Shared Translation Keys

Reuse shared keys when possible:

```dart
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';

// Use:
SharedTranslationKeys.save
SharedTranslationKeys.cancel
SharedTranslationKeys.delete
SharedTranslationKeys.add
SharedTranslationKeys.edit
```

## 18. Component Naming Patterns

| Component Type  | Pattern                               | Example               |
| --------------- | ------------------------------------- | --------------------- |
| Settings page   | `<Feature>Setting`                    | `TaskStatusesSetting` |
| Helper          | `<Entity>Helper` or `<Entity>Display` | `TaskStatusDisplay`   |
| Constants       | `<Entity>Constants`                   | `TaskStatusConstants` |
| Grouping helper | `<Entity>GroupingHelper`              | `TaskGroupingHelper`  |

## 19. File Organization

```
lib/core/domain/features/<feature>/
├── <entity>.dart
├── <entity>_constants.dart

lib/core/application/features/<feature>/
├── commands/save_<entity>_command.dart
├── commands/delete_<entity>_command.dart
├── queries/get_list_<entities>_query.dart
├── queries/get_<entity>_query.dart
├── services/abstraction/i_<entity>_repository.dart
├── constants/<feature>_translation_keys.dart

lib/infrastructure/persistence/features/<feature>/repositories/
├── drift_<entity>_repository.dart
└── <entity>_data_mapper.dart

lib/presentation/ui/features/<feature>/
├── components/<feature>_<entities>_setting.dart
├── constants/<feature>_translation_keys.dart
└── assets/locales/*.yaml
```

## 20. Import Conventions

```dart
// Domain imports first
import 'package:whph/core/domain/features/<feature>/<entity>.dart';

// Application imports
import 'package:whph/core/application/features/<feature>/commands/save_<entity>_command.dart';

// Shared imports last
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';
```

## 21. DateTime Handling

Always use UTC for database storage:

```dart
createdDate: DateTime.now().toUtc(),
modifiedDate: DateTime.now().toUtc(),
```

**Parsing from JSON**:

```dart
DateTime.parse(json['createdDate'] as String)
```

## 22. UUID Generation

Use `uuid` package for ID generation:

```dart
import 'package:uuid/uuid.dart';

String _generateId() => uuid.v4();
```

**For built-ins**: Use fixed constants (see Phase 1: Constants).

## 23. Soft Delete Pattern

Soft-delete via `deletedDate`:

```dart
// In query
await repository.getList(filter: (e) => e.deletedDate == null);

// To delete
await repository.save(entity.copyWith(deletedDate: DateTime.now().toUtc()));

// Hard delete (if needed)
await repository.delete(entity.id);
```

## 24. Data-Driven vs Fixed Columns

**Data-driven** (columns from entity list):

```dart
List<String>? fixedColumnKeysFor(SortField field) {
  case SortField.yourField:
    return null;  // UI loads entities and builds columns
}
```

**Fixed columns** (predefined):

```dart
List<String>? fixedColumnKeysFor(SortField field) {
  case SortField.yourField:
    return ['key1', 'key2', 'key3'];  // Always these columns
}
```

## 25. Async Error Handling

Use `AsyncErrorHandler` in UI components:

```dart
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';

await AsyncErrorHandler.executeWithLoading(
  context: context,
  setLoading: (isLoading) => setState(() => _isLoading = isLoading),
  errorMessage: _translationService.translate(/* error key */),
  operation: () async {
    // Your async operation
  },
);
```

---

**These patterns ensure consistency across the codebase. Follow them when
implementing new entities.**

**Next**: See [Quick Reference Checklist](./09_QUICK_REFERENCE.md) for a
condensed summary.
