import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_card.dart';
import 'package:whph/main.dart' as app_main;
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:acore/acore.dart';

class MockMediator extends Mock implements Mediator {}

class MockTranslationService extends Mock implements ITranslationService {
  @override
  String translate(String key, {Map<String, String>? namedArgs}) {
    // Return "Untitled" for the untitled translation key
    if (key == 'shared.untitled') return 'Untitled';
    return key;
  }
}

class MockSoundManagerService extends Mock implements ISoundManagerService {}

class MockTasksService extends Mock implements TasksService {}

class MockTaskRecurrenceService extends Mock implements ITaskRecurrenceService {}

class MockLogger extends Mock implements ILogger {}

class MockThemeService extends Mock implements IThemeService {
  @override
  Color get primaryColor => Colors.blue;

  @override
  Color get surface0 => const Color(0xFF1A1A24);

  @override
  Color get surface1 => const Color(0xFF1E1E2E);

  @override
  Color get surface2 => const Color(0xFF2A2A3C);

  @override
  Color get surface3 => const Color(0xFF3A3A4C);

  Color get background => const Color(0xFF1A1A24);

  @override
  Color get textColor => const Color(0xFFE0E0E0);

  @override
  Color get secondaryTextColor => const Color(0xFF9E9E9E);

  @override
  Color get darkTextColor => const Color(0xFFFFFFFF);

  @override
  Color get lightTextColor => const Color(0xFF000000);

  @override
  Color get dividerColor => const Color(0xFF3E3E4E);

  @override
  Color get barrierColor => const Color(0x80000000);

  bool get isDarkMode => true;

  TextTheme get textTheme => const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFE0E0E0)),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFFE0E0E0)),
      );

  @override
  UiDensity get currentUiDensity => UiDensity.compact;
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

