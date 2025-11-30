# Implement Task Management Module

> RFC: 001
> Status: Implemented

## Summary

This RFC proposes the implementation of the task management module within WHPH's modular architecture, utilizing core/application/features/tasks/ for services and queries. It enables users to create, organize, schedule, and track tasks with subtasks, recurrence, and time recording using Flutter for cross-platform UI and Drift for persistent storage, forming the foundational productivity feature.

## Motivation

The PRD identifies task management as core for productivity users (sections 2.1, 4.1). It requires tools for priorities, deadlines, and tracking to optimize routines, fulfilling the unified hub (section 1.3). WHPH addresses gaps in open-source apps through local-first design with modular dependencies on calendar and notifications modules.

## Detailed Design

Implemented in Flutter/Dart with clean architecture: domain models in core/domain/features/tasks/, application layer in core/application/features/tasks/ for commands/queries/services, persistence via Drift in infrastructure/persistence/features/tasks/, and UI in presentation/ui/features/tasks/. Key components:

### Data Models

- **Task Entity** (core/domain/features/tasks/models/task_model.dart): Fields: id (UUID), title (String), description (String), priority (enum: Low/Medium/High), deadline (DateTime?), estimatedTime (Duration?), actualTime (Duration), isCompleted (bool), parentId (UUID? for subtasks), recurrenceRule (String? e.g., "daily"), createdAt/updatedAt (DateTime).
- **Subtask Relationship**: Hierarchical via foreign keys in Drift schema.
- **Storage**: Drift (SQLite) with tables for tasks and relations; indexes on parentId/deadline. Migrations handled via DriftDatabase.

### UI Components

- **Task List View** (presentation/ui/features/tasks/widgets/task_list_view.dart): ListView.builder with Cards, checkboxes, progress bars; sortable by priority/deadline.
- **Task Creation/Edit Screen**: Form with TextFormFields, DropdownButton, DateTimePicker; dynamic subtasks list.
- **Calendar Integration**: table_calendar package for views, events from tasks; recurring expanded on-the-fly.
- **Time Tracking**: Timer widget logging to DB; integrates with notifications module for reminders.

### APIs and Logic

- **CRUD Operations**: Provider for state; commands like createTask() in tasks_service.dart insert via Drift repository, notify UI.
- **Recurrence Handling**: rrule package; creates next instance on completion.
- **Querying**: tasks_queries.dart with DAO methods for filters (overdue, subtasks); search via FTS.
- **Cross-Platform Adaptations**: Keyboard shortcuts (desktop), gestures (mobile) via platform channels.
- **Integration**: Depends on calendar module for deadlines, notifications for reminders; tags for categorization.

Trade-offs: Local Drift storage prioritizes privacy over collaboration; relational schema suits hierarchies but adds migration complexity.

Assumptions: Uses drift for DB (core/shared/repositories/drift/); table_calendar, rrule libraries GPL-compatible. Offline conflicts resolved by last-modified timestamps in sync module.

## Alternatives Considered

- **Cloud Sync (Firebase)**: Rejected for privacy (PRD 1.3, 5.1.3).
- **NoSQL (Hive)**: Dismissed for relational needs; Drift better for queries.
- **Flat Lists**: Insufficient for hierarchies (PRD 4.1).

## Implementation Notes

Phases: 1) Models/DB schema (Week 1-2), 2) CRUD UI/services (Week 3-4), 3) Recurrence/time (Week 5), 4) Testing/adaptations (Week 6). Challenges: Recurring deletions (soft-delete flags); timer accuracy (platform channels). Outcomes: 95% coverage; <200ms queries for 1000+ tasks. Integrated with search/themes.

## References

- [PRD 3.1](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L45-L52), [4.1](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L137-L145).
- [MODULES.md: Tasks Module](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L239-L264).
- Flutter: [Provider](https://pub.dev/packages/provider).
- Drift: [SQLite ORM](https://pub.dev/packages/drift).
- table_calendar: [Calendar Widget](https://pub.dev/packages/table_calendar).
