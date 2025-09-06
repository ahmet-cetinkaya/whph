# Project Modules Documentation

This document provides an overview of the modules in the WHPH project, a cross-platform application built with Flutter/Dart. Modules are organized in feature folders to promote modularity.

## Core Modules

### About Module
**Overview**: Displays app information, version, licenses, and credits with localization support.

**Folder Structure**:
- `core/application/features/about/`: Commands, queries, services.
- `core/domain/features/about/`: Domain models.
- `presentation/ui/features/about/`: UI components.

**Key Functionalities**:
- Renders dynamic about pages.
- Loads multi-language strings.
- Shows open-source licenses.

**Dependencies**:
- Localization services.
- Package info utilities.

**Usage Instructions**:
- Query: `aboutQueries.getAppInfo()`.
- Reference: [`about_service.dart`](core/application/features/about/services/about_service.dart).

**Best Practices**:
- Cache license data for performance.
- `docs(about): update credits for new contributors`.

### App Usages Module
**Overview**: Tracks app usage statistics like time spent and sessions across platforms.

**Folder Structure**:
- `core/application/features/app_usages/`: Commands, constants, queries, services.
- `core/domain/features/app_usages/`: Domain models.
- `infrastructure/persistence/features/app_usages/`: Database schemas.
- `presentation/ui/features/app_usages/`: UI (inferred).

**Key Functionalities**:
- Logs open/close events.
- Queries daily/weekly stats.
- Uses platform-specific APIs (e.g., Android UsageStatsManager, desktop timers).

**Dependencies**:
- Platform infrastructure modules.
- Persistence for storage.

**Usage Instructions**:
- Service: `appUsagesService.logSessionStart()`.
- Query: `appUsagesQueries.getWeeklyStats()`.
- Reference: [`app_usages_service.dart`](core/application/features/app_usages/services/app_usages_service.dart).

**Best Practices**:
- Respect privacy: Opt-in tracking.
- `feat(app-usages): add export functionality`.

### Calendar Module
**Overview**: Handles calendar events, reminders, and scheduling.

**Folder Structure**:
- `core/application/features/calendar/`: Commands, queries, services.
- `core/domain/features/calendar/`: Domain models.
- `infrastructure/persistence/features/calendar/`: Storage (if needed).
- `presentation/ui/features/calendar/`: UI.

**Key Functionalities**:
- Create/view events.
- Set recurring reminders.
- Sync with device calendars across platforms.

**Dependencies**:
- Notifications module.
- Date utilities from shared.

**Usage Instructions**:
- Command: `calendarCommands.createEvent(EventModel(title: 'Meeting'))`.
- Reference: [`calendar_service.dart`](core/application/features/calendar/services/calendar_service.dart).

**Best Practices**:
- Handle time zones consistently.
- `fix(calendar): resolve sync conflicts`.

### Demo Module
**Overview**: Provides sample features for testing and onboarding.

**Folder Structure**:
- `core/application/features/demo/`: Commands, services.
- `core/domain/features/demo/`: Mock models.

**Key Functionalities**:
- Generates mock data.
- Demonstrates workflows for other modules.

**Dependencies**:
- All feature modules for integration testing.

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
**Overview**: Platform-specific implementations for notifications, file systems, and more.

**Folder Structure**:
- `infrastructure/android/`: Usage stats, reminders.
- `infrastructure/desktop/`: System tray, notifications.
- `infrastructure/linux/`: Window management, file system.
- `infrastructure/mobile/`: Wakelock, notifications.
- `infrastructure/windows/`: Audio, file system.

**Key Functionalities**:
- Platform adaptations for core features.

**Dependencies**:
- Shared abstractions.

**Usage Instructions**:
- Abstract via `abstraction/` interfaces.

**Best Practices**:
- Test per platform.
- `feat(infrastructure:android): add new API integration`.

## Contribution Guidelines
- Follow folder structure for new features: Add to all layers (domain, application, infrastructure, presentation).
- Run `flutter analyze` before commits.
- Use semantic commits strictly.
- For cross-references, update this doc: `docs(modules): add new feature section`.
- Test thoroughly: Unit (services), Integration (sync), UI (widgets).

This documentation is auto-generated based on project structure as of 2025-09-06. Update via PRs.