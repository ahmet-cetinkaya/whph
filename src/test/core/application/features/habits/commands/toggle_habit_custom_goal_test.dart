import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';

// Fakes
class FakeHabitRepository extends Fake implements IHabitRepository {
  Habit? _habit;
  void setHabit(Habit h) => _habit = h;

  @override
  Future<Habit?> getById(String id, {bool includeDeleted = false}) async => _habit;
}

class FakeHabitRecordRepository extends Fake implements IHabitRecordRepository {
  List<HabitRecord> records = [];
  bool deleteCalled = false;
  HabitRecord? deletedRecord;

  @override
  Future<PaginatedList<HabitRecord>> getListByHabitIdAndRangeDate(
      String habitId, DateTime startDate, DateTime endDate, int pageIndex, int pageSize) async {
    return PaginatedList(items: List.from(records), totalItemCount: records.length, pageIndex: 0, pageSize: 10);
  }

  @override
  Future<void> delete(HabitRecord record) async {
    deleteCalled = true;
    deletedRecord = record;
    records.remove(record);
  }

  @override
  Future<void> add(HabitRecord record) async {
    records.add(record);
  }
}

class FakeHabitTimeRecordRepository extends Fake implements IHabitTimeRecordRepository {
  @override
  Future<List<HabitTimeRecord>> getByHabitIdAndDateRange(String habitId, DateTime start, DateTime end) async {
    return [];
  }

  @override
  Future<void> delete(HabitTimeRecord record) async {}
}

class FakeSettingRepository extends Fake implements ISettingRepository {
  @override
  Future<Setting?> getByKey(String key) async {
    if (key == SettingKeys.habitThreeStateEnabled) {
      return Setting(
          id: 'setting-1',
          createdDate: DateTime.now(),
          key: SettingKeys.habitThreeStateEnabled,
          value: 'true',
          valueType: SettingValueType.bool);
    }
    return null;
  }
}

void main() {
  late ToggleHabitCompletionCommandHandler handler;
  late FakeHabitRepository fakeHabitRepository;
  late FakeHabitRecordRepository fakeHabitRecordRepository;
  late FakeHabitTimeRecordRepository fakeHabitTimeRecordRepository;
  late FakeSettingRepository fakeSettingRepository;

  setUp(() {
    fakeHabitRepository = FakeHabitRepository();
    fakeHabitRecordRepository = FakeHabitRecordRepository();
    fakeHabitTimeRecordRepository = FakeHabitTimeRecordRepository();
    fakeSettingRepository = FakeSettingRepository();

    handler = ToggleHabitCompletionCommandHandler(
      habitRepository: fakeHabitRepository,
      habitRecordRepository: fakeHabitRecordRepository,
      habitTimeRecordRepository: fakeHabitTimeRecordRepository,
      settingsRepository: fakeSettingRepository,
    );
  });

  test('Should transition from NotDone to Unknown (Reset) for custom goal habit', () async {
    final habitId = 'habit-1';
    final date = DateTime(2026, 1, 11);

    // 2. Mock Habit: Custom Goal (Target = 3)
    final habit = Habit(
      id: habitId,
      createdDate: DateTime.now(),
      name: 'Test Habit',
      description: 'Test Description',
      hasGoal: true,
      dailyTarget: 3,
      periodDays: 1,
      targetFrequency: 1,
    );
    fakeHabitRepository.setHabit(habit);

    // 3. Mock Records: Currently 1 "NotDone" record
    final notDoneRecord = HabitRecord(
      id: 'record-1',
      habitId: habitId,
      occurredAt: date.toUtc(), // make sure it matches "same day"
      status: HabitRecordStatus.notDone,
      createdDate: DateTime.now(),
    );
    fakeHabitRecordRepository.records.add(notDoneRecord);

    // 4. Command: Calendar tap behavior (incremental = false)
    final command = ToggleHabitCompletionCommand(
      habitId: habitId,
      date: date,
      useIncrementalBehavior: false,
    );

    await handler.call(command);

    // 5. Verify: It should DELETE the record (Reset to Unknown)
    expect(fakeHabitRecordRepository.deleteCalled, true, reason: 'Delete should be called for NotDone -> Unknown');
    expect(fakeHabitRecordRepository.records.isEmpty, true, reason: 'Record should be removed');
  });
}
