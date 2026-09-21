import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/core/application/features/habits/services/habit_actions.dart';
import 'package:whph/core/application/features/habits/services/i_habit_events.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/services/drift_application_transaction_service.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/tools/habit_tools.dart';

final class _EmptySettings extends Fake implements ISettingRepository {
  @override
  Future<Setting?> getByKey(String key) async => null;
}

final class _Events implements IHabitEvents {
  final created = <String>[];
  final updated = <String>[];
  final deleted = <String>[];
  final recordsAdded = <String>[];
  final recordsRemoved = <String>[];

  @override
  void notifyHabitCreated(String habitId) => created.add(habitId);
  @override
  void notifyHabitDeleted(String habitId) => deleted.add(habitId);
  @override
  void notifyHabitRecordAdded(String habitId) => recordsAdded.add(habitId);
  @override
  void notifyHabitRecordRemoved(String habitId) => recordsRemoved.add(habitId);
  @override
  void notifyHabitUpdated(String habitId) => updated.add(habitId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temporaryDirectory;
  late AppDatabase database;
  late DriftHabitRepository habits;
  late DriftHabitRecordRepository records;
  late DriftHabitTagRepository habitTags;
  late DriftHabitTimeRecordRepository times;
  late DriftTagRepository tags;
  late _Events events;
  late Map<String, McpToolDefinition> tools;
  var canCommit = true;
  var grantedScopes = McpScopes.all;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('whph-habit-tools-');
    database = AppDatabase(
        NativeDatabase(File('${temporaryDirectory.path}/habits.sqlite')));
    AppDatabase.setInstanceForTesting(database);
    habits = DriftHabitRepository.withDatabase(database);
    records = DriftHabitRecordRepository.withDatabase(database);
    habitTags = DriftHabitTagRepository.withDatabase(database);
    times = DriftHabitTimeRecordRepository.withDatabase(database);
    tags = DriftTagRepository.withDatabase(database);
    events = _Events();
    canCommit = true;
    grantedScopes = McpScopes.all;
    final mediator = Mediator(Pipeline())
      ..registerHandler<GetHabitQuery, GetHabitQueryResponse,
              GetHabitQueryHandler>(
          () => GetHabitQueryHandler(
              habitRepository: habits,
              habitRecordRepository: records,
              settingsRepository: _EmptySettings()))
      ..registerHandler<GetListHabitsQuery, GetListHabitsQueryResponse,
              GetListHabitsQueryHandler>(
          () => GetListHabitsQueryHandler(
              habitRepository: habits,
              habitTagRepository: habitTags,
              habitRecordRepository: records))
      ..registerHandler<
              GetListHabitRecordsQuery,
              GetListHabitRecordsQueryResponse,
              GetListHabitRecordsQueryHandler>(
          () => GetListHabitRecordsQueryHandler(habitRecordRepository: records))
      ..registerHandler<
          GetTotalDurationByHabitIdQuery,
          GetTotalDurationByHabitIdQueryResponse,
          GetTotalDurationByHabitIdQueryHandler>(
        () => GetTotalDurationByHabitIdQueryHandler(
            habitTimeRecordRepository: times),
      );
    final actions = HabitActions(
      transactions: DriftApplicationTransactionService(database),
      habitRepository: habits,
      habitRecordRepository: records,
      habitTagsRepository: habitTags,
      habitTimeRecordRepository: times,
      tagRepository: tags,
      habitEvents: events,
    );
    tools = {
      for (final tool in buildHabitTools(
        mediator: mediator,
        actions: actions,
        habitRepository: habits,
        habitRecordRepository: records,
        habitTimeRecordRepository: times,
        authorizeBeforeCommit: (extra, scopes) async =>
            canCommit && grantedScopes.containsAll(scopes),
      ))
        tool.name: tool,
    };
  });

  tearDown(() async {
    await database.close();
    AppDatabase.resetInstance();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
      'good and bad habits support multi-target, undo, archive, time, and statistics',
      () async {
    await tags.add(Tag(
        id: 'health',
        createdDate: DateTime.now().toUtc(),
        name: 'Health',
        type: TagType.label));
    await tags.add(Tag(
        id: 'morning',
        createdDate: DateTime.now().toUtc(),
        name: 'Morning',
        type: TagType.label));
    final good = await _call(tools, 'whph_habits_create', {
      'name': 'Read',
      'description': 'Thirty pages',
      'type': 'good',
      'hasGoal': true,
      'dailyTarget': 3,
      'targetFrequency': 3,
      'periodDays': 1,
      'hasReminder': true,
      'reminderTime': '08:30',
      'reminderDays': [1, 3, 5],
      'tagIds': ['health', 'morning'],
    });
    final bad = await _call(
        tools, 'whph_habits_create', {'name': 'Sugar', 'type': 'bad'});
    final goodId = good['id'] as String;
    final badId = bad['id'] as String;
    final badHabitDate = DateTime.now().toIso8601String().substring(0, 10);
    final filtered = await _call(tools, 'whph_habits_list', {
      'search': 'Read',
      'tagIds': ['health'],
      'forDate': '2026-09-08',
    });
    expect(filtered['totalItemCount'], 1);
    expect(((filtered['items'] as List).single as Map)['tags'], hasLength(2));

    await _call(tools, 'whph_habit_records_set', {
      'habitId': goodId,
      'date': '2026-09-08',
      'status': 'complete',
      'count': 3,
    });
    await _call(tools, 'whph_habit_records_set', {
      'habitId': badId,
      'date': badHabitDate,
      'status': 'not_done',
    });
    final listed = await _call(tools, 'whph_habit_records_list', {
      'habitId': goodId,
      'from': '2026-09-08',
      'to': '2026-09-08',
    });
    final recordItems = listed['items'] as List<dynamic>;
    expect(recordItems, hasLength(3));
    final removedId =
        (recordItems.first as Map<String, dynamic>)['id'] as String;
    final undo = await _call(tools, 'whph_habit_records_undo', {
      'habitId': goodId,
      'date': '2026-09-08',
      'recordId': removedId,
    });
    expect(undo['remainingCount'], 2);
    expect((await records.getById(removedId)), isNull);

    final daily = await _call(tools, 'whph_habit_daily_results', {
      'habitId': badId,
      'from': badHabitDate,
      'to': badHabitDate,
    });
    expect(((daily['days'] as List).single as Map)['status'], 'failed');

    final time = await _call(tools, 'whph_habit_time_records_add', {
      'habitId': goodId,
      'durationSeconds': 90,
      'occurredAt': '2026-09-08T09:00:00+03:00',
    });
    final timeList =
        await _call(tools, 'whph_habit_time_records_list', {'habitId': goodId});
    final timeItem =
        ((timeList['items'] as List).single as Map<String, dynamic>);
    expect(timeItem['id'], time['id']);
    expect(timeList['totalDurationSeconds'], 90);
    await _call(tools, 'whph_habit_time_records_update', {
      'habitId': goodId,
      'date': '2026-09-08',
      'totalDurationSeconds': 120,
      'expectedRevision': timeItem['revision'],
    });

    final read = await _call(tools, 'whph_habits_read', {'id': goodId});
    final archived = await _call(tools, 'whph_habits_archive', {
      'id': goodId,
      'expectedRevision': read['revision'],
      'isArchived': true,
    });
    expect(archived['isArchived'], isTrue);
    final statistics =
        await _call(tools, 'whph_habit_statistics', {'id': goodId});
    expect(statistics, containsPair('topStreaks', isA<List<dynamic>>()));
    expect(events.created, [goodId, badId]);
    expect(events.recordsRemoved, [goodId]);
    final badRead = await _call(tools, 'whph_habits_read', {'id': badId});
    final deleted = await _call(tools, 'whph_habits_delete', {
      'id': badId,
      'expectedRevision': badRead['revision'],
    });
    expect(deleted['id'], badId);
    expect(await habits.getById(badId), isNull);
    stdout.writeln('HABIT_HAPPY ${<String, dynamic>{
      'goodType': read['type'],
      'badDailyState': ((daily['days'] as List).single as Map)['status'],
      'remainingAfterUndo': undo['remainingCount'],
      'archived': archived['isArchived'],
      'timeTotalSeconds': 120,
    }}');
  });

  test('malformed, negative, stale, and revoked writes fail without mutation',
      () async {
    expect(tools.keys, {
      'whph_habits_list',
      'whph_habits_read',
      'whph_habits_create',
      'whph_habits_update',
      'whph_habits_archive',
      'whph_habits_delete',
      'whph_habits_reorder',
      'whph_habit_records_list',
      'whph_habit_records_set',
      'whph_habit_records_undo',
      'whph_habit_daily_results',
      'whph_habit_statistics',
      'whph_habit_time_records_list',
      'whph_habit_time_records_add',
      'whph_habit_time_records_update',
      'whph_habit_time_total',
    });
    final created = await _call(
        tools, 'whph_habits_create', {'name': 'Safe', 'type': 'good'});
    final id = created['id'] as String;
    final malformed = await _raw(tools, 'whph_habit_records_set', {
      'habitId': id,
      'date': '2026-02-30',
      'status': 'unknown',
    });
    final negative = await _raw(tools, 'whph_habit_time_records_add', {
      'habitId': id,
      'durationSeconds': -1,
    });
    final current = await _call(tools, 'whph_habits_update', {
      'id': id,
      'expectedRevision': created['revision'],
      'name': 'Current',
    });
    final stale = await _raw(tools, 'whph_habits_update', {
      'id': id,
      'expectedRevision': created['revision'],
      'name': 'Stale',
    });
    canCommit = false;
    final denied = await _raw(tools, 'whph_habits_archive', {
      'id': id,
      'expectedRevision': current['revision'],
      'isArchived': true,
    });
    final persisted = await habits.getById(id);
    final missingScope = await McpToolRegistry(
      tools: tools.values,
      authorize: (extra, scopes) => false,
      runInvocation: (invocation) => invocation(),
    ).invoke(
        'whph_habit_records_set',
        McpToolArguments({
          'habitId': id,
          'date': '2026-09-08',
          'status': 'complete',
        }),
        _extra());

    expect(_errorCode(malformed), 'validation_error');
    expect(_errorCode(negative), 'validation_error');
    expect(_errorCode(stale), 'conflict');
    expect(_errorCode(denied), 'permission_denied');
    expect(_errorCode(missingScope), 'permission_denied');
    expect(persisted?.name, 'Current');
    expect(persisted?.isArchived, isFalse);
    stdout.writeln('HABIT_FAILURE ${<String, dynamic>{
      'malformed': _errorCode(malformed),
      'negative': _errorCode(negative),
      'stale': _errorCode(stale),
      'revoked': _errorCode(denied),
      'missingScope': _errorCode(missingScope),
      'persistedName': persisted?.name,
    }}');
  });

  test('time totals use occurrence ranges and replace the complete dated total',
      () async {
    final created = await _call(
        tools, 'whph_habits_create', {'name': 'Timed', 'type': 'good'});
    final id = created['id'] as String;
    await _call(tools, 'whph_habit_time_records_add', {
      'habitId': id,
      'durationSeconds': 30,
      'occurredAt': '2026-09-08T09:35:00Z',
    });
    await _call(tools, 'whph_habit_time_records_add', {
      'habitId': id,
      'durationSeconds': 40,
      'occurredAt': '2026-09-08T11:35:00Z',
    });
    final rangedList = await _call(tools, 'whph_habit_time_records_list', {
      'habitId': id,
      'from': '2026-09-08T09:30:00Z',
      'to': '2026-09-08T09:45:00Z',
    });
    final rangedTotal = await _call(tools, 'whph_habit_time_total', {
      'habitId': id,
      'from': '2026-09-08T09:30:00Z',
      'to': '2026-09-08T09:45:00Z',
    });
    final habitList = await _call(tools, 'whph_habits_list', {});
    final timeList =
        await _call(tools, 'whph_habit_time_records_list', {'habitId': id});
    final revision =
        ((timeList['items'] as List).first as Map<String, dynamic>)['revision'];
    await _call(tools, 'whph_habit_time_records_update', {
      'habitId': id,
      'date': '2026-09-08',
      'totalDurationSeconds': 120,
      'expectedRevision': revision,
    });
    final replaced =
        await _call(tools, 'whph_habit_time_total', {'habitId': id});

    expect(rangedList['totalDurationSeconds'], 30);
    expect(rangedTotal['totalDurationSeconds'], 30);
    expect(
        ((habitList['items'] as List).single
            as Map<String, dynamic>)['totalDurationSeconds'],
        70);
    expect(replaced['totalDurationSeconds'], 120);
  });

  test('name-only update preserves disabled reminder weekday preferences',
      () async {
    final created = await _call(tools, 'whph_habits_create', {
      'name': 'Reminder',
      'type': 'good',
      'hasReminder': true,
      'reminderTime': '08:30',
      'reminderDays': [1, 3],
    });
    final id = created['id'] as String;
    final disabled = await _call(tools, 'whph_habits_update', {
      'id': id,
      'expectedRevision': created['revision'],
      'hasReminder': false,
    });
    await _call(tools, 'whph_habits_update', {
      'id': id,
      'expectedRevision': disabled['revision'],
      'name': 'Renamed',
    });

    expect(await habits.getReminderDaysById(id), '1,3');
  });

  test('record changes preserve manual time and guard derived timer writes',
      () async {
    final manual = await _call(tools, 'whph_habits_create', {
      'name': 'Manual time',
      'type': 'good',
    });
    final manualId = manual['id'] as String;
    await _call(tools, 'whph_habit_time_records_add', {
      'habitId': manualId,
      'durationSeconds': 90,
      'occurredAt': '2026-09-08T12:00:00Z',
    });
    grantedScopes = {McpScopes.habitsWrite};
    final registry = McpToolRegistry(
      tools: tools.values,
      authorize: (extra, scopes) async => grantedScopes.containsAll(scopes),
      runInvocation: (invocation) => invocation(),
    );
    final skipped = await registry.invoke(
      'whph_habit_records_set',
      McpToolArguments({
        'habitId': manualId,
        'date': '2026-09-08',
        'status': 'skipped',
      }),
      _extra(),
    );
    grantedScopes = McpScopes.all;
    final estimated = await _call(tools, 'whph_habits_create', {
      'name': 'Estimated time',
      'type': 'good',
      'estimatedMinutes': 10,
    });
    grantedScopes = {McpScopes.habitsWrite};
    final denied = await registry.invoke(
      'whph_habit_records_set',
      McpToolArguments({
        'habitId': estimated['id'],
        'date': '2026-09-08',
        'status': 'complete',
      }),
      _extra(),
    );
    final eventsAfterDenied = events.recordsAdded.length;
    grantedScopes = McpScopes.all;
    await _call(tools, 'whph_habit_records_set', {
      'habitId': estimated['id'],
      'date': '2026-09-08',
      'status': 'complete',
    });
    await _call(tools, 'whph_habit_time_records_add', {
      'habitId': estimated['id'],
      'durationSeconds': 90,
      'occurredAt': '2026-09-08T00:00:00Z',
    });
    grantedScopes = {McpScopes.habitsWrite, McpScopes.timersWrite};
    final clearedDerived = await registry.invoke(
      'whph_habit_records_set',
      McpToolArguments({
        'habitId': estimated['id'],
        'date': '2026-09-08',
        'status': 'skipped',
      }),
      _extra(),
    );

    expect(skipped.isError, isFalse);
    expect(await times.getTotalDurationByHabitId(manualId), 90);
    expect(_errorCode(denied), 'permission_denied');
    expect(eventsAfterDenied, 1);
    expect(await records.getByHabitId(estimated['id'] as String), isEmpty);
    expect(clearedDerived.isError, isFalse);
    expect(
        await times.getTotalDurationByHabitId(estimated['id'] as String), 90);
  });

  test('record count replacement clears every existing dated record', () async {
    final created = await _call(
        tools, 'whph_habits_create', {'name': 'Counted', 'type': 'good'});
    final id = created['id'] as String;
    await _call(tools, 'whph_habit_records_set', {
      'habitId': id,
      'date': '2026-09-08',
      'status': 'complete',
      'count': 1001,
    });
    final replacement = await _call(tools, 'whph_habit_records_set', {
      'habitId': id,
      'date': '2026-09-08',
      'status': 'complete',
      'count': 1,
    });

    expect(replacement['count'], 1);
    expect(await records.getByHabitId(id), hasLength(1));
  });
}

Future<Map<String, dynamic>> _call(Map<String, McpToolDefinition> tools,
    String name, Map<String, dynamic> arguments) async {
  tools[name]!.inputSchema.validate(arguments);
  final result = await _raw(tools, name, arguments);
  expect(result.isError, isFalse, reason: result.toJson().toString());
  tools[name]!.outputSchema.validate(result.structuredContent);
  return Map<String, dynamic>.from(result.structuredContent!);
}

Future<CallToolResult> _raw(Map<String, McpToolDefinition> tools, String name,
        Map<String, dynamic> arguments) =>
    Future<CallToolResult>.value(
        tools[name]!.handler(McpToolArguments(arguments), _extra()));

String? _errorCode(CallToolResult result) =>
    (result.structuredContent?['error'] as Map<String, dynamic>?)?['code']
        as String?;

RequestHandlerExtra _extra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'habit-tools-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest:
          <T extends BaseResultData>(request, resultFactory, options) async =>
              resultFactory(const {}),
    );
