# Implement Habit Tracking Module

> RFC: 002
> Status: Implemented

## Summary

This RFC outlines the habit tracking module in WHPH's feature-based architecture, using core/application/features/habits/ for commands/queries/services. It enables defining, monitoring, and analyzing habits with streaks, calendar views, goals, reminders, and archiving via Flutter UI and Drift storage, complementing tasks for long-term consistency in the productivity hub.

## Motivation

Habit formation supports productivity routines (PRD 2.1, 4.2), requiring tracking, visuals, and reminders for accountability. It addresses gaps in checklists without analytics/cross-platform support, aligning with intelligent insights (PRD 1.3) through modular, local-first design integrating with notifications and calendar modules.

## Detailed Design

Follows clean architecture: domain in core/domain/features/habits/, application layer in core/application/features/habits/, persistence via Drift in infrastructure/persistence/features/habits/, UI in presentation/ui/features/habits/. Core elements:

### Data Models

- **Habit Entity** (core/domain/features/habits/models/habit_model.dart): Fields: id (UUID), name (String), description (String), goal (int), frequency (enum: Daily/Weekly/Monthly), streak/currentStreak (int), lastCompleted (DateTime?), createdAt/updatedAt (DateTime), isArchived (bool).
- **Completion Log**: Table with habitId (foreign key), completionDate (DateTime), notes (String?).
- **Storage**: Drift (SQLite) with tables/indexes on habitId/completionDate; migrations via DriftDatabase.

### UI Components

- **Habit List View** (presentation/ui/features/habits/widgets/habit_list_view.dart): ListView Cards with streaks, progress; color-coded.
- **Habit Creation/Edit Screen**: Form with TextFields, Slider for goal, Dropdown for frequency, Toggle for reminders.
- **Calendar View**: table_calendar package for completions/heatmaps; integrates with calendar module.
- **Streak Visualization**: fl_chart for line/bar charts of history/progress.
- **Reminder System**: flutter_local_notifications for alerts, configurable per habit.

### APIs and Logic

- **CRUD Operations**: Provider state; createHabit() in habits_service.dart inserts via Drift repo; logCompletion() updates streak via queries.
- **Streak Calculation**: Method in service checks consecutive dates, resets on misses; weekly aggregation.
- **Archiving**: Soft-delete isArchived flag; separate view.
- **Querying**: habits_queries.dart with DAO for status/progress; search by name/description using FTS.
- **Cross-Platform**: Haptics (mobile), drag-reorder (desktop) via platform channels.
- **Integration**: Depends on notifications for reminders, calendar for views; tags for categorization.

Trade-offs: Local Drift ensures privacy but limits sharing; simple streak logic timezone-mitigated with UTC, may need sync module for multi-device.

Assumptions: Uses drift for DB (infrastructure/persistence/shared/repositories/drift/); libraries fl_chart, table_calendar, flutter_local_notifications GPL-compatible. Offline conflicts resolved timestamp-based in sync module.

## Alternatives Considered

- **Cloud Sync (Firebase)**: Rejected for privacy (PRD 5.1.3); P2P preferred.
- **ObjectBox over Drift**: Rejected for GPL/relational needs.
- **External Integration (Habitica)**: Avoided for self-containment; custom enables linking.
- **Text-Only Progress**: Insufficient for visuals (PRD 4.2); fl_chart adds value.

## Implementation Notes

Phases: 1) Models/DB (Week 2), 2) Tracking UI (Week 3), 3) Calendar/streaks (Week 4), 4) Reminders/testing (Week 5). Challenges: Streak resets (date comparisons). Outcomes: Supports 500+ habits, real-time; 90% coverage. Performance: <100ms queries. Integrated with themes/search.

## References

- [PRD 3.1](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L53-L60), [4.2](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L146-L155).
- [MODULES.md: Habits Module](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L107-L133).
- Flutter: [Local Notifications](https://pub.dev/packages/flutter_local_notifications).
- fl_chart: [Charts](https://pub.dev/packages/fl_chart).
- Drift: [ORM](https://pub.dev/packages/drift).

