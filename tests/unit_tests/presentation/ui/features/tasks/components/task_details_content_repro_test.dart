import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/task_details_content.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_date_picker_field.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:application/features/tasks/queries/get_task_query.dart';
import 'package:application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:application/features/tasks/commands/save_task_command.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:acore/acore.dart';

import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';

// Mocks
class FakeContainer extends Fake implements IContainer {
  final Map<Type, Object> _instances = {};

  void register<T>(T instance) {
    _instances[T] = instance as Object;
  }

  @override
  T resolve<T>() {
    if (!_instances.containsKey(T)) {
      throw Exception('Type $T not registered in FakeContainer');
    }
    return _instances[T] as T;
  }
}

class FakeMediator extends Fake implements Mediator {
  final List<Object> sentRequests = [];
  final Map<Type, Function(Object)> _fakeHandlers = {};

  void registerFakeHandler<TRequest, TResponse>(Future<TResponse> Function(TRequest) handler) {
    _fakeHandlers[TRequest] = (req) => handler(req as TRequest);
  }

  @override
  Future<TResponse> send<TRequest extends IRequest<TResponse>, TResponse>(TRequest request) async {
    sentRequests.add(request as Object);
    if (_fakeHandlers.containsKey(TRequest)) {
      return await _fakeHandlers[TRequest]!(request) as TResponse;
    }
    throw Exception('No handler for $TRequest');
  }
}

class FakeTasksService extends Fake implements TasksService {
  @override
  ValueNotifier<String?> get onTaskUpdated => ValueNotifier(null);
  @override
  ValueNotifier<String?> get onTaskDeleted => ValueNotifier(null);
  @override
  void notifyTaskUpdated(String taskId) {}
  @override
  void notifyTaskCompleted(String taskId) {}
}

class FakeTranslationService extends Fake implements ITranslationService {
  @override
  String translate(String key, {Map<String, dynamic>? namedArgs}) => key;
}

class FakeTagsService extends Fake implements TagsService {
  @override
  ValueNotifier<String?> get onTagUpdated => ValueNotifier(null);
}

class MockTaskRecurrenceService extends Mock implements ITaskRecurrenceService {
  @override
  List<WeekDays>? getRecurrenceDays(Task? task) => [];
}

class FakeSoundManagerService extends Fake implements ISoundManagerService {
  @override
  Future<void> playTaskCompletion() async {}
}

class FakeLogger extends Fake implements ILogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    debugPrint('DEBUG: $message');
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    debugPrint('INFO: $message');
  }

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    debugPrint('WARNING: $message');
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    debugPrint('ERROR: $message');
  }

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) {
    debugPrint('FATAL: $message');
  }
}

void main() {
  late FakeContainer fakeContainer;
  late FakeMediator mockMediator;
  late FakeTasksService mockTasksService;
  late FakeTranslationService mockTranslationService;
  late FakeTagsService mockTagsService;
  late MockTaskRecurrenceService mockTaskRecurrenceService;

  setUpAll(() {
    fakeContainer = FakeContainer();
    // Initialize the global container
    container = fakeContainer;
  });

  setUp(() {
    mockMediator = FakeMediator();
    mockTasksService = FakeTasksService();
    mockTranslationService = FakeTranslationService();
    mockTagsService = FakeTagsService();
    mockTaskRecurrenceService = MockTaskRecurrenceService();

    // Register mocks in fake container
    fakeContainer.register<Mediator>(mockMediator);
    fakeContainer.register<TasksService>(mockTasksService);
    fakeContainer.register<ITranslationService>(mockTranslationService);
    fakeContainer.register<TagsService>(mockTagsService);
    fakeContainer.register<ITaskRecurrenceService>(mockTaskRecurrenceService);
    fakeContainer.register<ISoundManagerService>(FakeSoundManagerService());
    fakeContainer.register<ILogger>(FakeLogger());

    // Setup default stubs
    // No need to stub getters for Fakes as they are implemented
  });

  testWidgets('TaskDetailsContent saves custom reminder offset correctly', (WidgetTester tester) async {
    // Arrange
    final taskId = 'test-task-id';
    final task = GetTaskQueryResponse(
      id: taskId,
      title: 'Test Task',
      createdDate: DateTime.now(),
      plannedDate: DateTime.now().add(const Duration(hours: 1)),
      plannedDateReminderTime: ReminderTime.none,
      totalDuration: 0,
      parentTaskId: null,
      subTasksCompletionPercentage: 0,
      subTasks: [],
    );

    mockMediator.registerFakeHandler<GetTaskQuery, GetTaskQueryResponse>((req) async => task);
    mockMediator.registerFakeHandler<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
        (req) async => GetListTaskTagsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 10));
    mockMediator.registerFakeHandler<SaveTaskCommand, SaveTaskCommandResponse>(
        (req) async => SaveTaskCommandResponse(id: taskId, createdDate: DateTime.now()));

    // Act
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TaskDetailsContent(taskId: taskId),
        ),
      ));
      // Wait for initial data load which might involve timers or async gaps
      await tester.pump(const Duration(seconds: 1));
    });

    await tester.pumpAndSettle();

    // Verify initial load
    expect(mockMediator.sentRequests.whereType<GetTaskQuery>().length, equals(1));

    // Verify TaskDetailsContent is present
    expect(find.byType(TaskDetailsContent), findsOneWidget);

    // Verify if loading
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      debugPrint('Still loading...');
    }

    // Simulate changing reminder to custom
    final datePickerFinder = find.byType(TaskDatePickerField);
    expect(datePickerFinder, findsOneWidget, reason: 'TaskDatePickerField should be visible');
    final plannedDatePicker = tester.widget<TaskDatePickerField>(datePickerFinder.first);

    // Trigger the callback with custom reminder
    plannedDatePicker.onReminderChanged(ReminderTime.custom, 15);

    await tester.pump(); // Rebuild
    await tester.pump(const Duration(milliseconds: 500)); // Wait for async operations

    // Assert
    final saveCommand = mockMediator.sentRequests.whereType<SaveTaskCommand>().last;

    expect(saveCommand.plannedDateReminderTime, equals(ReminderTime.custom));
    expect(saveCommand.plannedDateReminderCustomOffset, equals(15));
  });
}
