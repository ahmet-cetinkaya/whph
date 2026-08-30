import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/habits/components/habits_list.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_view_mode.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';

class MockSoundManagerService extends Mock implements ISoundManagerService {}

class MockTimeDataService extends Mock implements TimeDataService {}

class MockHabitsService extends Mock implements HabitsService {
  @override
  final ValueNotifier<String?> onHabitCreated = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitUpdated = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitDeleted = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitRecordAdded = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onHabitRecordRemoved = ValueNotifier(null);
}

class MockTasksService extends Mock implements TasksService {
  @override
  final ValueNotifier<String?> onTaskCreated = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onTaskUpdated = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onTaskDeleted = ValueNotifier(null);
  @override
  final ValueNotifier<String?> onTaskCompleted = ValueNotifier(null);
}

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) => key;
}

class MockTaskRecurrenceService extends Mock implements ITaskRecurrenceService {
  @override
  bool isRecurring(Task task) => false;
  @override
  bool canCreateNextInstance(Task task) => false;
}

class MockLogger extends Mock implements ILogger {
  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

class FakeThemeService extends Fake implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;
  @override
  Color get surface0 => Colors.white;
  @override
  Color get surface1 => Colors.white;
  @override
  Color get surface2 => Colors.grey;
  @override
  Color get surface3 => Colors.grey;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  Color get darkTextColor => Colors.black;
}

class FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _registrations = {};

  void register<T>(dynamic instance) => _registrations[T] = instance;

  @override
  T resolve<T>([String? name]) {
    if (_registrations.containsKey(T)) return _registrations[T] as T;
    throw Exception('Service setup missing for type $T');
  }
}

