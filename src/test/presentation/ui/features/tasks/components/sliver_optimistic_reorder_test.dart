import 'package:acore/acore.dart' hide Container;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/commands/update_task_order_command.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_statuses_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' show UiDensity;
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/services/time_data_service.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_view_mode.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
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
  @override
  UiDensity get currentUiDensity => UiDensity.normal;
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

/// Serves tasks whose persisted order the test controls, and records the
/// reorder command the widget issues. Re-queries reflect the recorded
/// reorder, mimicking a real backend round-trip.
class ReorderMediator extends Fake implements Mediator {
  ReorderMediator(this.order);

  List<String> order;
  final List<UpdateTaskOrderCommand> commands = [];

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse extends Object?>(TRequest request) async {
    if (request is GetListTasksQuery) {
      return GetListTasksQueryResponse(
        items: [
          for (final (index, id) in order.indexed)
            TaskListItem(
              id: id,
              title: id,
              priority: null,
              isCompleted: false,
              // Canonical, well-spaced base-62 ranks so the widget does not
              // trigger its "orders need normalization" repair path.
              order: String.fromCharCode('F'.codeUnitAt(0) + index * 5),
            ),
        ],
        totalItemCount: order.length,
        pageIndex: 0,
        pageSize: order.length,
      ) as TResponse;
    }
    if (request is UpdateTaskOrderCommand) {
      final command = request as UpdateTaskOrderCommand;
      commands.add(command);
      // Apply the same placement the real handler would: remove the moved
      // task, then insert it before afterTaskId (or after beforeTaskId).
      final next = List<String>.from(order)..remove(command.taskId);
      int insertAt;
      if (command.afterTaskId != null && next.contains(command.afterTaskId)) {
        insertAt = next.indexOf(command.afterTaskId!);
      } else if (command.beforeTaskId != null && next.contains(command.beforeTaskId)) {
        insertAt = next.indexOf(command.beforeTaskId!) + 1;
      } else {
        insertAt = command.targetIndex.clamp(0, next.length);
      }
      next.insert(insertAt.clamp(0, next.length), command.taskId);
      order = next;
      return UpdateTaskOrderResponse(command.taskId, command.taskId) as TResponse;
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

SortConfig<TaskSortFields> _customSort() => SortConfig<TaskSortFields>(
      orderOptions: const [],
      useCustomOrder: true,
      enableGrouping: false,
    );

void main() {
  late FakeContainer fakeContainer;
  late ReorderMediator mediator;

  void setUpContainer(List<String> order) {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
    mediator = ReorderMediator(order);

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
  }

  Future<void> pumpSliverTaskList(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            TaskList(
              sortConfig: _customSort(),
              viewMode: TaskViewMode.list,
              enableReordering: true,
              useSliver: true,
              onClickTask: (_) {},
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Reads the currently rendered task order from the widget tree.
  List<String> renderedOrder(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where((s) => s.startsWith('task-'))
      .toList();

  testWidgets('optimistic reorder is visible immediately, before the refresh lands', (tester) async {
    setUpContainer(['task-a', 'task-b', 'task-c', 'task-d']);
    await pumpSliverTaskList(tester);

    expect(renderedOrder(tester), ['task-a', 'task-b', 'task-c', 'task-d']);

    final state = tester.state<State<TaskList>>(find.byType(TaskList)) as dynamic;

    // Drag task-a down to sit between task-b and task-c. In pre-removal
    // sliver coordinates that is newIndex 2.
    state.onSliverReorderForTest(0, 2);

    // A single pump applies the optimistic setState but not the
    // post-frame refresh. The new order must already be on screen: if the
    // derived caches were stale the list would still show the old order
    // here and only correct itself after the refresh, which is exactly the
    // flicker users reported.
    await tester.pump();

    expect(
      renderedOrder(tester),
      ['task-b', 'task-a', 'task-c', 'task-d'],
      reason: 'optimistic reorder must be rendered immediately after the drop',
    );
  });

  testWidgets('dropped position survives the post-command refresh', (tester) async {
    setUpContainer(['task-a', 'task-b', 'task-c', 'task-d']);
    await pumpSliverTaskList(tester);

    final state = tester.state<State<TaskList>>(find.byType(TaskList)) as dynamic;
    state.onSliverReorderForTest(0, 2);
    await tester.pumpAndSettle();

    // After the command round-trip and refresh, the item must remain where
    // it was dropped rather than snapping to a different slot.
    expect(mediator.commands, hasLength(1));
    expect(renderedOrder(tester), ['task-b', 'task-a', 'task-c', 'task-d']);
  });
}
