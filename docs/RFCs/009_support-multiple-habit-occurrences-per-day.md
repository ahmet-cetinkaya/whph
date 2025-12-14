# Support Multiple Habit Occurrences per Day

> RFC: 009
> Status: Proposed

## Summary

This RFC proposes enhancements to the habits module (RFC 002) to support logging multiple completions of the same habit per day (e.g., medication three times daily), extending HabitRecord with timestamps while maintaining streaks, statistics, reminders, and UI consistency. Implemented via updates to domain models, Drift persistence, application logic, and UI in core/application/features/habits/, addressing current one-per-day limitations for better user flexibility in habit goals.

## Motivation

Current habit tracking assumes one completion per day, limiting scenarios like multi-dose habits (implied in PRD 3.1 habit goals, section 57). Users need granular logging for accurate progress toward daily targets >1, enhancing accountability and analytics without disrupting existing streaks/UI. This evolution aligns with intelligent insights (PRD 1.3) and modular extensibility, filling gaps for habit formation seekers (PRD 2.1, 4.2).

## Detailed Design

Follows clean architecture: updates to core/domain/features/habits/models/, core/application/features/habits/ for commands/queries/services, infrastructure/persistence/features/habits/ via Drift, presentation/ui/features/habits/ for UI. Key changes:

### Data Models

- **HabitRecord Extension** (core/domain/features/habits/models/habit_record_model.dart): Add occurredAt (DateTime timestamp); derive recordDate as DateTime(occurredAt.year, month, day). Remove unique constraint on (habitId, date).
- **Habit Update**: Add dailyTarget (int? nullable, default 1); migration sets NULL for legacy (interpret as 1).
- **Storage**: Drift schema ALTER TABLE habit_record ADD COLUMN occurred_at TEXT; UPDATE back-fill from date; RENAME date to record_date; INDEX on (habitId, record_date). New query countByHabitIdAndDate(habitId, DateTime date).

### UI Components

- **Habit Edit Screen** (presentation/ui/features/habits/screens/habit_edit_screen.dart): Add input for "Times per day" (Stepper, default 1).
- **Habit List/Calendar Widgets** (presentation/ui/features/habits/widgets/habit_card.dart, habit_calendar_view.dart): Replace checkmark with badge "n/m" (actual/target); tap adds record (occurredAt=now), long-press subtracts last of day.
- **Statistics View**: Bar chart percentage completion (actual/target) per day if target>1; adapt streaks (day complete if count ≥ target).
- **Notifications**: Dynamic reminder times (e.g., spaced for target=3); integrate with notifications module.

### APIs and Logic

- **Commands**: AddHabitRecordCommand accepts occurredAt (default now), no uniqueness; in habits_service.dart, insert via Drift repo without constraint.
- **Queries**: Update GetHabitQuery/GetListHabitRecordsQuery to group by recordDate, calculate daily score = actualOccurrences / dailyTarget; streak if score ≥1. Helper countByHabitIdAndDate in habits_queries.dart.
- **Validation**: Non-empty names, valid frequencies/targets; UI prevents >target logging if desired.
- **Cross-Platform**: Timestamp handling UTC; haptics on log (mobile), keyboard shortcuts (desktop).
- **Integration**: Depends on notifications for multi-reminders, calendar for views; sync module for multi-occurrence transfer (timestamp-based conflicts).

Trade-offs: Adds complexity to queries (aggregation overhead, mitigated by indexes <10ms); backward-compatible migration preserves legacy data. No cascade deletes assumed safe.

Assumptions: Current DB no foreign key issues; statistics centralized in GetHabitQueryHandler. Libraries: Drift for migrations/queries GPL-compatible. Feature flag for rollout; open questions (e.g., deletion undo) resolved in implementation.

## Alternatives Considered

- **New Habit Type (e.g., Medication)**: Less flexible; universal extension better for all habits (PRD goal setting).
- **No Timestamp (just count column)**: Loses timing granularity for reminders/export; full occurredAt enables precise analytics.
- **Generic Reminders Only**: Insufficient for spaced multi-reminders; dynamic list aligns with configurable alerts (PRD 3.3).
- **No Migration (break legacy)**: Risky data loss; script ensures compatibility.

## Implementation Notes

### Phase 1: Domain & Persistence Foundation

**Objective:** Lay the groundwork by extending the data models and updating the persistence layer to accommodate multiple habit occurrences per day, ensuring backward compatibility for existing records.

**Key Tasks:**

1. Introduce `occurredAt` column to `HabitRecord`.
   - Type: `DateTime` (full timestamp).
   - Replace or supplement existing `date` field; derive `recordDate` as date-only from `occurredAt`.
2. Implement Drift migrations using a safe create-copy-drop-rename strategy:
   - Create a new table `habit_record_table_new` with `occurred_at INTEGER NOT NULL` replacing the old `date` column.
   - Copy data from the old table, mapping `date` to `occurred_at`.
   - Drop the old table and rename the new one to `habit_record_table`.
   - Add `daily_target INTEGER` column to `habit_table`.
   - Create index `idx_habit_record_habit_occurred_at ON habit_record_table (habit_id, occurred_at)` for query performance.
3. Adjust domain entity:

   ```dart
   class HabitRecord extends BaseEntity<String> {
     String habitId;
     DateTime occurredAt;         // new field
     DateTime get recordDate => DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
   }
   ```

