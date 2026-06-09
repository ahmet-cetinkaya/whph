# Code Generation & Verification

## Overview

After implementing all layers, run code generation and verification to ensure
everything is correct.

## Code Generation

### Run Codegen

```bash
rps gen
```

This regenerates:

- **Drift schemas**: `drift_app_context.g.dart`, `.steps.dart`
- **Schema snapshots**: New `v34.json` file
- **Migration tests**: Auto-generated for each version step
- **Mapper code**: `main.mapper.g.dart`
- **JSON serialization**: Entity serialization

### What Gets Generated

#### Drift Generated Files

**Location**:
`lib/infrastructure/persistence/shared/contexts/drift/drift_app_context.g.dart`

```dart
// Auto-generated database class with CRUD methods
part 'drift_app_context.g.dart'

// Example:
Future<List<YourEntityTableData>> get allYourEntities;
Future<YourEntityTableData> getYourEntityById(String id);
```

**Location**:
`lib/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart`

```dart
// Migration steps for schema validation
class Schema34 extends SchemaVersion {
  // ...
}
```

#### Mapper Generated Files

**Location**: `lib/main.mapper.g.dart`

```dart
// JSON serialization for @JsonSerializable classes
YourEntity $YourEntityJsonMapperType(
  Map<String, dynamic> value,
) => YourEntity.fromJson(value);
```

### Verify Mapper Registration

Check that your entity is registered in the mapper:

```bash
grep -i "YourEntity" lib/main.mapper.g.dart | wc -l
```

Should return > 0 (number of references to your entity).

## Static Analysis

### Flutter Analyze

```bash
fvm flutter analyze
```

**Expected output**: `No issues found!`

**Common issues**:

- **Missing imports**: Add imports for new entities
- **Unused imports**: Remove unused imports after refactoring
- **Const issues**: Make query constructors `const`
- **Type mismatches**: Verify column types (Drift vs Domain)

### Lint Check

```bash
rps lint
```

**Expected output**: No lint errors.

## Unit Tests

### Write Entity Tests

**Location**: `test/core/domain/features/<feature>/<entity_name>_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/<feature>/<entity_name>.dart';

void main() {
  group('YourEntity', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final entity = YourEntity(
        id: 'test-id',
        createdDate: DateTime.utc(2026, 1, 1),
        modifiedDate: DateTime.utc(2026, 1, 2),
        field1: 'Test',
        nullableField: null,
        order: 1.0,
        isBuiltIn: false,
      );

      final restored = YourEntity.fromJson(entity.toJson());

      expect(restored.id, equals('test-id'));
      expect(restored.field1, equals('Test'));
      expect(restored.order, equals(1.0));
      expect(restored.isBuiltIn, isFalse);
      expect(restored.nullableField, isNull);
      expect(restored.createdDate, equals(DateTime.utc(2026, 1, 1)));
      expect(restored.modifiedDate, equals(DateTime.utc(2026, 1, 2)));
    });

    test('fromJson tolerates missing optional fields', () {
      final restored = YourEntity.fromJson({
        'id': 'test-id',
        'createdDate': DateTime.utc(2026, 1, 1).toIso8601String(),
        'modifiedDate': DateTime.utc(2026, 1, 2).toIso8601String(),
        'field1': 'Test',
        'order': 1.0,
        'isBuiltIn': false,
      });

      expect(restored.nullableField, isNull);
    });
  });
}
```

### Write Command Tests

**Location**:
`test/core/application/features/<feature>/commands/save_<entity_name>_command_test.dart`

```dart
void main() {
  group('SaveYourEntityCommand', () {
    test('saves new entity', () async {
      final command = SaveYourEntityCommand(
        field1: 'Test',
        order: 1.0,
        isBuiltIn: false,
      );

      final result = await handler.call(command);

      expect(result.id, isNotNull);
      expect(result.field1, equals('Test'));
    });

    test('updates existing entity', () async {
      // Setup: create entity
      final existing = await repository.save(/* ... */);

      final command = SaveYourEntityCommand(
        id: existing.id,
        field1: 'Updated',
        order: existing.order,
        isBuiltIn: existing.isBuiltIn,
      );

      final result = await handler.call(command);

      expect(result.field1, equals('Updated'));
    });
  });
}
```

### Run All Tests

```bash
rps test
```

**Expected output**: All tests pass.

## Locale Test

Verify all translations are complete:

```bash
rps test:locale
```

**Expected output**: `All translations complete`

**Common issues**:

- **Missing keys**: Add to all 22 locale YAMLs
- **Typos**: Check key spelling across files
- **Inconsistent keys**: Ensure exact match between code and YAML

## Migration Test

Test migration correctness:

```bash
rps test:migrate
```

This runs auto-generated Drift schema verification tests for all migration
steps.

**What it tests**:

- Schema upgrades from any version to current
- Downgrade support (if implemented)
- Column additions
- Table creations
- Data backfills

### Manual Migration Test

1. **Backup existing database** (if any):

   ```bash
   cp ~/.local/share/whph/whph.db ~/.local/share/whph/whph.db.backup
   ```

2. **Run migration**:

   ```bash
   fvm flutter run -d linux  # Or your platform
   ```

3. **Verify schema**:

   ```bash
   sqlite3 ~/.local/share/whph/whph.db ".schema your_entity_table"
   ```

4. **Verify data**:

   ```sql
   SELECT * FROM your_entity_table;
   ```

5. **Check backfills** (if FK on parent):
   ```sql
   SELECT your_entity_id, COUNT(*) FROM parent_table GROUP BY your_entity_id;
   ```

## Build Verification

### Full Build

```bash
fvm flutter build linux --release
```

**Expected output**: Build succeeds.

### Test Build

```bash
fvm flutter test
```

## Common Issues and Fixes

### Code Generation Fails

**Issue**: `rps gen` fails with errors.

**Fixes**:

1. Check Drift table definition matches domain entity
2. Verify all columns have type mappings
3. Ensure `@UseRowClass` annotation is present
4. Check for circular imports

### Mapper Not Generated

**Issue**: Entity not in `main.mapper.g.dart`.

**Fixes**:

1. Ensure `@JsonSerializable()` on entity class
2. Implement `toJson()` and `fromJson()` methods
3. Check imports are correct
4. Run `fvm flutter clean` then `rps gen`

### Migration Fails

**Issue**: Database migration errors on app start.

**Fixes**:

1. Verify schema version bumped
2. Check migration registered in runner
3. Ensure PRAGMA guards are correct
4. Test with fresh database (delete old)

### Locale Test Fails

**Issue**: Missing translations.

**Fixes**:

1. Add missing keys to all 22 locale files
2. Verify key spelling matches exactly
3. Check for extra whitespace in keys
4. Run `rps gen` after changes

## Pre-Commit Checklist

Before committing:

- [ ] `rps gen` completed successfully
- [ ] `fvm flutter analyze` reports no issues
- [ ] `rps lint` passes
- [ ] `rps test` passes (all tests)
- [ ] `rps test:locale` reports complete
- [ ] `rps test:migrate` passes
- [ ] Mapper verified in `main.mapper.g.dart`
- [ ] Build succeeds for target platform
- [ ] Documentation updated (if patterns changed)

## Next Steps

After all verification passes:

→ See [Quick Reference Checklist](./09_QUICK_REFERENCE.md) for a condensed
summary.

---

**See also**: [Common Patterns](./08_COMMON_PATTERNS.md) for troubleshooting
patterns.
