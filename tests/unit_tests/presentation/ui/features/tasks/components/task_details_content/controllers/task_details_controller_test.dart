import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/controllers/task_details_controller.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/models/recurrence_configuration.dart';
import 'package:application/features/tasks/queries/get_task_query.dart';
import 'package:application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:application/features/tasks/commands/save_task_command.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

import 'task_details_controller_test.mocks.dart';

@GenerateMocks([
  Mediator,
  TasksService,
  ITranslationService,
  ITaskRecurrenceService,
  TagsService,
])
void main() {
  late TaskDetailsController controller;
  late MockMediator mockMediator;
  late MockTasksService mockTasksService;
  late MockITranslationService mockTranslationService;
  late MockITaskRecurrenceService mockTaskRecurrenceService;
  late MockTagsService mockTagsService;

  setUp(() {
    mockMediator = MockMediator();
    mockTasksService = MockTasksService();
    mockTranslationService = MockITranslationService();
    mockTaskRecurrenceService = MockITaskRecurrenceService();
    mockTagsService = MockTagsService();

    // Stub listeners
    when(mockTasksService.onTaskUpdated).thenReturn(ValueNotifier<String?>(null));
    when(mockTasksService.onTaskDeleted).thenReturn(ValueNotifier<String?>(null));
    when(mockTasksService.onTaskCreated).thenReturn(ValueNotifier<String?>(null));
    when(mockTasksService.onTaskCompleted).thenReturn(ValueNotifier<String?>(null));
    when(mockTasksService.onTaskTimeRecordUpdated).thenReturn(ValueNotifier<String?>(null));

    when(mockTagsService.onTagUpdated).thenReturn(ValueNotifier<String?>(null));
    when(mockTagsService.onTagCreated).thenReturn(ValueNotifier<String?>(null));
    when(mockTagsService.onTagDeleted).thenReturn(ValueNotifier<String?>(null));

    when(mockTaskRecurrenceService.getRecurrenceDays(any)).thenReturn(null);

    controller = TaskDetailsController(
      mediator: mockMediator,
      tasksService: mockTasksService,
      translationService: mockTranslationService,
      taskRecurrenceService: mockTaskRecurrenceService,
      tagsService: mockTagsService,
    );
  });

  group('TaskDetailsController Tests', () {
    test('buildSaveCommand should include recurrenceConfiguration from task', () async {
      // Arrange
      const taskId = 'task-1';
      final config = RecurrenceConfiguration(
        frequency: RecurrenceFrequency.monthly,
        monthlyPatternType: MonthlyPatternType.relativeDay,
        weekOfMonth: 2,
        dayOfWeek: 2,
      );

      final taskResponse = GetTaskQueryResponse(
        id: taskId,
        title: 'Test Task',
        createdDate: DateTime.now(),
        parentTaskId: null,
        subTasksCompletionPercentage: 0,
        subTasks: [],
        totalDuration: 0,
        recurrenceConfiguration: config,
        recurrenceType: RecurrenceType.monthly,
      );

      final tagsResponse = GetListTaskTagsQueryResponse(
        items: [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 10,
      );

      when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(argThat(isA<GetTaskQuery>())))
          .thenAnswer((_) async => taskResponse);

      when(mockMediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(argThat(isA<GetListTaskTagsQuery>())))
          .thenAnswer((_) async => tagsResponse);

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(isA<SaveTaskCommand>())))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: taskId, createdDate: DateTime.now()));

      // Act
      await controller.initialize(taskId);
      final command = controller.buildSaveCommand();

      // Assert
      expect(command.recurrenceConfiguration, equals(config));
      expect(command.recurrenceType, equals(RecurrenceType.monthly));
    });

    test('updateRecurrence should update task and preserve configuration', () async {
      // Arrange
      const taskId = 'task-1';
      final initialTask = GetTaskQueryResponse(
        id: taskId,
        title: 'Test Task',
        createdDate: DateTime.now(),
        parentTaskId: null,
        subTasksCompletionPercentage: 0,
        subTasks: [],
        totalDuration: 0,
        recurrenceType: RecurrenceType.none,
      );

      final tagsResponse = GetListTaskTagsQueryResponse(
        items: [],
        totalItemCount: 0,
        pageIndex: 0,
        pageSize: 10,
      );

      when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(argThat(isA<GetTaskQuery>())))
          .thenAnswer((_) async => initialTask);

      when(mockMediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(argThat(isA<GetListTaskTagsQuery>())))
          .thenAnswer((_) async => tagsResponse);

      when(mockMediator.send<SaveTaskCommand, SaveTaskCommandResponse>(argThat(isA<SaveTaskCommand>())))
          .thenAnswer((_) async => SaveTaskCommandResponse(id: taskId, createdDate: DateTime.now()));

      await controller.initialize(taskId);

      final newConfig = RecurrenceConfiguration(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: [1, 3, 5],
      );

      // Act
      controller.updateRecurrence(
        recurrenceConfiguration: newConfig,
      );

      final command = controller.buildSaveCommand();

      // Assert
      expect(controller.task?.recurrenceType, equals(RecurrenceType.daysOfWeek));
      expect(controller.task?.recurrenceConfiguration, equals(newConfig));
      expect(command.recurrenceType, equals(RecurrenceType.daysOfWeek));
      expect(command.recurrenceConfiguration, equals(newConfig));
    });

    test('getRecurrenceSummaryText should show monthly relative day summary', () async {
      // Arrange
      const taskId = 'task-1';
      final config = RecurrenceConfiguration(
        frequency: RecurrenceFrequency.monthly,
        monthlyPatternType: MonthlyPatternType.relativeDay,
        weekOfMonth: 2, // Second
        dayOfWeek: 2, // Tuesday
      );

      final taskResponse = GetTaskQueryResponse(
        id: taskId,
        title: 'Test Task',
        createdDate: DateTime.now(),
        parentTaskId: null,
        subTasksCompletionPercentage: 0,
        subTasks: [],
        totalDuration: 0,
        recurrenceConfiguration: config,
        recurrenceType: RecurrenceType.monthly,
      );

      when(mockMediator.send<GetTaskQuery, GetTaskQueryResponse>(argThat(isA<GetTaskQuery>())))
          .thenAnswer((_) async => taskResponse);
      when(mockMediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(argThat(isA<GetListTaskTagsQuery>())))
          .thenAnswer(
              (_) async => GetListTaskTagsQueryResponse(items: [], totalItemCount: 0, pageIndex: 0, pageSize: 10));

      when(mockTranslationService.translate(any)).thenAnswer((invocation) => invocation.positionalArguments[0]);

      await controller.initialize(taskId);

      // Act
      final summary = controller.getRecurrenceSummaryText();

      // Assert
      expect(summary, contains(TaskTranslationKeys.recurrenceOnThe));
      expect(summary, contains(TaskTranslationKeys.recurrenceWeekModifierSecond));
    });
  });
}