4. Update repository methods:
   - Modify insert/update to include `occurredAt` (required).
   - Add helper query: `countByHabitIdAndDate(habitId, DateTime date)` for daily counts.
   - Remove unique constraint on `(habitId, date)`.

**Dependencies:** None (initial phase).

**Success Criteria:**

- Migration completes without data loss or errors on sample legacy data.
- Queries execute correctly, returning accurate daily counts (<10ms with index).

### Phase 2: Application Logic

**Objective:** Enhance commands, queries, and services to handle multiple occurrences, including daily targets, scoring, and streak calculations.

**Key Tasks:**

1. Update commands:
   - `AddHabitRecordCommand`: Accept optional `occurredAt` (defaults to `DateTime.now()`); remove uniqueness check.
2. Revise queries:
   - In `GetHabitQuery` and `GetListHabitRecordsQuery`: Group by `recordDate`, compute daily score as `actualOccurrences / dailyTarget`.
   - Update streak logic: A day is complete if daily count ≥ `dailyTarget`.
3. Introduce new field in `Habit` model:
   - `int? dailyTarget;` (nullable for backward compatibility; interpret NULL as 1).
   - Include in migration to set NULL for legacy habits.

**Dependencies:** Completion of Phase 1 (domain models and persistence).

**Success Criteria:**

- Commands insert multiple records per day without errors.
- Queries return correct daily scores and streaks for habits with `dailyTarget > 1`.

### Phase 3: UI Enhancements

**Objective:** Update user interfaces to support input of daily targets, visual feedback for multiple completions, and adapted statistics and notifications.

**Key Tasks:**

1. Modify `Habit Edit Screen` (`presentation/ui/features/habits/screens/habit_edit_screen.dart`):
   - Add input field for "Times per day" using a stepper (default: 1, max: 10).
2. Update habit list and calendar widgets (`presentation/ui/features/habits/widgets/habit_card.dart`, `habit_calendar_view.dart`):
   - Replace checkmark with badge showing "n/m" (actual/target).
   - Implement tap logic: Tap adds record with current timestamp; long-press subtracts/deletes last occurrence of the day.
3. Adapt `Statistics View`:
   - Display bar chart for percentage completion (actual/target) per day when `dailyTarget > 1`.
   - Ensure streaks reflect completion based on target.
4. Integrate notifications:
   - Support dynamic reminder scheduling (e.g., spaced intervals for `dailyTarget = 3`).
   - Link to notifications module for multi-reminder handling.

**Dependencies:** Phases 1 and 2 (data and logic availability).

**Success Criteria:**

- UI inputs and displays update in real-time without crashes.
- Badge and tap interactions correctly log/view multiple occurrences.

### Phase 4: Data Migration & Backward Compatibility

**Objective:** Ensure seamless transition for existing data and users, with safeguards for rollout.

**Key Tasks:**

1. Bump version in `pubspec.yaml` and Drift schema.
2. Develop and test migration:
   - Unit tests for inserting and migrating legacy records.
   - Back-fill `occurredAt` from existing `date` fields.
3. Implement feature flag:
   - Toggle multi-occurrence support until fully stable.

**Dependencies:** All prior phases (full functionality implemented).

**Success Criteria:**

- Migration preserves all legacy data; tests pass on staging environment.
- Feature flag enables/disables changes without breaking core functionality.

### Phase 5: QA & Metrics

**Objective:** Validate the implementation through testing, performance checks, and user feedback to ensure reliability and usability.

**Key Tasks:**

1. Write unit tests for domain, persistence, and application logic.
2. Conduct UI and integration tests for screens and widgets.
3. Perform performance benchmarks (e.g., query times on large datasets).
4. Gather UX feedback and iterate on ambiguous elements (e.g., long-press semantics).

| Checkpoint  | Success Criteria                                                                                              |
| ----------- | ------------------------------------------------------------------------------------------------------------- |
| Unit Tests  | • Multiple records insertable same day without errors<br>• Queries return correct counts, scores, and streaks |
| UI Tests    | • Badges update real-time; editing targets recalculates stats<br>• Tap/long-press logic functions as expected |
| Performance | • Indexed queries <10ms on 10k records                                                                        |
| UX Feedback | • Clear understanding of badges, inputs, and multi-reminder flows                                             |

**Dependencies:** All prior phases.

**Success Criteria:** 95% test coverage, including migration; no critical bugs; positive UX validation.

**Challenges:** Ensure back-fill integrity during migration (tested on staging data); refine UI tap semantics (e.g., long-press for subtract).

**Outcomes:** Full support for daily targets up to 10; backward-compatible with legacy habits; enhanced analytics and reminders.

**Next Steps:** Confirm open questions (e.g., daily target requirement, deletion semantics, reminder complexity, export/sync integration); proceed with iterative implementation and version bumps after stakeholder review.

## References

- [PRD 3.1](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L53-L60), [4.2](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/PRD.md#L146-L155).
- [HABIT_ENHANCEMENTS.md: Full design plan](https://github.com/ahmet-cetinkaya/whph/blob/main/docs/HABIT_ENHANCEMENTS.md#L1-L148).
- [MODULES.md: Habits Module](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L107-L133), [Persistence](https://github.com/ahmet-cetinkaya/whph/blob/ea71256c1/docs/MODULES.md#L309-L330).
- Drift: [Migrations](https://drift.simonbinder.eu/docs/migrations/).
- Flutter: [Provider for Reactive UI](https://pub.dev/packages/provider).
