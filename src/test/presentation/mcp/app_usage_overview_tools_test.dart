import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart' hide Task;
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/queries/get_app_usage_statistics_query.dart';
import 'package:whph/core/application/features/app_usages/queries/get_distinct_device_names_query.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_events.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/core/application/features/app_usages/services/app_usage_mcp_actions.dart';
import 'package:whph/core/application/features/app_usages/services/app_usage_filter_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_total_duration_by_task_id_query.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_ignore_rule_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_tag_rule_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_time_record_repository.dart';
import 'package:whph/infrastructure/android/features/app_usage/android_app_usage_service.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_status_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/services/drift_application_transaction_service.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/tools/app_usage_tools.dart';
import 'package:whph/presentation/mcp/tools/overview_tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late DriftAppUsageRepository usageRepository;
  late DriftAppUsageTagRepository usageTagRepository;
  late DriftAppUsageTimeRecordRepository timeRepository;
  late DriftTagRepository tagRepository;
  late _TrackingService trackingService;
  late _UsageEvents events;
  late AppUsageActions actions;

  setUp(() {
    database = AppDatabase.forTesting();
    usageRepository = DriftAppUsageRepository.withDatabase(database);
    usageTagRepository = DriftAppUsageTagRepository.withDatabase(database);
    timeRepository = DriftAppUsageTimeRecordRepository.withDatabase(database);
    tagRepository = DriftTagRepository.withDatabase(database);
    trackingService = _TrackingService();
    events = _UsageEvents();
    actions = AppUsageActions(
      transactionService: DriftApplicationTransactionService(database),
      appUsageRepository: usageRepository,
      appUsageTagRepository: usageTagRepository,
      appUsageTimeRecordRepository: timeRepository,
      tagRuleRepository: DriftAppUsageTagRuleRepository.withDatabase(database),
      ignoreRuleRepository: DriftAppUsageIgnoreRuleRepository.withDatabase(database),
      appUsageService: trackingService,
      appUsageEvents: events,
      tagRepository: tagRepository,
      isTrackingSupported: true,
    );
  });

  tearDown(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidAppUsageService.appUsageStatsChannel, null);
    messenger.setMockMethodCallHandler(AndroidAppUsageService.workManagerChannel, null);
    await database.close();
  });

  test('real SQLite update preserves omitted fields, clears null, tags, and rejects stale revision', () async {
    final usage = AppUsage(
      id: 'usage-1',
      createdDate: DateTime.utc(2026, 9, 8),
      name: 'editor',
      displayName: 'Editor',
      color: '#123456',
      deviceName: 'desktop',
    );
    final tag = Tag(id: 'tag-1', createdDate: DateTime.utc(2026, 9, 8), name: 'Work');
    await usageRepository.add(usage);
    await tagRepository.add(tag);
    final revision = _databaseRevision(usage.createdDate);

    final updated = await actions.update(
      id: usage.id,
      expectedRevision: revision,
      displayName: const OptionalUpdate.value(null),
      tagIds: [tag.id],
    );

    final stored = await usageRepository.getById(usage.id);
    final tags = await usageTagRepository.getListByAppUsageId(usage.id, 0, 50);
    expect(stored?.displayName, isNull);
    expect(stored?.color, '#123456');
    expect(tags.items.single.tagId, tag.id);
    expect(events.updated, [usage.id]);
    expect(updated.revision.isAfter(revision), isTrue);
    expect(usage.displayName, 'Editor');
    expect(usage.modifiedDate, isNull);
    await expectLater(
      actions.update(id: usage.id, expectedRevision: revision, color: const OptionalUpdate.value('#ffffff')),
      throwsA(isA<AppUsageRevisionConflict>()),
    );
    expect(events.updated, [usage.id]);
    expect(usage.displayName, 'Editor');
    expect(usage.modifiedDate, isNull);
  });

  test('real SQLite usage statistics equal seeded source rows across days and hours', () async {
    final usage = AppUsage(id: 'usage-2', createdDate: DateTime.utc(2026, 9, 8), name: 'browser');
    await usageRepository.add(usage);
    await timeRepository.add(AppUsageTimeRecord(
      id: 'record-1',
      createdDate: DateTime.utc(2026, 9, 8),
      appUsageId: usage.id,
      duration: 40,
      usageDate: DateTime.utc(2026, 9, 8, 9),
    ));
    await timeRepository.add(AppUsageTimeRecord(
      id: 'record-2',
      createdDate: DateTime.utc(2026, 9, 9),
      appUsageId: usage.id,
      duration: 20,
      usageDate: DateTime.utc(2026, 9, 9, 10),
    ));

    final result = await GetAppUsageStatisticsQueryHandler(appUsageTimeRecordRepository: timeRepository)(
      GetAppUsageStatisticsQuery(
        appUsageId: usage.id,
        startDate: DateTime.utc(2026, 9, 8),
        endDate: DateTime.utc(2026, 9, 10),
      ),
    );

    expect(result.totalDuration, 60);
    expect(
      result.hourlyUsage.where((entry) => entry.totalDuration > 0).map((entry) => entry.totalDuration),
      containsAll([40, 20]),
    );
  });

  test('invalid rules and tracking consent fail without simulated success', () async {
    expect(() => actions.createIgnoreRule('[', null), throwsFormatException);
    trackingService.hasPermission = false;
    expect(await actions.startTracking(), 'permission_required');
    expect(trackingService.startCalls, 0);
    trackingService.hasPermission = true;
    trackingService.startError = StateError('native adapter failed');
    await expectLater(actions.startTracking(), throwsStateError);
  });

  test('Android native tracking exposes collection, WorkManager, and stop failures', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final androidService = AndroidAppUsageService(
      usageRepository,
      timeRepository,
      DriftAppUsageTagRuleRepository.withDatabase(database),
      usageTagRepository,
      AppUsageFilterService(DriftAppUsageIgnoreRuleRepository.withDatabase(database)),
    );
    var workManagerCalls = 0;
    messenger.setMockMethodCallHandler(AndroidAppUsageService.appUsageStatsChannel, (call) async {
      if (call.method == 'checkUsageStatsPermission') return false;
      return null;
    });
    messenger.setMockMethodCallHandler(AndroidAppUsageService.workManagerChannel, (call) async {
      workManagerCalls++;
      return null;
    });
    final androidActions = AppUsageActions(
      transactionService: DriftApplicationTransactionService(database),
      appUsageRepository: usageRepository,
      appUsageTagRepository: usageTagRepository,
      appUsageTimeRecordRepository: timeRepository,
      tagRuleRepository: DriftAppUsageTagRuleRepository.withDatabase(database),
      ignoreRuleRepository: DriftAppUsageIgnoreRuleRepository.withDatabase(database),
      appUsageService: androidService,
      appUsageEvents: events,
      tagRepository: tagRepository,
      isTrackingSupported: true,
    );
    expect(await androidActions.startTracking(), 'permission_required');
    expect(workManagerCalls, 0);

    var permissionChecks = 0;
    messenger.setMockMethodCallHandler(AndroidAppUsageService.appUsageStatsChannel, (call) async {
      if (call.method == 'checkUsageStatsPermission') {
        permissionChecks++;
        return permissionChecks == 1;
      }
      return <String, dynamic>{};
    });
    expect(await androidActions.startTracking(), 'permission_required');
    expect(permissionChecks, 2);
    expect(workManagerCalls, 0);

    messenger.setMockMethodCallHandler(AndroidAppUsageService.appUsageStatsChannel, (call) async {
      if (call.method == 'checkUsageStatsPermission') return true;
      if (call.method == 'getAccurateForegroundUsage') return <String, dynamic>{};
      if (call.method == 'getTodayForegroundUsage') return <String, dynamic>{};
      return null;
    });
    messenger.setMockMethodCallHandler(AndroidAppUsageService.workManagerChannel, (call) async {
      workManagerCalls++;
      return null;
    });
    await androidService.startTracking();
    expect(workManagerCalls, 1);
    await androidService.stopTracking();

    messenger.setMockMethodCallHandler(AndroidAppUsageService.appUsageStatsChannel, (call) async {
      if (call.method == 'checkUsageStatsPermission') return true;
      if (call.method == 'getAccurateForegroundUsage') return <String, dynamic>{};
      if (call.method == 'getTodayForegroundUsage') throw PlatformException(code: 'collection_failed');
      return null;
    });
    await expectLater(androidService.startTracking(), throwsA(isA<PlatformException>()));

    messenger.setMockMethodCallHandler(AndroidAppUsageService.appUsageStatsChannel, (call) async {
      if (call.method == 'checkUsageStatsPermission') return true;
      return <String, dynamic>{};
    });
    messenger.setMockMethodCallHandler(AndroidAppUsageService.workManagerChannel, (call) async {
      throw PlatformException(code: '${call.method}_failed');
    });
    await expectLater(androidService.startTracking(), throwsA(isA<PlatformException>()));
    await expectLater(androidService.stopTracking(), throwsA(isA<PlatformException>()));
  });

  test('local grant revocation during Android permission await prevents native effects', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final permissionCheckEntered = Completer<void>();
    final releasePermissionCheck = Completer<void>();
    var permissionChecks = 0;
    var isAuthorized = true;
    var guardChecks = 0;
    var scheduled = 0;
    messenger.setMockMethodCallHandler(AndroidAppUsageService.appUsageStatsChannel, (call) async {
      if (call.method == 'checkUsageStatsPermission') {
        permissionChecks++;
        if (permissionChecks == 2) {
          permissionCheckEntered.complete();
          await releasePermissionCheck.future;
        }
        return true;
      }
      return <String, dynamic>{};
    });
    messenger.setMockMethodCallHandler(AndroidAppUsageService.workManagerChannel, (call) async {
      if (call.method == 'startPeriodicAppUsageWork') scheduled++;
      return null;
    });
    final androidService = AndroidAppUsageService(
      usageRepository,
      timeRepository,
      DriftAppUsageTagRuleRepository.withDatabase(database),
      usageTagRepository,
      AppUsageFilterService(DriftAppUsageIgnoreRuleRepository.withDatabase(database)),
    );
    final androidActions = AppUsageActions(
      transactionService: DriftApplicationTransactionService(database),
      appUsageRepository: usageRepository,
      appUsageTagRepository: usageTagRepository,
      appUsageTimeRecordRepository: timeRepository,
      tagRuleRepository: DriftAppUsageTagRuleRepository.withDatabase(database),
      ignoreRuleRepository: DriftAppUsageIgnoreRuleRepository.withDatabase(database),
      appUsageService: androidService,
      appUsageEvents: events,
      tagRepository: tagRepository,
      isTrackingSupported: true,
    );

    final invocation = androidActions.startTracking(authorizeCommit: () async {
      guardChecks++;
      return isAuthorized;
    });
    await permissionCheckEntered.future;
    isAuthorized = false;
    releasePermissionCheck.complete();
    final result = await invocation.then<Object>(
      (state) => state,
      onError: (Object error, StackTrace _) => error,
    );

    expect(
      result,
      isA<MutationAuthorizationException>(),
      reason: 'nativeGrantRace state=$result guardChecks=$guardChecks scheduled=$scheduled',
    );
    expect(scheduled, 0);
    expect(guardChecks, 2);
  });

  test('today aggregate matches task, habit, record, and time rows in real SQLite', () async {
    final day = DateTime(2026, 9, 8);
    final taskRepository = DriftTaskRepository.withDatabase(database);
    final taskStatusRepository = DriftTaskStatusRepository.withDatabase(database);
    final taskTimeRepository = DriftTaskTimeRecordRepository.withDatabase(database);
    final habitRepository = DriftHabitRepository.withDatabase(database);
    final habitTagRepository = DriftHabitTagRepository.withDatabase(database);
    final habitRecordRepository = DriftHabitRecordRepository.withDatabase(database);
    final habitTimeRepository = DriftHabitTimeRecordRepository.withDatabase(database);
    await taskRepository.add(Task(
      id: 'task-today',
      createdDate: day,
      title: 'Today task',
      plannedDate: day.add(const Duration(hours: 9)),
      completedAt: day.add(const Duration(hours: 10)),
    ));
    await taskTimeRepository.add(TaskTimeRecord(
      id: 'task-time',
      taskId: 'task-today',
      duration: 90,
      createdDate: day.add(const Duration(hours: 10)),
    ));
    final habitToday = Habit(
      id: 'habit-today',
      createdDate: day,
      name: 'Today habit',
      description: '',
    );
    await habitRepository.add(habitToday);
    // DriftBaseRepository.add() always stamps createdDate to the real insert
    // time, overwriting the backdated value above. Restore it explicitly so
    // HabitDayStateResolver (used by whph_overview_today) sees the habit as
    // already existing on `day`, matching this test's intent - update() only
    // touches modifiedDate, so this is safe.
    habitToday.createdDate = day;
    await habitRepository.update(habitToday);
    await habitRecordRepository.add(HabitRecord(
      id: 'habit-record',
      createdDate: day,
      habitId: 'habit-today',
      occurredAt: day.add(const Duration(hours: 8)),
    ));
    await habitTimeRepository.add(HabitTimeRecord(
      id: 'habit-time',
      habitId: 'habit-today',
      duration: 30,
      occurredAt: day.add(const Duration(hours: 8)),
      createdDate: day,
    ));

    final mediator = Mediator(Pipeline())
      ..registerHandler<GetListTasksQuery, GetListTasksQueryResponse, GetListTasksQueryHandler>(
        () => GetListTasksQueryHandler(
          taskRepository: taskRepository,
          taskStatusRepository: taskStatusRepository,
        ),
      )
      ..registerHandler<GetListHabitsQuery, GetListHabitsQueryResponse, GetListHabitsQueryHandler>(
        () => GetListHabitsQueryHandler(
          habitRepository: habitRepository,
          habitTagRepository: habitTagRepository,
          habitRecordRepository: habitRecordRepository,
        ),
      )
      ..registerHandler<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse, GetListHabitRecordsQueryHandler>(
        () => GetListHabitRecordsQueryHandler(habitRecordRepository: habitRecordRepository),
      )
      ..registerHandler<GetTotalDurationByTaskIdQuery, GetTotalDurationByTaskIdQueryResponse,
          GetTotalDurationByTaskIdQueryHandler>(
        () => GetTotalDurationByTaskIdQueryHandler(taskTimeRecordRepository: taskTimeRepository),
      )
      ..registerHandler<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse,
          GetTotalDurationByHabitIdQueryHandler>(
        () => GetTotalDurationByHabitIdQueryHandler(habitTimeRecordRepository: habitTimeRepository),
      );
    final today = buildOverviewTools(
      mediator: mediator,
      authorizeSources: (extra, scopes) async => true,
    ).singleWhere((tool) => tool.name == 'whph_overview_today');

    final result = await today.handler(
      McpToolArguments(const {'date': '2026-09-08'}),
      _requestExtra(),
    );
    final body = Map<String, dynamic>.from(result.structuredContent!);
    expect(body['taskSummary'], {'total': 1, 'completed': 1, 'durationSeconds': 90});
    expect(body['habitSummary'], {'total': 1, 'completed': 1, 'durationSeconds': 30});
  });

  test('revocation inside an open transaction rolls back usage update and event', () async {
    final usage = AppUsage(
      id: 'usage-auth',
      createdDate: DateTime.utc(2026, 9, 8),
      name: 'editor',
      displayName: 'before',
    );
    await usageRepository.add(usage);
    final pause = _PausingTransactionService(database);
    final guardedEvents = _UsageEvents();
    final guardedActions = AppUsageActions(
      transactionService: pause,
      appUsageRepository: usageRepository,
      appUsageTagRepository: usageTagRepository,
      appUsageTimeRecordRepository: timeRepository,
      tagRuleRepository: DriftAppUsageTagRuleRepository.withDatabase(database),
      ignoreRuleRepository: DriftAppUsageIgnoreRuleRepository.withDatabase(database),
      appUsageService: trackingService,
      appUsageEvents: guardedEvents,
      tagRepository: tagRepository,
      isTrackingSupported: true,
    );
    var authorized = true;
    var authorizationChecks = 0;
    final update = buildAppUsageTools(
      mediator: Mediator(Pipeline()),
      actions: guardedActions,
      authorizeBeforeCommit: (extra, scopes) async {
        authorizationChecks++;
        return authorized;
      },
    ).singleWhere((tool) => tool.name == 'whph_usage_update');

    final invocation = update.handler(
      McpToolArguments({
        'id': usage.id,
        'expectedRevision': _databaseRevision(usage.createdDate).toIso8601String(),
        'displayName': 'after',
      }),
      _requestExtra(),
    );
    await pause.entered.future;
    authorized = false;
    pause.release.complete();
    final result = await invocation;

    expect(result.isError, isTrue);
    expect((await usageRepository.getById(usage.id))?.displayName, 'before');
    expect(guardedEvents.updated, isEmpty);
    expect(authorizationChecks, 2);
  });

  test('device serialization sorts a copy without mutating mediator response', () async {
    final source = ['zeta', 'alpha'];
    final mediator = Mediator(Pipeline())
      ..registerHandler<GetDistinctDeviceNamesQuery, GetDistinctDeviceNamesQueryResponse, _DeviceNamesHandler>(
          () => _DeviceNamesHandler(source));
    final tool = buildAppUsageTools(
      mediator: mediator,
      actions: actions,
      authorizeBeforeCommit: (extra, scopes) async => true,
    ).singleWhere((definition) => definition.name == 'whph_usage_devices_list');

    final result = await tool.handler(
      McpToolArguments(const {}),
      _requestExtra(),
    );

    expect(result.structuredContent?['deviceNames'], ['alpha', 'zeta']);
    expect(source, ['zeta', 'alpha']);
  });

  test('catalog is complete and malformed range/source grants fail before querying', () async {
    final mediator = Mediator(Pipeline());
    final usageTools = buildAppUsageTools(
      mediator: mediator,
      actions: actions,
      authorizeBeforeCommit: (extra, scopes) async => true,
    );
    expect(usageTools.map((tool) => tool.name).toSet(), {
      'whph_usage_list',
      'whph_usage_read',
      'whph_usage_update',
      'whph_usage_delete',
      'whph_usage_statistics',
      'whph_usage_devices_list',
      'whph_usage_tracking_start',
      'whph_usage_tracking_stop',
      'whph_usage_tag_rules_list',
      'whph_usage_tag_rules_create',
      'whph_usage_tag_rules_delete',
      'whph_usage_ignore_rules_list',
      'whph_usage_ignore_rules_create',
      'whph_usage_ignore_rules_delete',
    });

    var authorizationChecks = 0;
    final overviewTools = buildOverviewTools(
      mediator: mediator,
      authorizeSources: (extra, scopes) {
        authorizationChecks++;
        return false;
      },
    );
    final calendar = overviewTools.singleWhere((tool) => tool.name == 'whph_overview_calendar');
    final tooLarge = await calendar.handler(
      McpToolArguments(const {'from': '2026-01-01', 'to': '2026-12-31'}),
      _requestExtra(),
    );
    expect(tooLarge.isError, isTrue);

    final analysis = overviewTools.singleWhere((tool) => tool.name == 'whph_overview_time_analysis');
    await expectLater(
      analysis.handler(
        McpToolArguments(const {
          'from': '2026-09-01',
          'to': '2026-09-08',
          'categories': ['usage'],
        }),
        _requestExtra(),
      ),
      throwsA(isA<McpToolException>()),
    );
    expect(authorizationChecks, 1);
  });
}

