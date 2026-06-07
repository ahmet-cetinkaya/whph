# Phase 3: Application Layer

## Overview

The application layer implements CQRS (Command Query Responsibility Segregation)
using MediatR. This phase creates commands (write operations), queries (read
operations), and registers handlers with dependency injection.

## Save Command

**Location**:
`lib/core/application/features/<feature>/commands/save_<entity_name>_command.dart`

```dart
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/shared/services/abstraction/i_repository.dart';
import 'package:whph/core/domain/features/<feature>/<entity_name>.dart';

class SaveYourEntityCommand extends IRequest<YourEntity> {
  final String? id;
  final String field1;
  final String? nullableField;
  final double order;
  final bool isBuiltIn;

  const SaveYourEntityCommand({
    this.id,
    required this.field1,
    this.nullableField,
    required this.order,
    this.isBuiltIn = false,
  });
}

class SaveYourEntityCommandHandler extends IRequestHandler<SaveYourEntityCommand, YourEntity> {
  final IYourEntityRepository yourEntityRepository;

  SaveYourEntityCommandHandler(this.yourEntityRepository);

  @override
  Future<YourEntity> call(SaveYourEntityCommand request) async {
    final now = DateTime.now().toUtc();
    final entity = request.id != null
        ? await yourEntityRepository.getById(request.id!)
        : null;

    final toSave = YourEntity(
      id: entity?.id ?? _generateId(),
      createdDate: entity?.createdDate ?? now,
      modifiedDate: now,
      field1: request.field1,
      nullableField: request.nullableField,
      order: request.order,
      isBuiltIn: request.isBuiltIn,
    );

    await yourEntityRepository.save(toSave);
    return toSave;
  }

  String _generateId() => uuid.v4();  // Or appropriate ID generation
}
```

### Save Command Pattern

- **Return type**: Returns the saved entity for confirmation
- **ID handling**: `null` ID = create, non-null = update
- **Timestamps**: `modifiedDate` always updates; `createdDate` preserved on
  update
- **Validation**: Add guards here (e.g., prevent mutating built-ins)

## Delete Command

**Location**:
`lib/core/application/features/<feature>/commands/delete_<entity_name>_command.dart`

```dart
class DeleteYourEntityCommand extends IRequest<void> {
  final String id;

  const DeleteYourEntityCommand({required this.id});
}

class DeleteYourEntityCommandHandler extends IRequestHandler<DeleteYourEntityCommand, void> {
  final IYourEntityRepository yourEntityRepository;
  final IParentRepository parentRepository;  // If FKs exist

  DeleteYourEntityCommandHandler(
    this.yourEntityRepository,
    this.parentRepository,
  );

  @override
  Future<void> call(DeleteYourEntityCommand request) async {
    final entity = await yourEntityRepository.getById(request.id);
    if (entity == null) {
      throw Exception('Entity not found');
    }

    // Guard: cannot delete built-ins (if applicable)
    if (entity.isBuiltIn) {
      throw Exception('Cannot delete built-in entity');
    }

    // Reassign/delete affected records (if FKs exist)
    final affected = await parentRepository.getList(
      filter: (p) => p.yourEntityId == request.id,
    );
    for (final item in affected) {
      await parentRepository.save(
        item.copyWith(yourEntityId: YourEntityConstants.builtinOneId),
      );
    }

    await yourEntityRepository.delete(request.id);
  }
}
```

### Delete Command Pattern

- **Existence check**: Always verify entity exists before deleting
- **Built-in guards**: Prevent deletion of system entities
- **FK cleanup**: Reassign or delete dependent records
- **Return `void`**: No data needed on success

## List Query

**Location**:
`lib/core/application/features/<feature>/queries/get_list_<entity_name>s_query.dart`

```dart
class GetListYourEntitiesQuery extends IRequest<List<YourEntityListItem>> {
  const GetListYourEntitiesQuery();
}

class YourEntityListItem {
  final String id;
  final String field1;
  final String? nullableField;
  final double order;
  final bool isBuiltIn;

  const YourEntityListItem({
    required this.id,
    required this.field1,
    this.nullableField,
    required this.order,
    required this.isBuiltIn,
  });
}

class GetListYourEntitiesQueryHandler extends IRequestHandler<GetListYourEntitiesQuery, List<YourEntityListItem>> {
  final IYourEntityRepository yourEntityRepository;

  GetListYourEntitiesQueryHandler(this.yourEntityRepository);

  @override
  Future<List<YourEntityListItem>> call(GetListYourEntitiesQuery request) async {
    final entities = await yourEntityRepository.getList(
      orderBy: (e) => e.order,
    );

    return entities.map((e) => YourEntityListItem(
      id: e.id,
      field1: e.field1,
      nullableField: e.nullableField,
      order: e.order,
      isBuiltIn: e.isBuiltIn,
    )).toList();
  }
}
```