void main() {
  late FakeContainer fakeContainer;
  late MockMediator mockMediator;
  late MockTranslationService mockTranslationService;
  late MockSoundManagerService mockSoundManagerService;
  late MockThemeService mockThemeService;
  late MockTasksService mockTasksService;
  late MockTaskRecurrenceService mockTaskRecurrenceService;
  late MockLogger mockLogger;

  setUpAll(() {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;

    mockMediator = MockMediator();
    mockTranslationService = MockTranslationService();
    mockSoundManagerService = MockSoundManagerService();
    mockThemeService = MockThemeService();
    mockTasksService = MockTasksService();
    mockTaskRecurrenceService = MockTaskRecurrenceService();
    mockLogger = MockLogger();

    fakeContainer.register<Mediator>(mockMediator);
    fakeContainer.register<ITranslationService>(mockTranslationService);
    fakeContainer.register<ISoundManagerService>(mockSoundManagerService);
    fakeContainer.register<IThemeService>(mockThemeService);
    fakeContainer.register<TasksService>(mockTasksService);
    fakeContainer.register<ITaskRecurrenceService>(mockTaskRecurrenceService);
    fakeContainer.register<ILogger>(mockLogger);
  });

  group('TaskCard swipe to complete', () {
    late TaskListItem testTask;

    setUp(() {
      testTask = TaskListItem(
        id: 'test-task-id',
        title: 'Test Task',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        tags: [],
        subTasks: [],
      );
    });

    testWidgets('should call onCompleted when swiped right past threshold', (tester) async {
      // Arrange
      bool completedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: (id) => completedCalled = true,
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Act - Swipe right past 40% threshold
      // Get the actual widget size and calculate 40% + some margin
      await tester.pumpAndSettle();
      final cardSize = tester.getSize(find.byType(TaskCard));
      final swipeDistance = cardSize.width * 0.5; // Swipe 50% to ensure we pass the 40% threshold

      await tester.drag(
        find.byType(TaskCard),
        Offset(swipeDistance, 0),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(completedCalled, isTrue);
    });

    testWidgets('should not call onCompleted when swiped below threshold', (tester) async {
      // Arrange
      bool completedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: (id) => completedCalled = true,
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Act - Swipe right but not past 40% threshold
      await tester.pumpAndSettle();
      final cardSize = tester.getSize(find.byType(TaskCard));
      final swipeDistance = cardSize.width * 0.3; // Swipe only 30% to stay below threshold

      await tester.drag(
        find.byType(TaskCard),
        Offset(swipeDistance, 0),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(completedCalled, isFalse);
    });

    testWidgets('should not dismiss widget after swipe (returns false)', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: (id) {},
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Act - Swipe right past threshold
      await tester.pumpAndSettle();
      final cardSize = tester.getSize(find.byType(TaskCard));
      final swipeDistance = cardSize.width * 0.5;

      await tester.drag(
        find.byType(TaskCard),
        Offset(swipeDistance, 0),
      );
      await tester.pumpAndSettle();

      // Assert - TaskCard should still be in the tree (not dismissed)
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('should not enable swipe when task is already completed', (tester) async {
      // Arrange
      final completedTask = TaskListItem(
        id: 'completed-task-id',
        title: 'Completed Task',
        isCompleted: true,
        priority: EisenhowerPriority.urgentImportant,
        tags: [],
        subTasks: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: completedTask,
              onOpenDetails: () {},
              onCompleted: (id) {},
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Act - Try to find Dismissible widget
      final dismissibleFinder = find.byType(Dismissible);

      // Assert - No Dismissible should be found for completed tasks
      expect(dismissibleFinder, findsNothing);
    });

    testWidgets('should not enable swipe when onCompleted callback is null', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: null, // No callback provided
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Act - Try to find Dismissible widget
      final dismissibleFinder = find.byType(Dismissible);

      // Assert - No Dismissible should be found when callback is null
      expect(dismissibleFinder, findsNothing);
    });

    testWidgets('should show background with check icon during swipe', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: (id) {},
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Act - Start swipe (but don't complete it)
      await tester.drag(
        find.byType(TaskCard),
        Offset(100, 0), // Small movement to see background
      );
      await tester.pump(); // Pump once to show animation state

      // Assert - Check icon should be visible in the background
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should not enable swipe on subtasks', (tester) async {
      // Arrange
      final taskWithSubTasks = TaskListItem(
        id: 'parent-task-id',
        title: 'Parent Task',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        tags: [],
        subTasks: [
          TaskListItem(
            id: 'subtask-id',
            title: 'Subtask',
            isCompleted: false,
            priority: EisenhowerPriority.urgentImportant,
            tags: [],
            subTasks: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: taskWithSubTasks,
              onOpenDetails: () {},
              onCompleted: (id) {},
              showSubTasks: true,
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Act - Find all Dismissible widgets
      final dismissibleFinder = find.byType(Dismissible);

      // Assert - Should only have one Dismissible (parent task), subtasks should not
      expect(dismissibleFinder, findsOneWidget);
    });

    testWidgets('should not enable swipe when enableSwipeToComplete is false', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: (id) {},
              enableSwipeToComplete: false, // Explicitly disable swipe
            ),
          ),
        ),
      );

      // Act - Try to find Dismissible widget
      final dismissibleFinder = find.byType(Dismissible);

      // Assert - No Dismissible should be found
      expect(dismissibleFinder, findsNothing);
    });

    testWidgets('should only allow swiping from left to right (startToEnd)', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: (id) {},
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Find the Dismissible
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));

      // Assert - Only startToEnd direction should be enabled
      expect(dismissible.direction, DismissDirection.startToEnd);
    });

    testWidgets('should use 40% threshold for swipe completion', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: (id) {},
              enableSwipeToComplete: true,
            ),
          ),
        ),
      );

      // Find the Dismissible
      final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));

      // Assert - Threshold should be 0.4 (40%)
      expect(
        dismissible.dismissThresholds[DismissDirection.startToEnd],
        0.4,
      );
    });
  });

  group('TaskCard non-swipe functionality', () {
    late TaskListItem testTask;

    setUp(() {
      testTask = TaskListItem(
        id: 'test-task-id',
        title: 'Test Task',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        tags: [],
        subTasks: [],
      );
    });

    testWidgets('should call onOpenDetails when tapped', (tester) async {
      // Arrange
      bool detailsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () => detailsOpened = true,
              onCompleted: (id) {},
            ),
          ),
        ),
      );

      // Act - Tap the card
      await tester.tap(find.byType(TaskCard));
      await tester.pumpAndSettle();

      // Assert
      expect(detailsOpened, isTrue);
    });

    testWidgets('should display task title', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: testTask,
              onOpenDetails: () {},
              onCompleted: (id) {},
            ),
          ),
        ),
      );

      // Act & Assert
      expect(find.text('Test Task'), findsOneWidget);
    });

    testWidgets('should display Untitled when task title is empty', (tester) async {
      // Arrange
      final emptyTitleTask = TaskListItem(
        id: 'empty-title-task',
        title: '',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        tags: [],
        subTasks: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: emptyTitleTask,
              onOpenDetails: () {},
              onCompleted: (id) {},
            ),
          ),
        ),
      );

      // Act & Assert - Should show "Untitled" instead of empty string
      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('should display subtasks when showSubTasks is true', (tester) async {
      // Arrange
      final taskWithSubTasks = TaskListItem(
        id: 'parent-task',
        title: 'Parent Task',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        tags: [],
        subTasks: [
          TaskListItem(
            id: 'subtask-1',
            title: 'Subtask 1',
            isCompleted: false,
            priority: EisenhowerPriority.urgentImportant,
            tags: [],
            subTasks: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: taskWithSubTasks,
              onOpenDetails: () {},
              onCompleted: (id) {},
              showSubTasks: true,
            ),
          ),
        ),
      );

      // Act & Assert
      expect(find.text('Subtask 1'), findsOneWidget);
    });

    testWidgets('should not display subtasks when showSubTasks is false', (tester) async {
      // Arrange
      final taskWithSubTasks = TaskListItem(
        id: 'parent-task',
        title: 'Parent Task',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        tags: [],
        subTasks: [
          TaskListItem(
            id: 'subtask-1',
            title: 'Subtask 1',
            isCompleted: false,
            priority: EisenhowerPriority.urgentImportant,
            tags: [],
            subTasks: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard(
              taskItem: taskWithSubTasks,
              onOpenDetails: () {},
              onCompleted: (id) {},
              showSubTasks: false,
            ),
          ),
        ),
      );

      // Act & Assert
      expect(find.text('Subtask 1'), findsNothing);
    });
  });
}