DateTime _databaseRevision(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
      (value.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );

RequestHandlerExtra _requestExtra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'usage-overview-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest: <T extends BaseResultData>(request, resultFactory, options) async => resultFactory(const {}),
    );

final class _TrackingService implements IAppUsageService {
  bool hasPermission = true;
  int startCalls = 0;
  Object? startError;

  @override
  final ValueNotifier<bool> isTrackingActiveWindowWorking = ValueNotifier(true);

  @override
  Future<bool> checkUsageStatsPermission() async => hasPermission;

  @override
  Future<void> requestUsageStatsPermission() async {}

  @override
  Future<void> saveTimeRecord(String appName, int duration, {bool overwrite = false, DateTime? customDateTime}) async {}

  @override
  Future<void> startTracking({ApplicationMutationGuard? authorizeCommit}) async {
    startCalls++;
    if (startError case final error?) throw error;
  }

  @override
  Future<void> stopTracking() async {}
}

final class _UsageEvents implements IAppUsageEvents {
  final List<String> updated = [];

  @override
  void notifyAppUsageCreated(String appUsageId) {}

  @override
  void notifyAppUsageDeleted(String appUsageId) {}

  @override
  void notifyAppUsageIgnoreRuleUpdated(String ruleId) {}

  @override
  void notifyAppUsageRuleCreated(String ruleId) {}

  @override
  void notifyAppUsageRuleDeleted(String ruleId) {}

  @override
  void notifyAppUsageUpdated(String appUsageId) => updated.add(appUsageId);
}

final class _PausingTransactionService implements IApplicationTransactionService {
  _PausingTransactionService(this._database);

  final AppDatabase _database;
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<T> run<T>(Future<T> Function() operation) => _database.transaction(() async {
        entered.complete();
        await release.future;
        return operation();
      });
}

final class _DeviceNamesHandler
    implements IRequestHandler<GetDistinctDeviceNamesQuery, GetDistinctDeviceNamesQueryResponse> {
  const _DeviceNamesHandler(this._deviceNames);

  final List<String> _deviceNames;

  @override
  Future<GetDistinctDeviceNamesQueryResponse> call(GetDistinctDeviceNamesQuery request) async =>
      GetDistinctDeviceNamesQueryResponse(deviceNames: _deviceNames);
}
