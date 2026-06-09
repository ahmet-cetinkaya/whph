# Quick Reference Checklist

## Overview

This is a condensed checklist for implementing a new entity. Use it as a quick
reference during implementation.

## Domain Layer ✓

- [ ] Entity class extends `BaseEntity<String>`
- [ ] `@JsonSerializable()` annotation on entity
- [ ] `toJson()` method (all fields)
- [ ] `fromJson()` factory (handle nullable fields)
- [ ] Sentinel `copyWith()` pattern (`_copyWithSentinel = Object()`)
- [ ] Constants class (if built-ins exist)
- [ ] FK field on parent entity (if applicable)

## Persistence Layer ✓

- [ ] Repository interface extends `IRepository<Entity, String>`
- [ ] Drift table with all columns (match domain entity)
- [ ] Repository class with `mapToEntity()` and `toCompanion()`
- [ ] Table registered in `@DriftDatabase`
- [ ] Schema version bumped (`schemaVersion`)
- [ ] FK column on parent table (if applicable)
- [ ] Parent data mapper updated (`mapFromRow`, `toCompanion`)
- [ ] Parent query builder updated (column in select)
- [ ] Migration file created (`migration_vXX_to_vYY.dart`)
- [ ] Migration idempotent (guards on table/column/data)
- [ ] Built-ins seeded in migration (if applicable)
- [ ] Backfill existing data (if FK on parent)
- [ ] Migration registered in `migration_runner.dart`
- [ ] Repository registered in `PersistenceContainer`

## Application Layer ✓

- [ ] Save command + handler (`IRequest<Entity>`)
- [ ] Delete command + handler (`IRequest<void>`)
- [ ] List query + handler (`const` constructor)
- [ ] Get query + handler (`const` constructor)
- [ ] Parent commands updated (if FK exists)
- [ ] Handlers registered in feature registration
- [ ] Repository passed through `ApplicationContainer`
- [ ] Feature registration wired in `ApplicationContainer`

## Business Logic Integration ✓ (Optional)

- [ ] Added to sort fields enum (if grouping dimension)
- [ ] Grouping helper updated (`getGroupName`, `isGroupTranslatable`, etc.)
- [ ] Board/group creation handler updated (if grouping)
- [ ] Parent commands apply business rules (if FK affects behavior)

## Sync Integration ✓ (Recommended)

- [ ] Field added to `PaginatedSyncDataDto`
- [ ] `toJson()` updated in DTO
- [ ] `fromJson()` updated in DTO
- [ ] Registered in `SyncConfigurationService`
- [ ] Updated in `sync_dto_builder.dart`
- [ ] Updated in `sync_dto_serializer.dart`
- [ ] Updated in `sync_page_accumulator.dart`
- [ ] Updated in `sync_response_builder.dart`
- [ ] Updated in `sync_validation_service.dart`
- [ ] Updated in `sync_registration.dart`

## UI Components ✓ (Optional)

- [ ] Settings component created
- [ ] Translation keys (application layer)
- [ ] Translation keys (presentation layer)
- [ ] All 22 locale YAML files updated
- [ ] Display helper for built-ins (if needed)
- [ ] Integrated into settings page
- [ ] Reorder support (if ordering needed)

## Code Generation ✓

- [ ] Run `rps gen` (Drift + mapper codegen)
- [ ] Verify `drift_app_context.g.dart` generated
- [ ] Verify `drift_app_context.steps.dart` generated
- [ ] Verify `main.mapper.g.dart` contains entity
- [ ] Verify schema snapshot created (`vXX.json`)

## Verification ✓

- [ ] `fvm flutter analyze` — No issues
- [ ] `rps lint` — Pass
- [ ] Entity unit tests written (`toJson`/`fromJson` round-trip)
- [ ] Command unit tests written (save/delete)
- [ ] `rps test` — All tests pass
- [ ] `rps test:locale` — Translations complete
- [ ] `rps test:migrate` — Migration tests pass
- [ ] Manual migration tested (fresh DB)

## Pre-Commit ✓

- [ ] All verification steps pass
- [ ] Build succeeds for target platform
- [ ] Documentation updated (if patterns changed)
- [ ] Semantic commit message: `feat(scope): add new entity`

---

## File Creation Summary

### New Files to Create

```
lib/core/domain/features/<feature>/
├── <entity>.dart                              # Entity class
└── <entity>_constants.dart                    # Constants (optional)

lib/core/application/features/<feature>/services/abstraction/
└── i_<entity>_repository.dart                 # Repository interface

lib/core/application/features/<feature>/
├── commands/
│   ├── save_<entity>_command.dart             # Save command
│   └── delete_<entity>_command.dart           # Delete command
└── queries/
    ├── get_list_<entities>_query.dart         # List query
    └── get_<entity>_query.dart                # Get query

lib/infrastructure/persistence/features/<feature>/repositories/
├── drift_<entity>_repository.dart              # Drift table + repo
└── <entity>_data_mapper.dart                   # Data mapper (if complex)

lib/infrastructure/persistence/shared/contexts/drift/migrations/
└── migration_vXX_to_vYY.dart                   # Migration file

lib/presentation/ui/features/<feature>/components/
└── <feature>_<entities>_setting.dart           # Settings UI (optional)

test/core/domain/features/<feature>/
└── <entity>_test.dart                          # Entity tests

test/core/application/features/<feature>/commands/
└── save_<entity>_command_test.dart             # Command tests (optional)
```

### Files to Modify

```
lib/infrastructure/persistence/shared/contexts/drift/
├── drift_app_context.dart                      # Add table, bump schema

lib/infrastructure/persistence/features/<parent>/repositories/
├── drift_<parent>_repository.dart              # Add FK column (if applicable)
├── <parent>_data_mapper.dart                   # Map FK (if applicable)
└── <parent>_query_builder.dart                 # Add FK to select (if applicable)

lib/infrastructure/persistence/shared/contexts/drift/migrations/
├── migration_runner.dart                       # Register migration step
└── migrations.dart                             # Export migration function

lib/infrastructure/persistence/
└── persistence_container.dart                   # Register repository

lib/core/application/features/<feature>/
├── <feature>_registration.dart                 # Register handlers
└── constants/<feature>_translation_keys.dart   # Add keys (application)

lib/core/application/
└── application_container.dart                   # Wire feature

lib/core/application/features/sync/
├── models/paginated_sync_data_dto.dart         # Add field
├── services/sync_configuration_service.dart    # Register config
├── services/sync_dto_builder.dart              # Update builder
├── services/sync_dto_serializer.dart           # Update serializer
├── services/sync_page_accumulator.dart         # Update accumulator
├── services/sync_response_builder.dart         # Update response builder
├── services/sync_validation_service.dart       # Update validator
└── sync_registration.dart                      # Register in container

lib/presentation/ui/features/<feature>/
├── constants/<feature>_translation_keys.dart   # Add keys (presentation)
└── assets/locales/*.yaml                       # Add translations (22 files)

lib/presentation/ui/features/settings/components/
└── <feature>_settings.dart                     # Integrate settings (optional)
```

## Quick Commands

```bash
# Code generation
rps gen

# Verification
fvm flutter analyze
rps lint
rps test
rps test:locale
rps test:migrate

# Build
fvm flutter build linux --release  # Or your platform
```

---

**For detailed guidance, see the full layer-by-layer guides in the previous
sections.**

**Next**: Start with [Phase 1: Domain Layer](./01_DOMAIN_LAYER.md).
