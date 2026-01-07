import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/presentation/ui/features/habits/components/habits_list.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/main.dart' as app_main;
import 'package:acore/acore.dart' hide Container;
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/error_helper.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

// Mocks
class MockSoundManagerService extends Mock implements ISoundManagerService {}

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

class MockTimeDataService extends Mock implements TimeDataService {}

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
  Color get surface1 => Colors.white;
  @override
  Color get surface2 => Colors.grey;
  @override
  Color get textColor => Colors.black;
  @override
  Color get secondaryTextColor => Colors.grey;
  @override
  UiDensity get currentUiDensity => UiDensity.normal;
}

class FakeContainer extends Fake implements IContainer {
  final Map<Type, dynamic> _registrations = {};

  void register<T>(dynamic instance) {
    _registrations[T] = instance;
  }

  @override
  T resolve<T>([String? name]) {
    if (_registrations.containsKey(T)) {
      return _registrations[T] as T;
    }
    throw Exception('Service setup missing for type $T');
  }
}

class FakeMediator extends Fake implements Mediator {
  final List<HabitListItem> habits;
  final List<TaskListItem> tasks;

  FakeMediator({this.habits = const [], this.tasks = const []});

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse extends Object?>(TRequest request) async {
    if (request is GetListHabitsQuery) {
      return GetListHabitsQueryResponse(
        items: habits,
        totalItemCount: habits.length,
        pageIndex: 0,
        pageSize: 100,
      ) as TResponse;
    } else if (request is GetListHabitRecordsQuery) {
      return GetListHabitRecordsQueryResponse(
        items: [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 10,
      ) as TResponse;
    } else if (request is GetListTasksQuery) {
      return GetListTasksQueryResponse(
        items: tasks,
        totalItemCount: tasks.length,
        pageIndex: 0,
        pageSize: 100,
      ) as TResponse;
    }
    throw UnimplementedError('Unhandled request type: ${request.runtimeType}');
  }
}

/// Generates demo habits for testing
List<HabitListItem> generateDemoHabits(int count) {
  return List.generate(
      count,
      (i) => HabitListItem(
            id: 'habit_$i',
            name: 'Demo Habit $i',
            hasGoal: i % 3 == 0,
            targetFrequency: 1,
            periodDays: 1,
            order: i.toDouble(),
            groupName: i % 5 == 0 ? 'Group ${i ~/ 5}' : null,
          ));
}

/// Generates demo tasks for testing
List<TaskListItem> generateDemoTasks(int count) {
  return List.generate(
      count,
      (i) => TaskListItem(
            id: 'task_$i',
            title: 'Demo Task $i',
            priority: null,
            isCompleted: false,
            order: i.toDouble(),
            groupName: i % 5 == 0 ? 'Group ${i ~/ 5}' : null,
            createdDate: DateTime.now(),
          ));
}

void main() {
  group('TodayPage Performance Tests', () {
    late FakeContainer fakeContainer;
    late FakeMediator fakeMediator;
    late MockHabitsService mockHabitsService;
    late MockTasksService mockTasksService;
    late MockTranslationService mockTranslationService;

    setUpAll(() {
      fakeContainer = FakeContainer();
      app_main.container = fakeContainer;
    });

    setUp(() {
      final habits = generateDemoHabits(20);
      final tasks = generateDemoTasks(20);

      fakeMediator = FakeMediator(habits: habits, tasks: tasks);
      mockHabitsService = MockHabitsService();
      mockTasksService = MockTasksService();
      mockTranslationService = MockTranslationService();

      fakeContainer.register<Mediator>(fakeMediator);
      fakeContainer.register<HabitsService>(mockHabitsService);
      fakeContainer.register<TasksService>(mockTasksService);
      fakeContainer.register<ITranslationService>(mockTranslationService);
      fakeContainer.register<ISoundManagerService>(MockSoundManagerService());
      fakeContainer.register<TimeDataService>(MockTimeDataService());
      fakeContainer.register<IThemeService>(FakeThemeService());
      fakeContainer.register<ITaskRecurrenceService>(MockTaskRecurrenceService());
      fakeContainer.register<ILogger>(MockLogger());

      ErrorHelper.initialize(mockTranslationService);
    });

    testWidgets('HabitsList build performance with 20 items (Sliver mode)', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: CustomScrollView(
              slivers: [
                HabitsList(
                  useSliver: true,
                  style: HabitListStyle.list,
                  onClickHabit: (_) {},
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle(const Duration(seconds: 5));

      stopwatch.stop();

      // Log performance metric
      debugPrint('HabitsList (20 items, Sliver): ${stopwatch.elapsedMilliseconds}ms');

      // Baseline assertion - adjust after optimization
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'HabitsList build should complete within 5 seconds');
    });

    testWidgets('TaskList build performance with 20 items (Sliver mode)', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: CustomScrollView(
              slivers: [
                TaskList(
                  useSliver: true,
                  onClickTask: (_) {},
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle(const Duration(seconds: 5));

      stopwatch.stop();

      // Log performance metric
      debugPrint('TaskList (20 items, Sliver): ${stopwatch.elapsedMilliseconds}ms');

      // Baseline assertion - adjust after optimization
      expect(stopwatch.elapsedMilliseconds, lessThan(5000), reason: 'TaskList build should complete within 5 seconds');
    });

    testWidgets('Combined HabitsList + TaskList performance (TodayPage simulation)', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: CustomScrollView(
              slivers: [
                HabitsList(
                  useSliver: true,
                  style: HabitListStyle.list,
                  onClickHabit: (_) {},
                ),
                TaskList(
                  useSliver: true,
                  onClickTask: (_) {},
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle(const Duration(seconds: 10));

      stopwatch.stop();

      // Log performance metric
      debugPrint('Combined Lists (TodayPage simulation): ${stopwatch.elapsedMilliseconds}ms');

      // Baseline assertion - adjust after optimization
      expect(stopwatch.elapsedMilliseconds, lessThan(10000), reason: 'Combined lists should build within 10 seconds');
    });

    testWidgets('Rebuild performance on keyboard simulation', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: CustomScrollView(
              slivers: [
                HabitsList(
                  useSliver: true,
                  style: HabitListStyle.list,
                  onClickHabit: (_) {},
                ),
                TaskList(
                  useSliver: true,
                  onClickTask: (_) {},
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Simulate multiple rebuilds (as if keyboard keeps toggling)
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 5; i++) {
        await tester.pump();
      }

      stopwatch.stop();

      // Log performance metric
      debugPrint('5 rapid rebuilds: ${stopwatch.elapsedMilliseconds}ms');

      // Should be very fast since data hasn't changed
      expect(stopwatch.elapsedMilliseconds, lessThan(500), reason: 'Rapid rebuilds without data change should be fast');
    });
  });
}
