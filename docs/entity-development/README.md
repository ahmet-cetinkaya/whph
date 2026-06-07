# Entity Development Guide

This guide provides a comprehensive reference for implementing new entities
(domain models with persistence) in the WHPH codebase.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Layer-by-Layer Implementation](#layer-by-layer-implementation)
4. [Quick Reference](#quick-reference)

## Overview

Adding a new entity involves changes across all four architectural layers:

```
Domain Layer          → Entity class with serialization
Application Layer     → CQRS commands/queries + service interfaces
Infrastructure Layer  → Drift table + repository + migration
Presentation Layer    → (optional) UI components for management
```

Entities that participate in sync require additional integration.

## Prerequisites

Before implementing a new entity, understand these foundational concepts:

1. **Clean Architecture**: The four-layer separation (domain, application,
   infrastructure, presentation)
2. **CQRS Pattern**: Commands (write operations) and Queries (read operations)
   with MediatR
3. **Drift ORM**: SQLite database with type-safe queries, migrations, and code
   generation
4. **Dependency Injection**: Kiwi container with three registration entry points
5. **Sync Architecture**: Paginated sync pipeline for cross-device data
   propagation

**Recommended reading** (canonical examples):

- `lib/core/domain/features/tags/tag.dart` — BaseEntity pattern
- `lib/core/application/features/tags/commands/save_tag_command.dart` — command
  structure
- `lib/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart`
  — repository pattern
- `lib/core/application/features/sync/services/sync_configuration_service.dart`
  — sync integration

## Layer-by-Layer Implementation

Each layer is documented in detail:

| Phase | Document                                                         | Description                                |
| ----- | ---------------------------------------------------------------- | ------------------------------------------ |
| 1     | [Domain Layer](./01_DOMAIN_LAYER.md)                             | Entity class, constants, FK fields         |
| 2     | [Persistence Layer](./02_PERSISTENCE_LAYER.md)                   | Drift tables, repositories, migrations     |
| 3     | [Application Layer](./03_APPLICATION_LAYER.md)                   | CQRS commands/queries, handlers, DI        |
| 4     | [Business Logic Integration](./04_BUSINESS_LOGIC_INTEGRATION.md) | Grouping dimensions, validation (optional) |
| 5     | [Sync Integration](./05_SYNC_INTEGRATION.md)                     | Paginated sync configuration (recommended) |
| 6     | [UI Components](./06_UI_COMPONENTS.md)                           | Settings pages, locales (optional)         |

After implementation, see
[Code Generation & Verification](./07_CODE_GENERATION_AND_VERIFICATION.md).

## Common Patterns

See [Common Patterns & Conventions](./08_COMMON_PATTERNS.md) for established
conventions like:

- Sentinel `copyWith` pattern
- Idempotent migrations
- Built-in entity guards
- Ordering pattern
- And more...

## Quick Reference

Use the [Quick Reference Checklist](./09_QUICK_REFERENCE.md) for a condensed
version of all steps.

## Contributing

When implementing a new entity:

1. Follow the layer-by-layer guides completely
2. Run all verification steps before committing
3. Update these documents if patterns change
4. Use semantic commits: `feat(scope): add new entity`

---

**Last Updated**: 2025-12-19