### List Query Pattern

- **`const` constructor**: Required for compiler optimizations
- **ListItem DTO**: Separate from full entity for UI use
- **Mapping**: Convert domain entities to presentation DTOs
- **Ordering**: Apply default sort (e.g., by `order` field)

## Get Query

**Location**:
`lib/core/application/features/<feature>/queries/get_<entity_name>_query.dart`

```dart
class GetYourEntityQuery extends IRequest<YourEntity> {
  final String id;

  const GetYourEntityQuery({required this.id});
}

class GetYourEntityQueryHandler extends IRequestHandler<GetYourEntityQuery, YourEntity> {
  final IYourEntityRepository yourEntityRepository;

  GetYourEntityQueryHandler(this.yourEntityRepository);

  @override
  Future<YourEntity> call(GetYourEntityQuery request) async {
    final entity = await yourEntityRepository.getById(request.id);
    if (entity == null) {
      throw Exception('Entity not found');
    }
    return entity;
  }
}
```

### Get Query Pattern

- **`const` constructor**: Same as list query
- **Single result**: Returns full entity, not DTO
- **Exception on not found**: UI handles error display

## Wire Entity Logic into Existing Commands (If Applicable)

If your entity is referenced by another entity (e.g., via FK), update those
parent commands:

**Location**:
`lib/core/application/features/<parent_feature>/commands/save_<parent>_command.dart`

```dart
class SaveParentCommand extends IRequest<ParentEntity> {
  // ... existing params
  final String? yourEntityId;  // ← Add

  const SaveParentCommand({
    // ...
    this.yourEntityId,
  });
}

class SaveParentCommandHandler extends IRequestHandler<SaveParentCommand, ParentEntity> {
  // ... inside the update logic:
  if (request.yourEntityId != null) {
    parent.yourEntityId = request.yourEntityId;
    // Apply any business rules here
  }
}
```

## Register Handlers in DI Container

**Location**:
`lib/core/application/features/<feature>/<feature>_registration.dart`

```dart
void registerYourFeature({
  required Container container,
  required IYourEntityRepository yourEntityRepository,
  // ...
}) {
  // Commands
  container.register<IRequestHandler<SaveYourEntityCommand, YourEntity>>(
    (c) => SaveYourEntityCommandHandler(c.resolve(yourEntityRepository)),
  );
  container.register<IRequestHandler<DeleteYourEntityCommand, void>>(
    (c) => DeleteYourEntityCommandHandler(
      c.resolve(yourEntityRepository),
      c.resolve(parentRepository),
    ),
  );

  // Queries
  container.register<IRequestHandler<GetListYourEntitiesQuery, List<YourEntityListItem>>>(
    (c) => GetListYourEntitiesQueryHandler(c.resolve(yourEntityRepository)),
  );
  container.register<IRequestHandler<GetYourEntityQuery, YourEntity>>(
    (c) => GetYourEntityQueryHandler(c.resolve(yourEntityRepository)),
  );
}
```

### Registration Pattern

- **Resolve repositories**: Pass in via parameters, not direct resolution
- **Handler factories**: Use lambda to resolve handler dependencies
- **Commands and queries**: Register all handlers used by the feature

## Wire into Application Container

**Location**: `lib/core/application/application_container.dart`

```dart
void registerApplicationComponents({required Container container}) {
  final yourEntityRepository = container.resolve<IYourEntityRepository>();

  registerYourFeature(
    container: container,
    yourEntityRepository: yourEntityRepository,
    // ...
  );
}
```

## Next Steps

After application layer is complete:

→ [Phase 4: Business Logic Integration](./04_BUSINESS_LOGIC_INTEGRATION.md)
(optional)

→ [Phase 5: Sync Integration](./05_SYNC_INTEGRATION.md) (recommended)

---

**See also**: [Common Patterns](./08_COMMON_PATTERNS.md) for CQRS conventions
and const query constructors.
