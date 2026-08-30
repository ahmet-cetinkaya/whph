import 'package:acore/acore.dart' hide Container;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
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
import 'package:whph/presentation/ui/features/tasks/components/task_card.dart';
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

/// Serves tasks in a caller-controlled order and records reorder commands,
/// applying each one the way the real handler would so a follow-up query
/// reflects the persisted result.
class TaskMediator extends Fake implements Mediator {
  TaskMediator(this.order);

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
      final next = List<String>.from(order)..remove(command.taskId);
      int insertAt;
      if (command.afterTaskId != null && next.contains(command.afterTaskId)) {
        insertAt = next.indexOf(command.afterTaskId!);
      } else if (command.beforeTaskId != null && next.contains(command.beforeTaskId)) {
        insertAt = next.indexOf(command.beforeTaskId!) + 1;
      } else {
        insertAt = command.targetIndex;
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

SortConfig<TaskSortFields> _customSort({required bool showCustomSortIndicator}) => SortConfig<TaskSortFields>(
      orderOptions: const [],
      useCustomOrder: true,
      enableGrouping: false,
      showCustomSortIndicator: showCustomSortIndicator,
    );

void main() {
  late TaskMediator mediator;

  setUp(() {
    final fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
    mediator = TaskMediator(['task-a', 'task-b']);

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

  Future<void> pumpSliverTaskList(WidgetTester tester, {required bool showCustomSortIndicator}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            TaskList(
              sortConfig: _customSort(showCustomSortIndicator: showCustomSortIndicator),
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

  testWidgets('with the indicator visible, drag handles render', (tester) async {
    await pumpSliverTaskList(tester, showCustomSortIndicator: true);

    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
  });

  testWidgets('with the indicator hidden, no handle renders but long-press reorder stays available', (tester) async {
    await pumpSliverTaskList(tester, showCustomSortIndicator: false);

    expect(find.byIcon(Icons.drag_handle), findsNothing);
    // ReorderableDelayedDragStartListener extends ReorderableDragStartListener,
    // so match the delayed subtype specifically — otherwise a plain handle
    // listener would satisfy this assertion.
    expect(find.byType(ReorderableDelayedDragStartListener), findsNWidgets(2));
  });

  testWidgets('REAL GESTURE: with the indicator hidden, a whole-card long press reorders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSliverTaskList(tester, showCustomSortIndicator: false);

    expect(renderedOrder(tester), ['task-a', 'task-b']);
    expect(find.byIcon(Icons.drag_handle), findsNothing, reason: 'no handle may exist to grab');

    final cards = find.byType(TaskCard);
    final start = tester.getCenter(cards.at(0));
    final rowHeight = tester.getCenter(cards.at(1)).dy - start.dy;

    // Press the card body itself, hold past the long-press delay, then drag.
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(Offset(0, rowHeight * 0.6));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(Offset(0, rowHeight * 0.6));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(mediator.commands, hasLength(1), reason: 'a whole-card long-press drag must persist a reorder');
    expect(renderedOrder(tester), ['task-b', 'task-a']);
  });

  testWidgets('REAL GESTURE: a short whole-card drag does not reorder', (tester) async {
    // Discriminates the delayed listener from a plain one: without the
    // long-press hold the same movement must scroll, never reorder.
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSliverTaskList(tester, showCustomSortIndicator: false);

    final cards = find.byType(TaskCard);
    final start = tester.getCenter(cards.at(0));
    final rowHeight = tester.getCenter(cards.at(1)).dy - start.dy;

    final gesture = await tester.startGesture(start);
    await gesture.moveBy(Offset(0, rowHeight * 0.6));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(Offset(0, rowHeight * 0.6));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(mediator.commands, isEmpty);
    expect(renderedOrder(tester), ['task-a', 'task-b']);
  });
}
