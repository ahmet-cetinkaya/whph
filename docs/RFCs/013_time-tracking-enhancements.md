# Time Tracking Enhancements — Architecture and Implementation Plan

> RFC: 013

> Status: Draft

> Related Issues: [#60](https://github.com/ahmet-cetinkaya/whph/issues/60)

## Summary
This RFC proposes comprehensive enhancements to WHPH's time tracking capabilities, addressing three main objectives: implementing a multi-mode timer (Normal + Pomodoro + Stopwatch), enabling manual time logging and editing for tasks, adding real timing support for habits with clarified semantics, and automatic insertion of estimated time records when habits are marked completed, with removal on unmarking to maintain accurate progress tracking for custom goals. The plan maintains backward compatibility and follows existing architectural patterns (Flutter + Drift, Mediator CQRS).

**Status Update**:
- ✅ Multi-mode timer system completed in `AppTimer` component with settings integration
- ✅ Task manual time logging completed with `TaskTimeLoggingDialog` and task details integration
- ✅ Habit time record infrastructure implemented: entity (`HabitTimeRecord`), repository (`IHabitTimeRecordRepository` and `DriftHabitTimeRecordRepository`), commands (`AddHabitTimeRecordCommand`, `RemoveHabitTimeRecordCommand`, `SaveHabitTimeRecordCommand`), database schema (`habit_time_record_table` in v24), and supporting tests
- ⏳ Next milestones: Habit time logging UI integration, automatic estimated time insertion on completion/uncompletion, and analytics integration

## Motivation

The current time tracking implementation has several limitations:

- **Timer inflexibility**: Only Pomodoro timer is available, limiting users who prefer simple stopwatch functionality
- **No retroactive logging**: Users cannot manually log time for completed tasks or correct inaccurate time records
- **Habit time estimation**: Habits use estimated time calculations (count × estimatedTime) rather than actual tracked time
- **No automatic time logging for habits**: Currently, no time is logged automatically when habits are completed; users must manually start timers or log time
- **Analytics gaps**: Time analytics rely on approximations for habits, reducing accuracy of productivity insights

Users frequently request the ability to:
- Use a simple timer without Pomodoro constraints
- Log time for tasks completed offline or without timer usage
- Track actual time spent on habits rather than estimates
- Automatically log estimated time when completing a habit for the day
- Edit or correct time records for accuracy

## Detailed Design

### 1. Current State Analysis

#### Timer Implementation
- **Pomodoro-only widget**: `presentation/ui/features/tasks/components/pomodoro_timer.dart`
- **Usage**: Marathon page integration with `onTimeUpdate` callbacks
- **Persistence**: Hour-bucketed time records via `AddTaskTimeRecordCommand`

#### Task Time Tracking
- **Domain**: `TaskTimeRecord` entity with duration, createdDate
- **Commands**: `AddTaskTimeRecordCommand`, `SaveTaskTimeRecordCommand`
- **Queries**: `getTotalDurationByTaskId`
- **UI**: Total duration display in task details

#### Habits
- **Current**: `HabitRecord` with occurrence timestamps only
- **Analytics**: Estimated time as `count(records) × estimatedTime`
- **Limitation**: No actual time tracking capability

### 2. Enhanced Architecture

#### A. Multi-Mode Timer System

**Location**: `src/lib/presentation/ui/features/tasks/components/timer.dart`

```dart
enum TimerMode { normal, pomodoro, stopwatch }

class AppTimer extends StatefulWidget {
  final VoidCallback? onTimerStart;
  final VoidCallback? onTimerStop;

  // Supports three timer modes with unified interface:
  // - Normal mode: Simple countdown timer with configurable duration
  // - Pomodoro mode: Traditional Pomodoro technique with work/break cycles
  // - Stopwatch mode: Count-up timer for open-ended time tracking
}
```

**Features**:
- Three distinct timer modes in a single component
- Mode switching via settings dialog integration
- System tray integration and keep-screen-awake support
- Responsive UI that adapts to screen size
- Comprehensive settings management for each mode

#### B. Manual Time Logging

**Location**: `src/lib/core/application/features/tasks/commands/add_task_time_record_command.dart`

```dart
class AddTaskTimeRecordCommand implements IRequest<AddTaskTimeRecordCommandResponse> {
  final String taskId;
  final int duration;
  final DateTime? customDateTime; // New: Support retroactive logging

  AddTaskTimeRecordCommand({
    required this.taskId,
    required this.duration,
    this.customDateTime, // Defaults to DateTime.now() if not provided
  });
}
```

**Capabilities**:
- Retroactive time entry with custom timestamps
- Hour-bucket preservation for existing analytics
- "Set total for day" functionality with delta calculations
- Manual time adjustment commands

#### C. Habit Time Tracking

**Location**: `src/lib/core/domain/features/habits/habit_time_record.dart`

Additionally, when a habit is marked as completed for a specific day (via `HabitRecord` creation or update), an automatic `HabitTimeRecord` will be inserted with the habit's `estimatedTime` as the duration for that day's timestamp. If the habit is later unmarked as uncompleted, the corresponding `HabitTimeRecord` for that day will be removed or its duration set to 0, ensuring accurate tracking. This automatic mechanism integrates with custom goals and progress tracking by updating derived calculations (e.g., goal progress percentages) that rely on total time spent, using the actual or estimated time records as the source of truth. Manual overrides via timer or logging will take precedence over automatic estimates.

```dart
@jsonSerializable
class HabitTimeRecord extends BaseEntity<String> {
  final String habitId;
  final int duration; // Duration in seconds

  HabitTimeRecord({
    required super.id,
    required this.habitId,
    required this.duration,
    required super.createdDate,
    super.modifiedDate,
    super.deletedDate,
  });
}
```

**Database Schema**:
```sql
CREATE TABLE habit_time_record_table (
  id TEXT NOT NULL PRIMARY KEY,
  habit_id TEXT NOT NULL,
  duration INTEGER NOT NULL,
  created_date INTEGER NOT NULL,
  modified_date INTEGER,
  deleted_date INTEGER
);

CREATE INDEX idx_habit_time_record_habit_date
ON habit_time_record_table(habit_id, created_date);
```

### 3. Data Layer Implementation

#### A. Repository Interface

**Location**: `src/lib/core/domain/features/habits/i_habit_time_record_repository.dart`

```dart
abstract class IHabitTimeRecordRepository extends IBaseRepository<HabitTimeRecord, String> {
  Future<int> getTotalDurationByHabitId(String habitId, {DateTime? startDate, DateTime? endDate});
  Future<List<HabitTimeRecord>> getByHabitId(String habitId);
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end);
}
```

#### B. Drift Repository Implementation

**Location**: `src/lib/infrastructure/persistence/features/habits/drift_habit_time_record_repository.dart`

```dart
class DriftHabitTimeRecordRepository extends BaseDriftRepository<HabitTimeRecord, String>
    implements IHabitTimeRecordRepository {

  @override
  Future<int> getTotalDurationByHabitId(String habitId, {DateTime? startDate, DateTime? endDate}) {
    // Query sum of duration for habit within date range
  }

  @override
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end) {
    // Query habit time records within date range
  }
}
```

### 4. Command and Query Updates

#### A. Enhanced Task Commands

**Location**: Update existing task time record commands

```dart
class AddTaskTimeRecordCommandHandler implements IRequestHandler<AddTaskTimeRecordCommand, AddTaskTimeRecordCommandResponse> {
  @override
  Future<AddTaskTimeRecordCommandResponse> handle(AddTaskTimeRecordCommand request) async {
    final targetDate = request.customDateTime ?? DateTime.now().toUtc();
    final hourBucket = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, targetDate.hour);

    // Find or create record within hour bucket
    // Apply duration with proper bucketing logic
  }
}
```

#### B. New Habit Commands

These commands support both manual and automatic time logging for habits. The automatic insertion/removal is triggered in the handler for habit completion updates.

**Location**: `src/lib/core/application/features/habits/commands/`

```dart
class AddHabitTimeRecordCommand implements IRequest<AddHabitTimeRecordCommandResponse> {
  final String habitId;
  final int duration;
  final DateTime? customDateTime; // For manual or automatic insertion
  final bool isEstimated; // Flag to indicate if this is an automatic estimated entry

  AddHabitTimeRecordCommand({
    required this.habitId,
    required this.duration,
    this.customDateTime,
    this.isEstimated = false,
  });
}

class RemoveHabitTimeRecordCommand implements IRequest<RemoveHabitTimeRecordCommandResponse> {
  final String habitId;
  final DateTime targetDate; // Remove estimated entry for this day

  RemoveHabitTimeRecordCommand({
    required this.habitId,
    required this.targetDate,
  });
}

class SaveHabitTimeRecordCommand implements IRequest<SaveHabitTimeRecordCommandResponse> {
  final String habitId;
  final int totalDuration;
  final DateTime targetDate;
}
```

#### C. Updated Analytics Queries

**Location**: Update `src/lib/core/application/features/tags/queries/get_tag_times_data_query.dart`

```dart
class GetTagTimesDataQueryHandler {
  Future<GetTagTimesDataQueryResponse> handle(GetTagTimesDataQuery request) async {
    // For habits: Try to get actual or automatic estimated time from HabitTimeRecord
    final habitTrackedTime = await _habitTimeRecordRepository.getTotalDurationByHabitId(
      habitId,
      startDate: request.startDate,
      endDate: request.endDate
    );

    // No fallback needed as automatic estimated records ensure coverage for completed habits;
    // If no record (uncompleted), time is 0
    final habitTime = habitTrackedTime;
  }
}
```

### 5. User Interface Components

#### A. Multi-Mode Timer Integration

**Location**: `src/lib/presentation/ui/features/tasks/pages/marathon_page.dart`

The existing `AppTimer` component is already integrated and supports all three timer modes:

```dart
class MarathonPage extends StatefulWidget {
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // AppTimer with multi-mode support
          AppTimer(
            onTimerStart: _onTimerStart,
            onTimerStop: _onTimerStop,
          ),
          // Existing task list and controls
        ],
      ),
    );
  }
}
```

**Current Implementation**:
- Mode switching via settings dialog (gear icon when timer is stopped)
- Persistent settings storage with real-time updates
- Responsive UI that scales based on screen size
- Integration with system tray and notification services

#### B. Manual Logging UI

**Location**: `src/lib/presentation/ui/features/tasks/components/task_time_logging_dialog.dart`

```dart
class TaskTimeLoggingDialog extends StatefulWidget {
  final String taskId;

  // DateTime picker for retroactive logging
  // Duration input (hours:minutes:seconds)
  // "Log Time" vs "Set Total for Day" options
  // Validation and error handling
}
```

**Integration**: Add to task details page as action buttons

#### C. Habit Timer Integration

In addition to manual timer usage, habit completion toggles (marking as completed/uncompleted for a day) will automatically trigger `AddHabitTimeRecordCommand` with estimated time or `RemoveHabitTimeRecordCommand`, respectively, via the habit update handler.

**Location**: Update `src/lib/presentation/ui/features/habits/components/habit_details_content.dart`

```dart
class HabitDetailsContent extends StatelessWidget {
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Existing habit info

        // Add timer section using existing AppTimer
        AppTimer(
          onTimerStart: () => _onHabitTimerStart(),
          onTimerStop: () => _onHabitTimerStop(),
        ),

        // Time display: actual vs estimated
        HabitTimeDisplay(
          habitId: habit.id,
          showActualTime: true,
        ),
      ],
    );
  }
}
```

#### D. Enhanced Time Display

**Location**: `src/lib/presentation/ui/features/habits/components/habit_time_display.dart`

```dart
class HabitTimeDisplay extends StatelessWidget {
  final String habitId;
  final bool showActualTime;

  // Shows "Time spent today: 1h 30m" for actual time
  // Shows "Time spent today: ~45m (estimated)" for calculated time
  // Tooltip explaining the difference
}
```

### 6. Database Migration

**Location**: Update `src/lib/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart`

```dart
@DriftDatabase(
  tables: [
    // Existing tables...
    HabitTimeRecordTable,
  ],
  version: 24, // Updated to v24 with HabitTimeRecordTable
)
class DriftAppContext extends _$DriftAppContext {

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 24) {
        // Create habit_time_record_table
        await migrator.createTable(habitTimeRecordTable);
        await migrator.createIndex(Index('idx_habit_time_record_habit_date',
          'habit_time_record_table', ['habit_id', 'created_date']));
      }
    },
  );
}
```

## Implementation Plan

### Phase 1: Core Infrastructure ✅ COMPLETED
1. **Data Model Creation**
   - Create `HabitTimeRecord` entity ✅
   - Implement Drift table and repository ✅
   - Add database migration for new table (v24) ✅
   - Register repository in DI container ✅

2. **Command Enhancement**
   - Update `AddTaskTimeRecordCommand` with `customDateTime` ✅
   - Create `AddHabitTimeRecordCommand` and handler ✅
   - Implement hour-bucket logic for custom dates ✅

### Phase 2: Timer Enhancement ✅ COMPLETED
1. **Multi-Mode Timer Component** ✅ COMPLETED
   - Enhanced `AppTimer` with three modes: Normal, Pomodoro, Stopwatch ✅
   - Added system tray and keep-awake integration for all modes ✅

2. **Settings Integration** ✅ COMPLETED
   - Created `TimerSettingsDialog` with mode selection and configuration ✅
   - Implemented debounced saving and real-time settings updates ✅
   - Added comprehensive settings management for all timer modes ✅

### Phase 3: Manual Logging ✅ PARTIALLY COMPLETED
1. **Task Time Logging** ✅ COMPLETED
   - Created `TaskTimeLoggingDialog` component with comprehensive UI ✅
   - Implemented "Add Time" and "Set Total for Day" modes ✅
   - Added delta calculation for total time setting ✅
   - Integrated with task details page as optional field ✅
   - Added `GetTotalDurationByTaskIdQuery` for current time retrieval ✅
   - Full internationalization support ✅

2. **Habit Time Logging** - PARTIALLY COMPLETED
   - Create habit-specific logging UI - PENDING
   - Implement actual vs estimated time display - PENDING
   - Add manual time entry for habits - PENDING
   - Integrate automatic estimated time insertion on habit completion/uncompletion in `UpdateHabitRecordCommandHandler` - PENDING
   - Ensure removal of estimated records affects custom goal progress calculations - PENDING

### Phase 4: Analytics Integration - PENDING
1. **Query Updates**
   - Update tag time queries to use actual habit time
   - Implement fallback to estimated time logic
   - Ensure backward compatibility

2. **UI Integration** ✅ PARTIALLY COMPLETED
   - AppTimer already integrated in MarathonPage with multi-mode support ✅
   - Task details page updated with manual time logging ✅
   - Update habit details pages - PENDING

### Phase 5: Testing and Polish - PARTIALLY COMPLETED
1. **Comprehensive Testing** - PARTIALLY COMPLETED
   - Unit tests for all new commands and queries ✅ (Added tests for `AddHabitTimeRecordCommand`, `HabitTimeRecord`, repository interface, Drift repo, `TimerMode`)
   - Widget tests for timer components - PENDING
   - Integration tests for time tracking workflows - PENDING

2. **Documentation and Localization**
   - Update help documentation - PENDING
   - Add new translation keys - PENDING
   - Update user guides - PENDING

## Security Considerations

- **Input Validation**: Validate duration inputs to prevent negative or excessive values
- **Date Constraints**: Limit retroactive logging to reasonable time ranges (e.g., last 30 days)
- **Data Integrity**: Ensure hour-bucket consistency when inserting custom-dated records
- **Performance**: Index optimization for habit time record queries by date range

## Testing Strategy

### Unit Tests

- Command handlers for task and habit time records ✅
- Hour-bucket logic with custom dates ✅
- Analytics query fallback behavior - PENDING
- Timer component state management - PENDING

### Widget Tests

- `CombinedTimer` mode switching functionality - PENDING
- Manual logging dialog form validation - PENDING
- Time display components (actual vs estimated) - PENDING
- Timer integration in task and habit pages - PENDING

### Integration Tests

- Database migration from version 23 to 24 ✅
- End-to-end time tracking workflows - PENDING
- Analytics accuracy with mixed actual/estimated data - PENDING
- Sync protocol compatibility with new data structures - PENDING

## Success Criteria

- **Functionality**: Users can switch between Normal and Pomodoro timers seamlessly
- **Manual Logging**: Users can log time for past dates with hour-bucket accuracy
- **Habit Timing**: Habit time analytics reflect actual tracked time when available
- **Performance**: Timer operations remain responsive under normal usage
- **Compatibility**: No regressions in existing time tracking functionality
- **Adoption**: >60% of active users try the new timer modes within 30 days

## Dependencies

- Existing CQRS infrastructure (`mediatr` package)
- Drift ORM for database operations
- Timer and notification services
- Device platform integration (system tray, keep-awake)
- Sync protocol and data structures

## Migration Strategy

1. **Gradual Rollout**: Feature flag for new timer modes
2. **Data Migration**: Automatic database schema upgrade
3. **User Education**: In-app notifications about new features
4. **Fallback Support**: Maintain estimated time calculations as backup

## References

- [GitHub Issue #60](https://github.com/ahmet-cetinkaya/whph/issues/60): Original feature request
- [Pomodoro Technique](https://francescocirillo.com/pages/pomodoro-technique): Original productivity method
- [Drift Documentation](https://drift.simonbinder.eu/): ORM and database operations
- [Flutter Timer](https://api.flutter.dev/flutter/dart-async/Timer-class.html): Timer implementation patterns
- Existing sync services and CQRS architecture patterns