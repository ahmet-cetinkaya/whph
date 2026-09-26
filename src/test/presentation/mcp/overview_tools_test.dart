// Regression test for: `whph_overview_today`/`whph_overview_calendar` computed
// a habit's "isCompleted" for a day purely from `HabitRecordStatus.complete`
// record counts. Bad habits never produce a `complete` record (a day
// succeeds by having *no* violation recorded - the reverse of a good habit's
// polarity), so every bad habit was reported as "not completed" every day,
// even on days the user successfully avoided it.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_total_duration_by_task_id_query.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_status_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/tools/overview_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temporaryDirectory;
  late AppDatabase database;
  late DriftHabitRepository habits;
  late DriftHabitRecordRepository records;
  late Map<String, McpToolDefinition> tools;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('whph-overview-tools-');
    database = AppDatabase(NativeDatabase(File('${temporaryDirectory.path}/overview.sqlite')));
    AppDatabase.setInstanceForTesting(database);
    habits = DriftHabitRepository.withDatabase(database);
    records = DriftHabitRecordRepository.withDatabase(database);
    final habitTags = DriftHabitTagRepository.withDatabase(database);

    final mediator = Mediator(Pipeline())
      ..registerHandler<GetListHabitsQuery, GetListHabitsQueryResponse, GetListHabitsQueryHandler>(() =>
          GetListHabitsQueryHandler(
              habitRepository: habits, habitTagRepository: habitTags, habitRecordRepository: records))
      ..registerHandler<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse, GetListHabitRecordsQueryHandler>(
          () => GetListHabitRecordsQueryHandler(habitRecordRepository: records))
      ..registerHandler<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse,
          GetTotalDurationByHabitIdQueryHandler>(
        () => GetTotalDurationByHabitIdQueryHandler(habitTimeRecordRepository: DriftHabitTimeRecordRepository()),
      )
      ..registerHandler<GetListTasksQuery, GetListTasksQueryResponse, GetListTasksQueryHandler>(
        () => GetListTasksQueryHandler(
          taskRepository: DriftTaskRepository(),
          taskStatusRepository: DriftTaskStatusRepository(),
        ),
      )
      ..registerHandler<GetTotalDurationByTaskIdQuery, GetTotalDurationByTaskIdQueryResponse,
          GetTotalDurationByTaskIdQueryHandler>(
        () => GetTotalDurationByTaskIdQueryHandler(taskTimeRecordRepository: DriftTaskTimeRecordRepository()),
      );

    tools = {
      for (final tool in buildOverviewTools(mediator: mediator, authorizeSources: (extra, scopes) async => true))
        tool.name: tool,
    };
  });

  tearDown(() async {
    await database.close();
    AppDatabase.resetInstance();
    await temporaryDirectory.delete(recursive: true);
  });

  test('a bad habit successfully avoided today is reported as completed, not stuck as failed', () async {
    final saveHandler = SaveHabitCommandHandler(habitRepository: habits);
    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final good = await saveHandler.call(SaveHabitCommand(name: 'Read', description: '', type: HabitType.good));
    final avoidedBad = await saveHandler.call(SaveHabitCommand(name: 'Sugar', description: '', type: HabitType.bad));
    final performedBad = await saveHandler.call(SaveHabitCommand(name: 'Snooze', description: '', type: HabitType.bad));

    // Good habit: completed today.
    await records.add(HabitRecord(
      id: 'good-record',
      createdDate: DateTime.now().toUtc(),
      habitId: good.id,
      occurredAt: DateTime(today.year, today.month, today.day, 12),
      status: HabitRecordStatus.complete,
    ));
    // avoidedBad: no record today at all -> successfully avoided.
    // performedBad: a notDone record today -> the bad habit was performed (a violation).
    await records.add(HabitRecord(
      id: 'performed-bad-record',
      createdDate: DateTime.now().toUtc(),
      habitId: performedBad.id,
      occurredAt: DateTime(today.year, today.month, today.day, 12),
      status: HabitRecordStatus.notDone,
    ));

    final result = await tools['whph_overview_today']!.handler(
      McpToolArguments({'date': todayIso}),
      _extra(),
    );
    expect(result.isError, isFalse, reason: result.toJson().toString());
    final body = Map<String, dynamic>.from(result.structuredContent!);
    final items = (body['habits'] as List).cast<Map<String, dynamic>>();

    Map<String, dynamic> itemFor(String id) => items.singleWhere((item) => item['id'] == id);

    expect(itemFor(good.id)['isCompleted'], isTrue, reason: 'A completed good habit must be reported as completed');
    expect(itemFor(avoidedBad.id)['isCompleted'], isTrue,
        reason: 'A bad habit with no violation today was successfully avoided and must be reported as completed - '
            'this is the exact case that was always reported as false before the fix');
    expect(itemFor(performedBad.id)['isCompleted'], isFalse,
        reason: 'A bad habit performed (violated) today must be reported as not completed');

    final summary = body['habitSummary'] as Map<String, dynamic>;
    expect(summary['total'], 3);
    expect(summary['completed'], 2, reason: 'good + avoidedBad succeeded today; performedBad did not');
  });
}

RequestHandlerExtra _extra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'overview-tools-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest: <T extends BaseResultData>(request, resultFactory, options) async => resultFactory(const {}),
    );
