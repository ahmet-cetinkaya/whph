# Phase 2: Persistence Layer

## Overview

The persistence layer handles database storage using Drift ORM. This phase
creates the repository interface, Drift table definition, and database
migration.

## Repository Interface

**Location**:
`lib/core/application/features/<feature>/services/abstraction/i_<entity_name>_repository.dart`

```dart
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/features/<feature>/<entity_name>.dart';

abstract class IYourEntityRepository extends app.IRepository<YourEntity, String> {}
```

Extending `IRepository` inherits CRUD operations:

- `save(YourEntity entity)`
- `getById(String id)`
- `getList({filter, orderBy})`
- `delete(String id)`
- `exists(String id)`

## Drift Table + Repository

**Location**:
`lib/infrastructure/persistence/features/<feature>/repositories/drift_<entity_name>_repository.dart`

```dart
import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/core/domain/features/<feature>/<entity_name>.dart';

@UseRowClass(YourEntity)
class YourEntityTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  TextColumn get field1 => text()();
  TextColumn get nullableField => text().nullable()();
  RealColumn get order => real()();
  BoolColumn get isBuiltIn => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

class DriftYourEntityRepository extends DriftBaseRepository<YourEntityTable, YourEntity, String>
    implements IYourEntityRepository {
  DriftYourEntityRepository(super.database);

  // Test constructor (recommended for testing)
  DriftYourEntityRepository.withDatabase(AppDatabase database) : super(database);

  static YourEntity mapToEntity(YourEntityTableData data) => YourEntity(
    id: data.id,
    createdDate: data.createdDate,
    modifiedDate: data.modifiedDate,
    deletedDate: data.deletedDate,
    field1: data.field1,
    nullableField: data.nullableField,
    order: data.order,
    isBuiltIn: data.isBuiltIn,
  );

  static YourEntityTableCompanion toCompanion(YourEntity entity) => YourEntityTableCompanion(
    id: Value(entity.id),
    createdDate: Value(entity.createdDate),
    modifiedDate: Value(entity.modifiedDate),
    deletedDate: entity.deletedDate != null ? Value(entity.deletedDate!) : const Value.absent(),
    field1: Value(entity.field1),
    nullableField: entity.nullableField != null ? Value(entity.nullableField!) : const Value.absent(),
    order: Value(entity.order),
    isBuiltIn: Value(entity.isBuiltIn),
  );
}
```

### Column Types Reference

| Dart Type  | Drift Column     | Example                                        |
| ---------- | ---------------- | ---------------------------------------------- |
| `String`   | `TextColumn`     | `textColumn get name => text()();`             |
| `DateTime` | `DateTimeColumn` | `dateTimeColumn get date => dateTime()();`     |
| `double`   | `RealColumn`     | `realColumn get order => real()();`            |
| `int`      | `IntColumn`      | `intColumn get count => integer()();`          |
| `bool`     | `BoolColumn`     | `booleanColumn get active => boolean()();`     |
| Optional   | `.nullable()`    | `textColumn get field => text().nullable()();` |

### Best Practices

- **`@UseRowClass` annotation**: Links table to domain entity
- **Test constructor**: `.withDatabase(AppDatabase)` for unit testing
- **`mapToEntity`**: Convert DB rows to domain objects
- **`toCompanion`**: Convert domain to DB objects with `Value` wrapper
- **Nullable handling**: Use `Value.absent()` for null, `Value(field)` for
  non-null

## Register Table in DriftDatabase

**Location**:
`lib/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart`

```dart
@DriftDatabase(tables: [
  // ... existing tables
  YourEntityTable,  // ← Add
], includedViews: [
  // ...
])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 34;  // ← Increment (was 33)

  // ...
}
```

### Schema Version

Increment `schemaVersion` by 1 for each migration.

## Foreign Key Column (If Applicable)

If your entity is referenced by another entity:

**Location**:
`lib/infrastructure/persistence/features/<parent_feature>/repositories/<parent_repository>/drift_<parent_repository>.dart`

```dart
class ParentEntityTable extends Table {
  // ... existing columns
  TextColumn get yourEntityId => text().nullable()();  // ← Add
}
```

### Update Parent Data Mapper

**Location**:
`lib/infrastructure/persistence/features/<parent_feature>/repositories/<parent_repository>/<parent>_data_mapper.dart`

```dart
class ParentDataMapper {
  static ParentEntity mapFromRow(QueryExecutorRow data) => ParentEntity(
    // ...
    yourEntityId: data['your_entity_id'],  // ← Add (snake_case from query)
  );

  static ParentTableCompanion toCompanion(ParentEntity entity, {bool isNew = false}) {
    return ParentTableCompanion(
      // ...
      yourEntityId: Value(entity.yourEntityId),  // ← Add
    );
  }
}
```

