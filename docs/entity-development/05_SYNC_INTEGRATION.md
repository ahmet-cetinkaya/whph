# Phase 5: Sync Integration

## Overview

Sync integration enables your entity to propagate across devices. Most entities
should participate in sync. This phase registers your entity with the paginated
sync pipeline.

## Architecture

The WHPH sync system uses:

- **Paginated sync**: Large datasets transferred in pages
- **Bidirectional**: Changes from any device sync to all others
- **Conflict resolution**: Last-write-wins based on `modifiedDate`
- **Soft-delete support**: Deleted records sync across devices

## Add to Sync DTO

**Location**:
`lib/core/application/features/sync/models/paginated_sync_data_dto.dart`

```dart
class PaginatedSyncDataDto {
  // ... existing fields
  final Map<String, dynamic>? yourEntitiesSyncData;  // ← Add

  const PaginatedSyncDataDto({
    // ...
    this.yourEntitiesSyncData,
  });

  Map<String, dynamic> toJson() => {
    // ...
    'yourEntitiesSyncData': yourEntitiesSyncData,
  };

  factory PaginatedSyncDataDto.fromJson(Map<String, dynamic> json) => PaginatedSyncDataDto(
    // ...
    yourEntitiesSyncData: json['yourEntitiesSyncData'] as Map<String, dynamic>?,
  );
}
```

### DTO Pattern

- Field name: `<entityPlural>SyncData` (camelCase)
- Type: `Map<String, dynamic>?` for paginated data structure
- Add to `toJson()` and `fromJson()` methods

## Register in Sync Configuration

**Location**:
`lib/core/application/features/sync/services/sync_configuration_service.dart`

```dart
void registerConfigurations({required Container container}) {
  final yourEntityRepository = container.resolve<IYourEntityRepository>();

  _registerConfiguration(PaginatedSyncConfig<YourEntity>(
    name: 'YourEntity',
    repository: yourEntityRepository,
    getPaginatedSyncDataFromDto: (dto) => dto.yourEntitiesSyncData,
    entityType: 'YourEntity',
  ));
}
```

### SyncConfig Parameters

| Parameter                     | Description                   | Example                             |
| ----------------------------- | ----------------------------- | ----------------------------------- |
| `name`                        | Human-readable name           | `'TaskStatus'`                      |
| `repository`                  | Repository instance           | `taskStatusRepository`              |
| `getPaginatedSyncDataFromDto` | Extract data from DTO         | `(dto) => dto.yourEntitiesSyncData` |
| `entityType`                  | Type identifier for sync logs | `'TaskStatus'`                      |

## Update Sync Pipeline Files

The following 6 files need to handle the new entity. For single-entity sync
(most common), mirror the existing entries exactly.

### 1. Sync DTO Builder

**Location**:
`lib/core/application/features/sync/services/sync_dto_builder.dart`

```dart
import 'package:whph/core/domain/features/<feature>/<entity_name>.dart';

class SyncDtoBuilder {
  // ...
  Future<PaginatedSyncDataDto> buildDto(SyncRequest request) async {
    // ...
    final yourEntitiesData = await _buildPaginatedData<YourEntity>(
      repository: _yourEntityRepository,
      request: request,
    );

    return PaginatedSyncDataDto(
      // ...
      yourEntitiesSyncData: yourEntitiesData,
    );
  }
}
```

### 2. Sync DTO Serializer

**Location**:
`lib/core/application/features/sync/services/sync_dto_serializer.dart`

```dart
class SyncDtoSerializer {
  // ...
  Map<String, dynamic> serializeDto(PaginatedSyncDataDto dto) => {
    // ...
    'yourEntitiesSyncData': dto.yourEntitiesSyncData,
  };
}
```

### 3. Sync Page Accumulator

**Location**:
`lib/core/application/features/sync/services/sync_page_accumulator.dart`

```dart
class SyncPageAccumulator {
  // ...
  PaginatedSyncDataDto accumulate(PaginatedSyncDataDto dto, PaginatedSyncDataDto page) {
    return PaginatedSyncDataDto(
      // ...
      yourEntitiesSyncData: _accumulatePages(
        existing: dto.yourEntitiesSyncData,
        incoming: page.yourEntitiesSyncData,
      ),
    );
  }
}
```

