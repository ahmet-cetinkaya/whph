# Project Modules Documentation

This document provides an overview of the modules in the WHPH project, a cross-platform application built with Flutter/Dart. Modules are organized in feature folders to promote modularity.

## Core Modules

### About Module
Displays app information, version, licenses, and credits with localization support. Renders dynamic about pages, loads multi-language strings, and shows open-source licenses.

### App Usages Module
Tracks app usage statistics like time spent and sessions across platforms. Logs open/close events, queries daily/weekly stats, and uses platform-specific APIs such as Android UsageStatsManager or desktop timers.

### Calendar Module
Handles calendar events, reminders, and scheduling. Allows creating/viewing events, setting recurring reminders, and syncing with device calendars across platforms.

### Demo Module
Provides sample features for testing and onboarding. Generates mock data and demonstrates workflows for other modules.

### Habits Module
Tracks user habits with streaks, reminders, and analytics. Supports creating/editing habits, daily completion tracking, and streak report generation.

### Notes Module
Enables note-taking with rich text, tagging, and search capabilities. Provides CRUD operations, tag attachments, and note searching/filtering.

### Settings Module
Manages app configuration including themes, privacy, and sync. Allows updating preferences, switching themes, and exporting/importing settings.

### Sync Module
Handles data synchronization across devices and backups. Supports two-way cloud sync (e.g., Firebase), conflict resolution, and backup/restore functions.

### Tags Module
Manages tags for categorizing notes, tasks, and more. Allows creating/deleting tags, assigning to entities, and searching by tag.

### Tasks Module
Manages tasks with priorities, deadlines, and subtasks. Enables adding/completing tasks, setting reminders, and filtering by status or priority.

### Widget Module
Provides custom widgets for home screens or dashboards. Supports configurable widgets with periodic data updates.

## Shared and Infrastructure Modules

### Shared Module (core/shared/)
Cross-cutting utilities including logging and extensions. Handles date formatting/validation and shared constants.

### Persistence Module (infrastructure/persistence/)
Data storage using Drift (SQLite). Supports CRUD operations via repositories and database migrations.

### Platform-Specific Infrastructure
Platform-specific implementations for notifications, file systems, and more. Includes Android usage stats/reminders, desktop system tray/notifications, Linux window management, mobile wakelock/notifications, and Windows audio handling.

**Usage Instructions**:
- Enable in settings: `DemoService.enableDemos(true);`.
- Reference: [`demo_service.dart`](core/application/features/demo/services/demo_service.dart).

**Best Practices**:
- Keep demos isolated: Use feature flags.
- `chore(demo): update mock data for new features`.

### Habits Module
**Overview**: Tracks user habits with streaks, reminders, and progress analytics.

**Folder Structure**:
- `core/application/features/habits/`: Commands, constants, queries, services.
- `core/domain/features/habits/`: Domain models.
- `infrastructure/persistence/features/habits/`: Database schemas.
- `presentation/ui/features/habits/`: (Inferred UI).

**Key Functionalities**:
- Create/edit habits.
- Track daily completions.
- Generate streak reports.

**Dependencies**:
- `acore/lib/queries/` for habit queries.
- `infrastructure/persistence/shared/repositories/drift/` for storage.

**Usage Instructions**:
- Command: `habitsCommands.createHabit(HabitModel(name: 'Exercise'));`.
- Query: `habitsQueries.getActiveHabits()`.
- Reference: [`habits_service.dart`](core/application/features/habits/services/habits_service.dart).

**Best Practices**:
- Validate habit data: Non-empty names, valid frequencies.
- `feat(habits): add gamification badges` for engagement.

### Notes Module
**Overview**: Note-taking with rich text, tagging, and search.

**Folder Structure**:
- `core/application/features/notes/`: Commands, constants, queries, services.
- `core/domain/features/notes/`: Domain.
- `infrastructure/persistence/features/notes/`: Persistence.
- `presentation/ui/features/notes/`: UI.

**Key Functionalities**:
- CRUD operations for notes.
- Attach tags.
- Search and filter notes.

**Dependencies**:
- `core/application/features/tags/` for tagging.
- `acore/lib/mapper/` for DTO mapping.

**Usage Instructions**:
- Service: `notesService.saveNote(NoteModel(content: 'Hello'));`.
- Cross-ref: Integrate with tags via `tagsService.assignTag(noteId, tagId)`.
- Reference: [`notes_queries.dart`](core/application/features/notes/queries/notes_queries.dart).

**Best Practices**:
- Encrypt sensitive notes.
- `fix(notes): prevent SQL injection in search`.

### Settings Module
**Overview**: App configuration, theme, privacy, and sync options.

**Folder Structure**:
- `core/application/features/settings/`: Commands, constants, queries, services.
- `core/domain/features/settings/`: Domain.
- `infrastructure/android/features/settings/`, etc.: Platform settings.
- `infrastructure/persistence/features/settings/`: Stored prefs.

**Key Functionalities**:
- Update user preferences.
- Theme switching.
- Export/import settings.

**Dependencies**:
- `acore/lib/dependency_injection/` for config injection.
- `infrastructure/shared/features/setup/` for initial setup.

**Usage Instructions**:
- Query: `settingsQueries.getTheme()`.
- Update: `settingsCommands.updateTheme(ThemeMode.dark);`.
- Reference: [`settings_service.dart`](core/application/features/settings/services/settings_service.dart).

**Best Practices**:
- Default to privacy-friendly settings.
- `docs(settings): add migration guide for v2.0`.