### Update Parent Query Builder

**Location**:
`lib/infrastructure/persistence/features/<parent_feature>/repositories/<parent_repository>/<parent>_query_builder.dart`

If using explicit column selection (not `*`), add the new column:

```dart
SimpleSelectStatement<ParentTable, ParentTableData> buildQuery({
  // ...
}) {
  final query = select(parentTable)..where((tbl) => tbl.deletedDate.isNull());

  // If using explicit columns, add:
  // yourEntityId: parentTable.yourEntityId
  // ...
}
```

## Migration

**Location**:
`lib/infrastructure/persistence/shared/contexts/drift/migrations/migration_v33_to_v34.dart`

```dart
import 'package:drift/drift.dart';
import 'package:whph/core/domain/features/<feature>/<entity_name>_constants.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

Future<void> migrateV33ToV34(
  AppDatabase db,
  Migrator m,
  Schema34 schema,
) async {
  // 1. Create table with PRAGMA guard (idempotent)
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS <entity_name>_table (
      id TEXT PRIMARY KEY,
      created_date INTEGER NOT NULL,
      modified_date INTEGER NOT NULL,
      deleted_date INTEGER,
      field1 TEXT NOT NULL,
      nullable_field TEXT,
      order REAL NOT NULL,
      is_built_in INTEGER NOT NULL
    )
  ''');

  // 2. Add column to parent table with guard
  final hasColumn = await db.customSelect(
    'SELECT COUNT(*) AS count FROM pragma_table_info("<parent_table>") WHERE name="<your_entity_id>"'
  ).getSingle();

  if (hasColumn.data['count'] == 0) {
    await m.addColumn(schema.parentTable, schema.parentTable.yourEntityId);
  }

  // 3. Seed built-in data with INSERT guard
  final existingBuiltIns = await db.customSelect(
    'SELECT COUNT(*) AS count FROM <entity_name>_table WHERE id IN (?, ?)',
    variables: [Variable(YourEntityConstants.builtinOneId), Variable(YourEntityConstants.builtinTwoId)],
  ).getSingle();

  if (existingBuiltIns.data['count'] == 0) {
    final now = DateTime.now().toUtc();
    await db.customStatement('''
      INSERT INTO <entity_name>_table (
        id, created_date, modified_date, field1, nullable_field, "order", is_built_in
      ) VALUES
        (?, ?, ?, '', NULL, ?, 1),
        (?, ?, ?, '', NULL, ?, 1)
    ''', [
      YourEntityConstants.builtinOneId, now, now, YourEntityConstants.defaultOrder,
      YourEntityConstants.builtinTwoId, now, now, YourEntityConstants.defaultOrder + 1,
    ]);
  }

  // 4. Backfill existing data (if FK on parent)
  await db.customStatement('''
    UPDATE <parent_table>
    SET <your_entity_id> = ?
    WHERE <condition> AND <your_entity_id> IS NULL
  ''', [YourEntityConstants.builtinOneId]);
}
```

### Migration Idempotence

Make migrations re-runnable with guards:

| Operation    | Guard Pattern                                                         |
| ------------ | --------------------------------------------------------------------- |
| Create table | `CREATE TABLE IF NOT EXISTS`                                          |
| Add column   | `SELECT COUNT(*) FROM pragma_table_info("table") WHERE name="column"` |
| Insert data  | `SELECT COUNT(*) FROM table WHERE id IN (...)`                        |
| Update data  | `WHERE ... IS NULL` (avoid overwriting)                               |

## Register Migration Step

**Location**:
`lib/infrastructure/persistence/shared/contexts/drift/migrations/migration_runner.dart`

```dart
Future<void> runMigrations(AppDatabase db, Migrator m) async {
  final from = db.executor.schemaVersion;

  // ... existing steps (from32To33, etc.)

  if (from < 34) {
    await from33To34(db, m, Schema34(db));
  }
}

Future<void> from33To34(AppDatabase db, Migrator m) async {
  final schema = Schema34(db);
  await migrateV33ToV34(db, m, schema);
}
```

## Register Repository in DI

**Location**: `lib/infrastructure/persistence/persistence_container.dart`

```dart
void registerPersistenceComponents({required Container container}) {
  // ...
  container.register<IYourEntityRepository, DriftYourEntityRepository>((c) {
    return DriftYourEntityRepository(c.resolve<AppDatabase>());
  });
}
```

## Next Steps

After persistence layer is complete:

→ [Phase 3: Application Layer](./03_APPLICATION_LAYER.md)

---

**See also**:
[Code Generation & Verification](./07_CODE_GENERATION_AND_VERIFICATION.md) for
running `rps gen` to regenerate Drift schemas.
