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
  MockTranslationService([this.translations = const {}]);

  final Map<String, String> translations;

  @override
  String translate(String key, {Map<String, String>? namedArgs}) => translations[key] ?? key;
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

/// Serves two grouped runs of tasks and records the reorder commands the
/// widget issues, so an ignored drop is observable as "no command at all".
class GroupedReorderMediator extends Fake implements Mediator {
  GroupedReorderMediator(this.groupOfTask);

  /// Task id -> group name, in render order.
  final Map<String, String> groupOfTask;
  final List<UpdateTaskOrderCommand> commands = [];

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse extends Object?>(TRequest request) async {
    if (request is GetListTasksQuery) {
      return GetListTasksQueryResponse(
        items: [
          for (final (index, entry) in groupOfTask.entries.indexed)
            TaskListItem(
              id: entry.key,
              title: entry.key,
              priority: null,
              isCompleted: false,
              groupName: entry.value,
              isGroupNameTranslatable: true,
              // Well-spaced base-62 ranks so the widget does not trigger its
              // "orders need normalization" repair path.
              order: String.fromCharCode('F'.codeUnitAt(0) + index * 5),
            ),
        ],
        totalItemCount: groupOfTask.length,
        pageIndex: 0,
        pageSize: groupOfTask.length,
      ) as TResponse;
    }
    if (request is UpdateTaskOrderCommand) {
      final command = request as UpdateTaskOrderCommand;
      commands.add(command);
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

SortConfig<TaskSortFields> _groupedCustomSort() => const SortConfig<TaskSortFields>(
      orderOptions: [
        SortOptionWithTranslationKey(
          field: TaskSortFields.status,
          direction: SortDirection.asc,
          translationKey: 'tasks.status',
        ),
      ],
      useCustomOrder: true,
      enableGrouping: true,
      groupOption: SortOptionWithTranslationKey(
        field: TaskSortFields.status,
        direction: SortDirection.asc,
        translationKey: 'tasks.status',
      ),
    );

void main() {
  late FakeContainer fakeContainer;
  late GroupedReorderMediator mediator;

  /// Renders two groups: header(alpha), a1, a2, header(beta), b1, b2.
  /// Visual indices: 0 header, 1 a1, 2 a2, 3 header, 4 b1, 5 b2.
  void setUpContainer({
    Map<String, String>? groupOfTask,
    Map<String, String> translations = const {},
  }) {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
    mediator = GroupedReorderMediator(
      groupOfTask ??
          {
            'task-a1': 'alpha',
            'task-a2': 'alpha',
            'task-b1': 'beta',
            'task-b2': 'beta',
          },
    );

    final translationService = MockTranslationService(translations);
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

  Future<void> pumpGroupedSliverTaskList(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            TaskList(
              sortConfig: _groupedCustomSort(),
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

  setUp(setUpContainer);

  testWidgets('a drop inside the source group is accepted', (tester) async {
    await pumpGroupedSliverTaskList(tester);

    final state = tester.state<State<TaskList>>(find.byType(TaskList)) as dynamic;

    // Move a1 (visual 1) past a2 (pre-removal newIndex 3, the slot just after
    // the group's last item) — still inside alpha.
    state.onSliverReorderForTest(1, 3);
    await tester.pumpAndSettle();

    expect(mediator.commands, hasLength(1));
    expect(mediator.commands.single.taskId, 'task-a1');
  });

  testWidgets('reordering a task dismisses its visible schedule tooltip before the sliver detaches it', (tester) async {
    await pumpGroupedSliverTaskList(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);

    final firstScheduleButton = find.descendant(
      of: find.byKey(const ValueKey('sliver_task_card_task-a1')),
      matching: find.byType(ScheduleButton),
    );
    await mouse.moveTo(tester.getCenter(firstScheduleButton));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('tasks.card.tooltips.schedule'), findsOneWidget);

    final dragHandle = find.byKey(const ValueKey('sliver_trailing_drag_task-a1'));
    await mouse.moveTo(tester.getCenter(dragHandle));
    await mouse.down(tester.getCenter(dragHandle));
    await tester.pump();
    await mouse.moveBy(const Offset(0, 100));
    await tester.pump();

    expect(find.text('tasks.card.tooltips.schedule'), findsNothing);
    expect(tester.takeException(), isNull);

    await mouse.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a drop past the source group into another group is ignored', (tester) async {
    await pumpGroupedSliverTaskList(tester);

    final state = tester.state<State<TaskList>>(find.byType(TaskList)) as dynamic;

    // Move a1 (visual 1) down into beta's span (pre-removal newIndex 5). If
    // cross-group drops were merely clamped, this would still issue a reorder
    // command for a position the user never dragged to.
    state.onSliverReorderForTest(1, 5);
    await tester.pumpAndSettle();

    expect(mediator.commands, isEmpty);
  });

  testWidgets('headers follow translated labels while items stay stable inside each group', (tester) async {
    setUpContainer(
      groupOfTask: {
        'task-a1': 'group.a',
        'task-a2': 'group.a',
        'task-z1': 'group.z',
        'task-z2': 'group.z',
      },
      translations: const {'group.a': 'Zulu', 'group.z': 'Alpha'},
    );
    await pumpGroupedSliverTaskList(tester);

    final alphaY = tester.getCenter(find.text('Alpha')).dy;
    final zuluY = tester.getCenter(find.text('Zulu')).dy;
    expect(alphaY, lessThan(zuluY), reason: 'headers must sort by their displayed labels, not raw group keys');

    final renderedTasks = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .where((text) => text.startsWith('task-'))
        .toList();
    expect(renderedTasks, ['task-z1', 'task-z2', 'task-a1', 'task-a2']);
  });
}
