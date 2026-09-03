import 'dart:convert';

import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/commands/normalize_habit_orders_command.dart';
import 'package:whph/core/application/features/notes/commands/normalize_note_orders_command.dart';
import 'package:whph/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/core/application/features/tasks/commands/normalize_task_orders_command.dart';
import 'package:whph/core/application/shared/services/compression_service.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;

import 'import_data_command_test.mocks.dart';

void main() {
  late MockIAppUsageRepository appUsageRepository;
  late MockIAppUsageTagRepository appUsageTagRepository;
  late MockIAppUsageTimeRecordRepository appUsageTimeRecordRepository;
  late MockIAppUsageTagRuleRepository appUsageTagRuleRepository;
  late MockIHabitRepository habitRepository;
  late MockIHabitRecordRepository habitRecordRepository;
  late MockIHabitTagsRepository habitTagRepository;
  late MockITagRepository tagRepository;
  late MockITagTagRepository tagTagRepository;
  late MockITaskRepository taskRepository;
  late MockITaskTagRepository taskTagRepository;
  late MockITaskTimeRecordRepository taskTimeRecordRepository;
  late MockISettingRepository settingRepository;
  late MockISyncDeviceRepository syncDeviceRepository;
  late MockIAppUsageIgnoreRuleRepository appUsageIgnoreRuleRepository;
  late MockINoteRepository noteRepository;
  late MockINoteTagRepository noteTagRepository;
  late MockIImportDataMigrationService migrationService;
  late CompressionService compressionService;
  late List<Habit> storedHabits;
  late ExportDataCommandHandler exportHandler;
  late ImportDataCommandHandler importHandler;

  setUp(() {
    initializeJsonMapper();
    AppDatabase.setInstanceForTesting(AppDatabase.forTesting());
    appUsageRepository = MockIAppUsageRepository();
    appUsageTagRepository = MockIAppUsageTagRepository();
    appUsageTimeRecordRepository = MockIAppUsageTimeRecordRepository();
    appUsageTagRuleRepository = MockIAppUsageTagRuleRepository();
    habitRepository = MockIHabitRepository();
    habitRecordRepository = MockIHabitRecordRepository();
    habitTagRepository = MockIHabitTagsRepository();
    tagRepository = MockITagRepository();
    tagTagRepository = MockITagTagRepository();
    taskRepository = MockITaskRepository();
    taskTagRepository = MockITaskTagRepository();
    taskTimeRecordRepository = MockITaskTimeRecordRepository();
    settingRepository = MockISettingRepository();
    syncDeviceRepository = MockISyncDeviceRepository();
    appUsageIgnoreRuleRepository = MockIAppUsageIgnoreRuleRepository();
    noteRepository = MockINoteRepository();
    noteTagRepository = MockINoteTagRepository();
    migrationService = MockIImportDataMigrationService();
    compressionService = CompressionService();
    storedHabits = [];

    final repositories = [
      appUsageRepository,
      appUsageTagRepository,
      appUsageTimeRecordRepository,
      appUsageTagRuleRepository,
      habitRepository,
      habitRecordRepository,
      habitTagRepository,
      tagRepository,
      tagTagRepository,
      taskRepository,
      taskTagRepository,
      taskTimeRecordRepository,
      settingRepository,
      syncDeviceRepository,
      appUsageIgnoreRuleRepository,
      noteRepository,
      noteTagRepository,
    ];
    for (final dynamic repository in repositories) {
      when(repository.getAll(
        customWhereFilter: anyNamed('customWhereFilter'),
        customOrder: anyNamed('customOrder'),
      )).thenAnswer((_) => Future.value(<Never>[]));
      when(repository.truncate()).thenAnswer((_) async {});
    }
    when(habitRepository.getAll(
      customWhereFilter: anyNamed('customWhereFilter'),
      customOrder: anyNamed('customOrder'),
    )).thenAnswer((_) async => storedHabits);
    when(habitRepository.add(any)).thenAnswer((invocation) async {
      storedHabits.add(invocation.positionalArguments.single as Habit);
    });
    when(habitRepository.updateMultiple(any)).thenAnswer((_) async {});
    when(taskRepository.updateMultiple(any)).thenAnswer((_) async {});
    when(noteRepository.updateMultiple(any)).thenAnswer((_) async {});
    when(migrationService.isMigrationNeeded(any)).thenReturn(false);

    final mediator = Mediator(Pipeline())
      ..registerHandler<NormalizeHabitOrdersCommand, NormalizeHabitOrdersResponse, NormalizeHabitOrdersCommandHandler>(
        () => NormalizeHabitOrdersCommandHandler(habitRepository),
      )
      ..registerHandler<NormalizeTaskOrdersCommand, NormalizeTaskOrdersResponse, NormalizeTaskOrdersCommandHandler>(
        () => NormalizeTaskOrdersCommandHandler(taskRepository),
      )
      ..registerHandler<NormalizeNoteOrdersCommand, NormalizeNoteOrdersResponse, NormalizeNoteOrdersCommandHandler>(
        () => NormalizeNoteOrdersCommandHandler(noteRepository),
      );

    exportHandler = ExportDataCommandHandler(
      appUsageRepository: appUsageRepository,
      appUsageTagRepository: appUsageTagRepository,
      appUsageTimeRecordRepository: appUsageTimeRecordRepository,
      appUsageTagRuleRepository: appUsageTagRuleRepository,
      habitRepository: habitRepository,
      habitRecordRepository: habitRecordRepository,
      habitTagRepository: habitTagRepository,
      tagRepository: tagRepository,
      tagTagRepository: tagTagRepository,
      taskRepository: taskRepository,
      taskTagRepository: taskTagRepository,
      taskTimeRecordRepository: taskTimeRecordRepository,
      settingRepository: settingRepository,
      syncDeviceRepository: syncDeviceRepository,
      appUsageIgnoreRuleRepository: appUsageIgnoreRuleRepository,
      noteRepository: noteRepository,
      noteTagRepository: noteTagRepository,
      compressionService: compressionService,
    );
    importHandler = ImportDataCommandHandler(
      appUsageRepository: appUsageRepository,
      appUsageTagRepository: appUsageTagRepository,
      appUsageTimeRecordRepository: appUsageTimeRecordRepository,
      appUsageTagRuleRepository: appUsageTagRuleRepository,
      habitRepository: habitRepository,
      habitRecordRepository: habitRecordRepository,
      habitTagRepository: habitTagRepository,
      tagRepository: tagRepository,
      tagTagRepository: tagTagRepository,
      taskRepository: taskRepository,
      taskTagRepository: taskTagRepository,
      taskTimeRecordRepository: taskTimeRecordRepository,
      settingRepository: settingRepository,
      syncDeviceRepository: syncDeviceRepository,
      appUsageIgnoreRuleRepository: appUsageIgnoreRuleRepository,
      noteRepository: noteRepository,
      noteTagRepository: noteTagRepository,
      migrationService: migrationService,
      compressionService: compressionService,
      mediator: mediator,
    );
  });

  tearDown(() async {
    await AppDatabase.instance().close();
    AppDatabase.resetInstance();
  });

  test('legacy backup without type imports the habit as good', () async {
    final backup = await compressionService.createWhphFile(jsonEncode({
      'appInfo': {'version': AppInfo.version},
      'habits': [_habitJson('legacy')..remove('type')],
    }));

    await importHandler.call(ImportDataCommand(backup, ImportStrategy.replace));

    expect(storedHabits.single.type, HabitType.good);
  });

  test('unknown and non-string backup types import as good', () async {
    final backup = await compressionService.createWhphFile(jsonEncode({
      'appInfo': {'version': AppInfo.version},
      'habits': [
        _habitJson('unknown', type: 'harmful'),
        _habitJson('garbage', type: 99),
      ],
    }));

    await importHandler.call(ImportDataCommand(backup, ImportStrategy.replace));

    expect(storedHabits.map((habit) => habit.type), everyElement(HabitType.good));
  });

  test('backup export and import round-trip preserves both habit types', () async {
    storedHabits.addAll([
      Habit.fromJson(_habitJson('good', type: 'good')),
      Habit.fromJson(_habitJson('bad', type: 'bad')),
    ]);
    final exported = await exportHandler.call(ExportDataCommand(ExportDataFileOptions.backup));
    storedHabits.clear();

    await importHandler.call(ImportDataCommand(exported.fileContent, ImportStrategy.replace));

    expect(
      {for (final habit in storedHabits) habit.id: habit.type},
      {'good': HabitType.good, 'bad': HabitType.bad},
    );
  });

  test('JSON and CSV exports keep deterministic habit headers including type', () async {
    storedHabits.add(Habit.fromJson(_habitJson('bad', type: 'bad')));

    final jsonExport = await exportHandler.call(ExportDataCommand(ExportDataFileOptions.json));
    final csvExport = await exportHandler.call(ExportDataCommand(ExportDataFileOptions.csv));
    final jsonHabit = (jsonDecode(jsonExport.fileContent) as Map<String, dynamic>)['habits'][0] as Map<String, dynamic>;
    final csvHeader =
        (csvExport.fileContent as String).split('\n').skipWhile((line) => line != '# habits').skip(1).first;

    const expectedHeaders = [
      'id',
      'createdDate',
      'modifiedDate',
      'deletedDate',
      'isDeleted',
      'type',
      'name',
      'description',
      'estimatedTime',
      'archivedDate',
      'hasReminder',
      'reminderTime',
      'reminderDays',
      'hasGoal',
      'targetFrequency',
      'periodDays',
      'dailyTarget',
      'order',
      'isArchived',
    ];
    expect(jsonHabit.keys.toList(), expectedHeaders);
    expect(csvHeader.trim().split(','), expectedHeaders);
  });
}

Map<String, dynamic> _habitJson(String id, {Object? type = 'good'}) => {
      'id': id,
      'createdDate': '2026-01-01T00:00:00.000Z',
      'modifiedDate': null,
      'deletedDate': null,
      'type': type,
      'name': id,
      'description': '',
      'estimatedTime': null,
      'archivedDate': null,
      'hasReminder': false,
      'reminderTime': null,
      'reminderDays': '',
      'hasGoal': false,
      'targetFrequency': 1,
      'periodDays': 1,
      'dailyTarget': 1,
      'order': OrderRank.initialRank,
    };
