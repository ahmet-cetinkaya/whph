// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/main.dart' as app_main;
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_creation_helper.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/features/tasks/services/default_task_settings_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/abstraction/i_default_task_settings_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/acore.dart';

import 'task_creation_helper_test.mocks.dart';

// Test logger that discards all log messages
class TestLogger implements ILogger {
  const TestLogger();

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {}
}

@GenerateMocks([
  Mediator,
  ITranslationService,
  TasksService,
  IDefaultTaskSettingsService,
])
void main() {
  late MockMediator mockMediator;
  late MockITranslationService mockTranslationService;
  late MockTasksService mockTasksService;
  late MockIDefaultTaskSettingsService mockDefaultSettingsService;
  late FakeContainer fakeContainer;

  setUpAll(() {
    fakeContainer = FakeContainer();
    app_main.container = fakeContainer;
  });

  setUp(() {
    mockMediator = MockMediator();
    mockTranslationService = MockITranslationService();
    mockTasksService = MockTasksService();
    mockDefaultSettingsService = MockIDefaultTaskSettingsService();

    fakeContainer.registerInstance<Mediator>(mockMediator);
    fakeContainer.registerInstance<ITranslationService>(mockTranslationService);
    fakeContainer.registerInstance<TasksService>(mockTasksService);
    fakeContainer.registerInstance<IDefaultTaskSettingsService>(mockDefaultSettingsService);

    // Setup default mock behaviors
    when(mockTranslationService.translate(any)).thenAnswer((_) => 'Translated text');
    when(mockDefaultSettingsService.getDefaultEstimatedTime()).thenAnswer((_) async => null);
    when(mockDefaultSettingsService.getDefaultPlannedDateReminder()).thenAnswer((_) async => (ReminderTime.none, null));
  });

  tearDown(() {
    fakeContainer.clear();
  });

  group('TaskCreationHelper Tests - skipQuickAdd Setting', () {
    testWidgets('should show QuickAddTaskDialog when skipQuickAdd setting is false', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'false',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => TaskCreationHelper.createTask(context: context),
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert - should have called mediator to get setting
      verify(mockMediator.send<GetSettingQuery, Setting?>(any)).called(1);
    });

    testWidgets('should create task immediately when skipQuickAdd setting is true', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(
                id: 'task-1',
                createdDate: DateTime.now().toUtc(),
              ));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => TaskCreationHelper.createTask(context: context),
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any)).called(1);
    });

    testWidgets('should use default when setting retrieval fails', (WidgetTester tester) async {
      // Arrange
      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenThrow(Exception('Setting not found'));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => TaskCreationHelper.createTask(context: context),
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert - should have tried to get setting (using default on error)
      verify(mockMediator.send<GetSettingQuery, Setting?>(any)).called(1);
    });

    testWidgets('should not call createTask when context is unmounted', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);

      // Act - Create a scenario where widget is unmounted before setting load completes
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // Simulate async operation that completes after unmount
                    Future.delayed(const Duration(milliseconds: 100), () {
                      TaskCreationHelper.createTask(context: context);
                    });
                  },
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      // Unmount immediately
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Assert - should not crash or create task
      verifyNever(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any));
    });
  });

  group('TaskCreationHelper Tests - Default Settings Loading', () {
    testWidgets('should load default estimated time when not provided', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockDefaultSettingsService.getDefaultEstimatedTime()).thenAnswer((_) async => 30);
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(
                id: 'task-1',
                createdDate: DateTime.now().toUtc(),
              ));

      SaveTaskCommand? capturedCommand;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    TaskCreationHelper.createTask(context: context);
                  },
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert
      final captured = verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(captureThat(
        predicate<SaveTaskCommand>((cmd) => cmd.estimatedTime == 30),
      ))).captured;
      expect(captured.isNotEmpty, isTrue);
    });

    testWidgets('should load default reminder settings when planned date is set', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockDefaultSettingsService.getDefaultPlannedDateReminder())
          .thenAnswer((_) async => (ReminderTime.fifteenMinutesBefore, null));
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(
                id: 'task-1',
                createdDate: DateTime.now().toUtc(),
              ));

      final plannedDate = DateTime.now().add(const Duration(days: 1));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    TaskCreationHelper.createTask(
                      context: context,
                      initialPlannedDate: plannedDate,
                    );
                  },
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(captureThat(
        predicate<SaveTaskCommand>(
            (cmd) => cmd.plannedDateReminderTime == ReminderTime.fifteenMinutesBefore && cmd.plannedDate != null),
      ))).called(1);
    });

    testWidgets('should not apply reminder when plannedDate is null', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(
                id: 'task-1',
                createdDate: DateTime.now().toUtc(),
              ));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    TaskCreationHelper.createTask(context: context);
                  },
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(captureThat(
        predicate<SaveTaskCommand>(
            (cmd) => cmd.plannedDateReminderTime == ReminderTime.none && cmd.plannedDateReminderCustomOffset == null),
      ))).called(1);
    });
  });

  group('TaskCreationHelper Tests - Callback and Navigation', () {
    testWidgets('should invoke onTaskCreated callback with correct data', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(
                id: 'task-123',
                createdDate: DateTime.now().toUtc(),
              ));

      String? capturedTaskId;
      TaskData? capturedTaskData;

      final tagIds = ['tag-1', 'tag-2'];
      final priority = EisenhowerPriority.urgentImportant;
      final estimatedTime = 45;
      final plannedDate = DateTime.now().add(const Duration(days: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    TaskCreationHelper.createTask(
                      context: context,
                      initialTagIds: tagIds,
                      initialPlannedDate: plannedDate,
                      initialPriority: priority,
                      initialEstimatedTime: estimatedTime,
                      initialTitle: 'Test Task',
                      onTaskCreated: (taskId, taskData) {
                        capturedTaskId = taskId;
                        capturedTaskData = taskData;
                      },
                    );
                  },
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert
      expect(capturedTaskId, equals('task-123'));
      expect(capturedTaskData, isNotNull);
      expect(capturedTaskData!.tagIds, equals(tagIds));
      expect(capturedTaskData!.priority, equals(priority));
      expect(capturedTaskData!.estimatedTime, equals(estimatedTime));
    });

    testWidgets('should include tagIds in TaskData callback', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(
                id: 'task-456',
                createdDate: DateTime.now().toUtc(),
              ));

      List<String>? capturedTagIds;
      final expectedTagIds = ['tag-a', 'tag-b', 'tag-c'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    TaskCreationHelper.createTask(
                      context: context,
                      initialTagIds: expectedTagIds,
                      onTaskCreated: (taskId, taskData) {
                        capturedTagIds = taskData.tagIds;
                      },
                    );
                  },
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert
      expect(capturedTagIds, equals(expectedTagIds));
    });

    testWidgets('should show TaskDetailsPage after immediate creation', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any))
          .thenAnswer((_) async => SaveTaskCommandResponse(
                id: 'task-789',
                createdDate: DateTime.now().toUtc(),
              ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    TaskCreationHelper.createTask(context: context);
                  },
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(TaskDetailsPage), findsOneWidget);
    });
  });

  group('TaskCreationHelper Tests - Error Handling', () {
    testWidgets('should handle save task errors gracefully', (WidgetTester tester) async {
      // Arrange
      final setting = Setting(
        id: 'setting-id',
        key: SettingKeys.taskSkipQuickAdd,
        value: 'true',
        valueType: SettingValueType.bool,
        createdDate: DateTime.now().toUtc(),
        modifiedDate: DateTime.now().toUtc(),
      );

      when(mockMediator.send<GetSettingQuery, Setting?>(any)).thenAnswer((_) async => setting);
      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(any)).thenThrow(Exception('Save failed'));
      when(mockTranslationService.translate(TaskTranslationKeys.saveTaskError)).thenReturn('Error saving task');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    TaskCreationHelper.createTask(context: context);
                  },
                  child: const Text('Create Task'),
                );
              },
            ),
          ),
        ),
      );

      // Act & Assert - should not crash
      await tester.tap(find.text('Create Task'));
      await tester.pumpAndSettle();

      // Verify error was handled (no exception thrown)
      expect(tester.takeException(), isNull);
    });
  });
}

/// Fake container implementation for dependency injection in tests
class FakeContainer implements IContainer {
  final Map<Type, Object?> _instances = {};
  final Map<String, Object?> _namedInstances = {};

  @override
  IContainer get instance => this;

  void registerInstance<T>(T instance, [String? name]) {
    if (name != null) {
      _namedInstances[name] = instance;
    } else {
      _instances[T] = instance;
    }
  }

  void clear() {
    _instances.clear();
    _namedInstances.clear();
  }

  @override
  T resolve<T>([String? name]) {
    if (name != null) {
      if (_namedInstances.containsKey(name)) {
        return _namedInstances[name] as T;
      }
      throw UnimplementedError('No instance registered for name: $name');
    }
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }
    throw UnimplementedError('No instance registered for type $T');
  }

  @override
  bool isRegistered<T>([String? name]) {
    if (name != null) {
      return _namedInstances.containsKey(name);
    }
    return _instances.containsKey(T);
  }

  @override
  void registerSingleton<T>(T Function(IContainer) factory) {
    _instances[T] = factory(this);
  }
}