### Sync Module
**Overview**: Data synchronization across devices and backups.

**Folder Structure**:
- `core/application/features/sync/`: Commands, constants, models, queries, services.
- `core/domain/features/sync/`: Domain.
- `infrastructure/android/features/sync/`, `infrastructure/desktop/features/sync/`, etc.: Platform sync.
- `infrastructure/persistence/features/sync/`: Sync state.

**Key Functionalities**:
- Two-way sync with cloud (e.g., Firebase).
- Conflict resolution.
- Backup/restore.

**Dependencies**:
- `acore/lib/async/` for async operations.
- All feature modules for data syncing.

**Usage Instructions**:
- Trigger: `syncService.startSync();`.
- Handle conflicts: Implement `SyncModel` resolvers.
- Reference: [`sync_service.dart`](core/application/features/sync/services/sync_service.dart).

**Best Practices**:
- Offline-first: Queue changes.
- `feat(sync): add end-to-end encryption`.

### Tags Module
**Overview**: Manage tags for categorization across notes, tasks, etc.

**Folder Structure**:
- `core/application/features/tags/`: Commands, constants, models, queries, services.
- `core/domain/features/tags/`: Domain.
- `infrastructure/persistence/features/tags/`: Storage.

**Key Functionalities**:
- Create/delete tags.
- Assign to entities.
- Search by tag.

**Dependencies**:
- `core/shared/models/` for tag models.

**Usage Instructions**:
- `tagsService.createTag(TagModel(name: 'Work'));`.
- Reference: [`tags_models.dart`](core/application/features/tags/models/tags_models.dart).

**Best Practices**:
- Limit tag hierarchy depth.
- `refactor(tags): optimize query performance`.

### Tasks Module
**Overview**: Task management with priorities, deadlines, and subtasks.

**Folder Structure**:
- `core/application/features/tasks/`: Commands, constants, queries, services.
- `core/domain/features/tasks/`: Models.
- `infrastructure/persistence/features/tasks/`: DB.
- `presentation/ui/features/tasks/`: UI.

**Key Functionalities**:
- Add/complete tasks.
- Set reminders.
- Filter by status/priority.

**Dependencies**:
- `core/application/features/calendar/` for deadlines.
- `infrastructure/shared/features/notification/` for reminders.

**Usage Instructions**:
- `tasksCommands.addTask(TaskModel(title: 'Buy groceries', due: DateTime.now().add(Duration(days:1))));`.
- Reference: [`tasks_service.dart`](core/application/features/tasks/services/tasks_service.dart).

**Best Practices**:
- Use enums for priorities.
- `test(tasks): cover edge cases like overdue tasks`.

### Widget Module
**Overview**: Custom widgets for home screen or dashboard.

**Folder Structure**:
- `core/application/features/widget/`: Models, services.
- `presentation/ui/app/services/`: Widget management.

**Key Functionalities**:
- Configurable home widgets.
- Update widget data periodically.

**Dependencies**:
- Platform-specific: `infrastructure/android/features/widget/` (inferred).

**Usage Instructions**:
- `widgetService.updateData();`.
- Reference: [`widget_models.dart`](core/application/features/widget/models/widget_models.dart).

**Best Practices**:
- Optimize for battery: Minimize updates.
- `feat(widget): support dynamic sizing`.

## Shared and Infrastructure Modules

### Shared Module (core/shared/)
**Overview**: Cross-cutting utilities like logging, extensions.

**Folder Structure**:
- `core/shared/utils/`: Helper functions.

**Key Functionalities**:
- Date formatting, validation.
- Shared constants.

**Dependencies**: None (base layer).

**Usage Instructions**:
- Import: `import 'package:whph/core/shared/utils/utils.dart';`.
- Reference: [`utils.dart`](core/shared/utils/utils.dart).

**Best Practices**:
- Keep pure functions.
- `chore(shared): bump utility versions`.

### Persistence Module (infrastructure/persistence/)
**Overview**: Data storage using Drift (SQLite).

**Folder Structure**:
- `infrastructure/persistence/features/*/`: Per-feature tables.
- `infrastructure/persistence/shared/contexts/drift/schemas/app_database/`: Schema.

**Key Functionalities**:
- CRUD via repositories.
- Migrations.

**Dependencies**:
- `acore/lib/repository/abstraction/`.

**Usage Instructions**:
- Use DriftDatabase: `AppDatabase.instance`.
- Reference: [`app_database.dart`](infrastructure/persistence/shared/contexts/drift/schemas/app_database/app_database.dart).

**Best Practices**:
- Index frequently queried fields.
- `fix(persistence): handle schema conflicts`.

### Platform-Specific Infrastructure
- **Android (infrastructure/android/)**: Usage stats, file system, reminders.
- **Desktop (infrastructure/desktop/)**: Notifications, system tray, single instance.
- **Linux (infrastructure/linux/)**: Window management, file system.
- **Mobile (infrastructure/mobile/)**: Notifications, wakelock.
- **Windows (infrastructure/windows/)**: Audio, file system.

**Usage Instructions**: Abstract via `abstraction/` interfaces.
**Best Practices**: Test per platform; use `feat(infrastructure:android): ...`.

## Contribution Guidelines
- Follow folder structure for new features: Add to all layers (domain, application, infrastructure, presentation).
- Run `flutter analyze` before commits.
- Use semantic commits strictly.
- For cross-references, update this doc: `docs(modules): add new feature section`.
- Test thoroughly: Unit (services), Integration (sync), UI (widgets).

This documentation is auto-generated based on project structure as of [current date]. Update via PRs.