### 4. Sync Response Builder

**Location**:
`lib/core/application/features/sync/services/sync_response_builder.dart`

```dart
class SyncResponseBuilder {
  // ...
  SyncResponse buildResponse(PaginatedSyncDataDto dto) => SyncResponse(
    // ...
    data: _serializeDto(dto),  // Includes your entity
  );
}
```

### 5. Sync Validation Service

**Location**:
`lib/core/application/features/sync/services/sync_validation_service.dart`

```dart
class SyncValidationService {
  // ...
  Future<SyncValidationResult> validateIncomingData(PaginatedSyncDataDto dto) async {
    // ...
    await _validateEntityData<YourEntity>(
      data: dto.yourEntitiesSyncData,
      entityName: 'YourEntity',
      repository: _yourEntityRepository,
    );
  }
}
```

### 6. Sync Registration

**Location**: `lib/core/application/features/sync/sync_registration.dart`

```dart
void registerSyncComponents({required Container container}) {
  final yourEntityRepository = container.resolve<IYourEntityRepository>();

  registerSyncConfiguration(
    container: container,
    yourEntityRepository: yourEntityRepository,
  );
}
```

### Pattern for All 6 Files

For simple single-entity sync (no relationships like TagTag):

1. Import your entity
2. Resolve repository in constructor
3. Add to build/serialize/accumulate/validate methods
4. Mirror existing entity entries exactly

## Complex Relationships (Advanced)

If your entity has relationships (like TagTag for many-to-many):

**Location**: Create specialized sync handlers

```dart
// Example for entities with relationships
class YourEntityRelationshipSyncHandler {
  Future<void> beforeSave(YourEntity entity, SyncContext context) async {
    // Resolve related entities before saving
    if (entity.relatedId != null) {
      final exists = await _relatedRepository.exists(entity.relatedId!);
      if (!exists) {
        throw SyncException('Related entity not found');
      }
    }
  }

  Future<void> afterSave(YourEntity entity, SyncContext context) async {
    // Update relationship tables
    if (entity.relatedIds != null) {
      await _relationshipRepository.saveAll(entity.id, entity.relatedIds!);
    }
  }
}
```

Most entities won't need this — use only for complex many-to-many relationships.

## Testing Sync

### Unit Test

**Location**:
`test/core/application/features/sync/services/sync_validation_service_test.dart`

```dart
test('validates YourEntity data', () async {
  final dto = PaginatedSyncDataDto(
    yourEntitiesSyncData: {
      'page1': [
        {'id': 'test-id', 'field1': 'test', /* ... */},
      ],
    },
  );

  final result = await validator.validateIncomingData(dto);
  expect(result.isValid, isTrue);
});
```

### Manual Test

1. Create entity on device A
2. Run sync
3. Verify on device B
4. Modify on device B
5. Run sync
6. Verify on device A

## Sync Troubleshooting

### Entity Not Syncing

1. **Check registration**: Is `SyncConfig` registered?
2. **Check DTO**: Is field added to `PaginatedSyncDataDto`?
3. **Check repository**: Is `IYourEntityRepository` resolved?
4. **Check pipeline files**: Are all 6 files updated?

### Data Corruption

1. **Check JSON**: Does `toJson()`/`fromJson()` handle all fields?
2. **Check mapper**: Is `@JsonSerializable()` on entity?
3. **Run `rps gen`**: Did mapper codegen run?

### Conflicts

Conflicts resolve by `modifiedDate` (last-write-wins). To add custom conflict
resolution:

```dart
class YourEntitySyncResolver {
  YourEntity resolveConflict(YourEntity local, YourEntity remote) {
    // Custom logic
    return local.modifiedDate.isAfter(remote.modifiedDate) ? local : remote;
  }
}
```

## Next Steps

After sync integration:

→ [Phase 6: UI Components](./06_UI_COMPONENTS.md) (optional)

→ [Code Generation & Verification](./07_CODE_GENERATION_AND_VERIFICATION.md)

---

**See also**: [Common Patterns](./08_COMMON_PATTERNS.md) for sync-specific
conventions.
