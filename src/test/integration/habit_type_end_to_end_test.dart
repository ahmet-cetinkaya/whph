import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

class EmptySettingRepository extends Fake implements ISettingRepository {
  @override
  Future<Setting?> getByKey(String key) async => null;
}

class EmptyHabitTimeRecordRepository extends Fake implements IHabitTimeRecordRepository {}

void main() {
  late Directory tempDirectory;
  late File databaseFile;
  late AppDatabase database;
  late DriftHabitRepository habitRepository;
  late DriftHabitRecordRepository recordRepository;
  late DriftHabitTagRepository tagRepository;
  final settingRepository = EmptySettingRepository();
  late DateTime targetDate;

  Future<void> openDatabase() async {
    AppDatabase.isTestMode = true;
    database = AppDatabase(NativeDatabase(databaseFile));
    habitRepository = DriftHabitRepository.withDatabase(database);
    recordRepository = DriftHabitRecordRepository.withDatabase(database);
    tagRepository = DriftHabitTagRepository.withDatabase(database);
  }

  ToggleHabitCompletionCommandHandler toggleHandler() => ToggleHabitCompletionCommandHandler(
        habitRepository: habitRepository,
        habitRecordRepository: recordRepository,
        settingsRepository: settingRepository,
        operationsService: HabitRecordOperationsService(
          habitRecordRepository: recordRepository,
          habitTimeRecordRepository: EmptyHabitTimeRecordRepository(),
        ),
      );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('whph-habit-type-e2e-');
    databaseFile = File('${tempDirectory.path}/habit-types.sqlite');
    targetDate = DateTime.now().toUtc();
    await openDatabase();
  });

  tearDown(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  test('bad habit survives create, outcomes, conversion, filters, statistics, and restart', () async {
    final saveHandler = SaveHabitCommandHandler(habitRepository: habitRepository);

    final created = await saveHandler.call(SaveHabitCommand(
      name: 'Avoid sugar',
      description: '',
      type: HabitType.bad,
    ));
    var details = await GetHabitQueryHandler(
      habitRepository: habitRepository,
      habitRecordRepository: recordRepository,
      settingsRepository: settingRepository,
    ).call(GetHabitQuery(id: created.id));

    expect(details.type, HabitType.bad);
    expect(details.statistics.totalRecords, 0);

    final successfulFilter = await GetListHabitsQueryHandler(
      habitRepository: habitRepository,
      habitTagRepository: tagRepository,
      habitRecordRepository: recordRepository,
    ).call(GetListHabitsQuery(
      pageIndex: 0,
      pageSize: 20,
      excludeCompletedForDate: targetDate,
    ));
    expect(successfulFilter.items.map((habit) => habit.id), isNot(contains(created.id)));

    await toggleHandler().call(ToggleHabitCompletionCommand(habitId: created.id, date: targetDate));
    var records = await recordRepository.getByHabitId(created.id);
    expect(records.map((record) => record.status), [HabitRecordStatus.notDone]);

    final failedFilter = await GetListHabitsQueryHandler(
      habitRepository: habitRepository,
      habitTagRepository: tagRepository,
      habitRecordRepository: recordRepository,
    ).call(GetListHabitsQuery(
      pageIndex: 0,
      pageSize: 20,
      excludeCompletedForDate: targetDate,
    ));
    expect(failedFilter.items.map((habit) => habit.id), contains(created.id));

    await toggleHandler().call(ToggleHabitCompletionCommand(habitId: created.id, date: targetDate));
    records = await recordRepository.getByHabitId(created.id);
    expect(records, isEmpty);

    await recordRepository.add(HabitRecord(
      id: 'history',
      createdDate: DateTime.utc(2026, 1, 1),
      habitId: created.id,
      occurredAt: DateTime.utc(2026, 1, 1, 12),
    ));
    await saveHandler.call(SaveHabitCommand(
      id: created.id,
      name: 'Avoid sugar',
      description: '',
      type: HabitType.good,
    ));
    await saveHandler.call(SaveHabitCommand(
      id: created.id,
      name: 'Avoid sugar',
      description: '',
      type: HabitType.bad,
    ));

    await database.close();
    await openDatabase();
    details = await GetHabitQueryHandler(
      habitRepository: habitRepository,
      habitRecordRepository: recordRepository,
      settingsRepository: settingRepository,
    ).call(GetHabitQuery(id: created.id));
    records = await recordRepository.getByHabitId(created.id);

    expect(details.type, HabitType.bad);
    expect(records.map((record) => record.status), [HabitRecordStatus.complete]);
    expect(details.statistics.totalRecords, 0);
  });
}