/// Records the queries the list widgets actually construct, so grouping
/// grouping coexistence can be asserted at the query-construction site rather
/// than merely on the enabled state of a button.
class RecordingMediator extends Fake implements Mediator {
  final List<GetListTasksQuery> taskQueries = [];
  final List<GetListHabitsQuery> habitQueries = [];

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse extends Object?>(TRequest request) async {
    if (request is GetListTasksQuery) {
      taskQueries.add(request as GetListTasksQuery);
      return GetListTasksQueryResponse(
        items: <TaskListItem>[],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 10,
      ) as TResponse;
    }
    if (request is GetListHabitsQuery) {
      habitQueries.add(request as GetListHabitsQuery);
      return GetListHabitsQueryResponse(
        items: const [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 10,
      ) as TResponse;
    }
    if (request is GetListHabitRecordsQuery) {
      return GetListHabitRecordsQueryResponse(
        items: const [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 10,
      ) as TResponse;
    }
    if (request is GetListTaskStatusesQuery) {
      return GetListTaskStatusesQueryResponse(
        items: const [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 100,
      ) as TResponse;
    }
    throw UnimplementedError('Unhandled request: ${request.runtimeType}');
  }
}

/// A config whose `groupOption` is always present, so `enableGrouping` is the
/// only thing distinguishing active grouping from a stale saved group field.
SortConfig<TaskSortFields> _taskConfig({required bool useCustomOrder, bool enableGrouping = true}) =>
    SortConfig<TaskSortFields>(
      orderOptions: const [
        SortOptionWithTranslationKey(
          field: TaskSortFields.status,
          direction: SortDirection.asc,
          translationKey: 'tasks.status',
        ),
      ],
      useCustomOrder: useCustomOrder,
      enableGrouping: enableGrouping,
      groupOption: const SortOptionWithTranslationKey(
        field: TaskSortFields.status,
        direction: SortDirection.asc,
        translationKey: 'tasks.status',
      ),
    );

SortConfig<HabitSortFields> _habitConfig({required bool useCustomOrder, bool enableGrouping = true}) =>
    SortConfig<HabitSortFields>(
      orderOptions: const [
        SortOptionWithTranslationKey(
          field: HabitSortFields.tag,
          direction: SortDirection.asc,
          translationKey: 'shared.tags',
        ),
      ],
      useCustomOrder: useCustomOrder,
      enableGrouping: enableGrouping,
      groupOption: const SortOptionWithTranslationKey(
        field: HabitSortFields.tag,
        direction: SortDirection.asc,
        translationKey: 'shared.tags',
      ),
    );

void main() {
  late FakeContainer fakeContainer;
  late RecordingMediator mediator;

  setUp(() {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
    mediator = RecordingMediator();

    final translationService = MockTranslationService();
    fakeContainer.register<Mediator>(mediator);
    fakeContainer.register<ITranslationService>(translationService);
    fakeContainer.register<HabitsService>(MockHabitsService());
    fakeContainer.register<TasksService>(MockTasksService());
    fakeContainer.register<ISoundManagerService>(MockSoundManagerService());
    fakeContainer.register<TimeDataService>(MockTimeDataService());
    fakeContainer.register<IThemeService>(FakeThemeService());
    fakeContainer.register<ITaskRecurrenceService>(MockTaskRecurrenceService());
    fakeContainer.register<ILogger>(MockLogger());

    ErrorHelper.initialize(translationService);
  });

  Future<void> pumpTaskList(
    WidgetTester tester, {
    required SortConfig<TaskSortFields> sortConfig,
    required TaskViewMode viewMode,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: TaskList(
            sortConfig: sortConfig,
            viewMode: viewMode,
            enableReordering: sortConfig.useCustomOrder,
            useParentScroll: false,
            onClickTask: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('TaskList query grouping coexistence', () {
    testWidgets('list mode with custom sort keeps configured grouping', (tester) async {
      await pumpTaskList(tester, sortConfig: _taskConfig(useCustomOrder: true), viewMode: TaskViewMode.list);

      expect(mediator.taskQueries, isNotEmpty);
      final query = mediator.taskQueries.last;
      expect(query.sortByCustomSort, isTrue);
      expect(query.enableGrouping, isTrue);
      expect(query.groupBy?.field, TaskSortFields.status);
    });

    testWidgets('board mode with custom sort keeps grouping active', (tester) async {
      await pumpTaskList(tester, sortConfig: _taskConfig(useCustomOrder: true), viewMode: TaskViewMode.board);

      expect(mediator.taskQueries, isNotEmpty);
      final query = mediator.taskQueries.last;
      expect(query.sortByCustomSort, isTrue);
      expect(query.enableGrouping, isTrue);
      expect(query.groupBy?.field, TaskSortFields.status);
    });

    testWidgets('list mode without custom sort keeps grouping active', (tester) async {
      await pumpTaskList(tester, sortConfig: _taskConfig(useCustomOrder: false), viewMode: TaskViewMode.list);

      expect(mediator.taskQueries, isNotEmpty);
      final query = mediator.taskQueries.last;
      expect(query.enableGrouping, isTrue);
      expect(query.groupBy?.field, TaskSortFields.status);
    });

    testWidgets('a stale saved groupOption is not sent while grouping is disabled', (tester) async {
      // Disabling grouping leaves groupOption in the persisted settings. If it
      // still reached the query, custom sort would rank items only *within*
      // that dormant group instead of globally.
      await pumpTaskList(
        tester,
        sortConfig: _taskConfig(useCustomOrder: true, enableGrouping: false),
        viewMode: TaskViewMode.list,
      );

      expect(mediator.taskQueries, isNotEmpty);
      final query = mediator.taskQueries.last;
      expect(query.sortByCustomSort, isTrue);
      expect(query.enableGrouping, isFalse);
      expect(query.groupBy, isNull);
    });
  });

  group('HabitsList query grouping coexistence', () {
    Future<void> pumpHabitsList(WidgetTester tester, {required SortConfig<HabitSortFields> sortConfig}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: HabitsList(
              style: HabitListStyle.list,
              sortConfig: sortConfig,
              enableReordering: sortConfig.useCustomOrder,
              useParentScroll: false,
              onClickHabit: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('custom sort keeps configured grouping', (tester) async {
      await pumpHabitsList(tester, sortConfig: _habitConfig(useCustomOrder: true));

      expect(mediator.habitQueries, isNotEmpty);
      final query = mediator.habitQueries.last;
      expect(query.sortByCustomSort, isTrue);
      expect(query.groupBy?.field, HabitSortFields.tag);
    });

    testWidgets('without custom sort grouping is preserved', (tester) async {
      await pumpHabitsList(tester, sortConfig: _habitConfig(useCustomOrder: false));

      expect(mediator.habitQueries, isNotEmpty);
      final query = mediator.habitQueries.last;
      expect(query.sortByCustomSort, isFalse);
      expect(query.groupBy?.field, HabitSortFields.tag);
    });

    testWidgets('a stale saved groupOption is not sent while grouping is disabled', (tester) async {
      await pumpHabitsList(tester, sortConfig: _habitConfig(useCustomOrder: true, enableGrouping: false));

      expect(mediator.habitQueries, isNotEmpty);
      final query = mediator.habitQueries.last;
      expect(query.sortByCustomSort, isTrue);
      expect(query.groupBy, isNull);
    });
  });
}
