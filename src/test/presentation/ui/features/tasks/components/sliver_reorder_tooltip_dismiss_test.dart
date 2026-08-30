import 'package:acore/acore.dart' hide Container;
import 'package:flutter/gestures.dart';
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
import 'package:whph/presentation/ui/features/tasks/components/schedule_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/tasks_list.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
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

class ReorderMediator extends Fake implements Mediator {
  ReorderMediator(this.order);

  List<String> order;

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
              plannedDate: DateTime.utc(2030, 1, 1, 9),
              plannedDateReminderTime: ReminderTime.atTime,
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
      final next = List<String>.from(order)..remove(command.taskId);
      next.insert(command.targetIndex.clamp(0, next.length), command.taskId);
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

SortConfig<TaskSortFields> _customSort({bool showCustomSortIndicator = true}) => SortConfig<TaskSortFields>(
      orderOptions: const [],
      useCustomOrder: true,
      enableGrouping: false,
      showCustomSortIndicator: showCustomSortIndicator,
    );

void main() {
  late FakeContainer fakeContainer;

  void setUpContainer(List<String> order) {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;

    final translationService = MockTranslationService();
    fakeContainer.register<Mediator>(ReorderMediator(order));
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

  Future<void> pumpSliverTaskList(WidgetTester tester, {bool showCustomSortIndicator = true}) async {
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

  /// The text rendered into [ScheduleButton]'s layout-aware overlay. Only
  /// matches while the hover label is actually visible.
  Finder visibleScheduleTooltip() => find.text(TaskTranslationKeys.taskScheduleTooltip);

  /// Whether any row still offers a [Tooltip]. Reorder must suppress them for
  /// the whole drag, because a tooltip anchored to a moving sliver child
  /// resolves a null layout offset.
  Finder rowTooltips() => find.byType(Tooltip);

  testWidgets('reorder drag start suppresses row tooltips before the dragged item moves', (tester) async {
    setUpContainer(['task-a', 'task-b', 'task-c']);
    // Without the drag handle the card itself is the drag affordance, which is
    // the surface where a hovered tooltip and a live reorder overlap.
    await pumpSliverTaskList(tester, showCustomSortIndicator: false);

    // Hover a schedule button until its tooltip is shown, so a tooltip overlay
    // is anchored to a sliver child render box when the drag begins.
    final scheduleButton = find.byType(ScheduleButton).first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(scheduleButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      visibleScheduleTooltip(),
      findsOneWidget,
      reason: 'the tooltip must be open before the drag so the regression can be exercised',
    );
    final idleTooltipCount = rowTooltips().evaluate().length;

    // Start a real reorder drag by long-pressing a card.
    final drag = await tester.startGesture(tester.getCenter(find.text('task-a')));
    await tester.pump(kLongPressTimeout);

    // The pointer has not moved yet, so only a drag-start handler can have
    // suppressed the tooltips. Starting drag state after the drop instead
    // leaves them mounted while the reorder reparents and moves the child.
    expect(
      visibleScheduleTooltip(),
      findsNothing,
      reason: 'the hovered tooltip must be dismissed the moment the reorder drag starts',
    );
    expect(
      rowTooltips().evaluate().length,
      lessThan(idleTooltipCount),
      reason: 'row tooltips must be suppressed at drag start, not only after the drop',
    );

    // While the drag is live the rows reflow under the cursor. A tooltip
    // re-shown by that incidental hover would be anchored to a sliver child
    // the reorder is still moving.
    await drag.moveBy(const Offset(0, 40));
    await mouse.moveTo(tester.getCenter(find.byType(ScheduleButton).first));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(visibleScheduleTooltip(), findsNothing, reason: 'tooltips must stay suppressed for the whole drag');

    await drag.moveBy(const Offset(0, 40));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Reorder end must release drag state so the translated tooltip returns.
    expect(
      rowTooltips().evaluate().length,
      idleTooltipCount,
      reason: 'tooltips must be restored once the reorder ends',
    );
  });

  testWidgets('reorder drag with an open ScheduleButton tooltip does not throw', (tester) async {
    setUpContainer(['task-a', 'task-b', 'task-c']);
    await pumpSliverTaskList(tester);

    final scheduleButton = find.byType(ScheduleButton).first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(scheduleButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(visibleScheduleTooltip(), findsOneWidget);

    final dragHandle = find.byKey(const ValueKey('sliver_trailing_drag_task-a'));
    final drag = await tester.startGesture(tester.getCenter(dragHandle));
    await tester.pump(kLongPressTimeout);
    await drag.moveBy(const Offset(0, 80));
    await tester.pump();
    await drag.moveBy(const Offset(0, 80));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
