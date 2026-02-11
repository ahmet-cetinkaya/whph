import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:domain/features/tasks/task_constants.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/quick_add_task_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/abstraction/i_default_task_settings_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:acore/acore.dart';

class TaskCreationHelper {
  static Future<void> createTask({
    required BuildContext context,
    List<String>? initialTagIds,
    DateTime? initialPlannedDate,
    DateTime? initialDeadlineDate,
    EisenhowerPriority? initialPriority,
    int? initialEstimatedTime,
    String? initialTitle,
    bool? initialCompleted,
    String? initialParentTaskId,
    Function(String taskId, TaskData taskData)? onTaskCreated,
  }) async {
    final mediator = container.resolve<Mediator>();
    final translationService = container.resolve<ITranslationService>();
    final tasksService = container.resolve<TasksService>();
    final defaultSettingsService = container.resolve<IDefaultTaskSettingsService>();

    // Check setting
    bool skipQuickAdd = TaskConstants.defaultSkipQuickAdd;
    try {
      final setting = await mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.taskSkipQuickAdd),
      );
      if (setting != null) {
        skipQuickAdd = setting.getValue<bool>();
      }
    } catch (e, stackTrace) {
      DomainLogger.error(
        'Failed to load skip quick add setting, using default',
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (!context.mounted) return;

    if (skipQuickAdd) {
      // Immediate creation
      await _createTaskImmediately(
        context: context,
        mediator: mediator,
        translationService: translationService,
        tasksService: tasksService,
        defaultSettingsService: defaultSettingsService,
        initialTagIds: initialTagIds,
        initialPlannedDate: initialPlannedDate,
        initialDeadlineDate: initialDeadlineDate,
        initialPriority: initialPriority,
        initialEstimatedTime: initialEstimatedTime,
        initialTitle: initialTitle,
        initialCompleted: initialCompleted,
        initialParentTaskId: initialParentTaskId,
        onTaskCreated: onTaskCreated,
      );
    } else {
      // Show dialog
      await QuickAddTaskDialog.show(
        context: context,
        initialTagIds: initialTagIds,
        initialPlannedDate: initialPlannedDate,
        initialDeadlineDate: initialDeadlineDate,
        initialPriority: initialPriority,
        initialEstimatedTime: initialEstimatedTime,
        initialTitle: initialTitle,
        initialCompleted: initialCompleted,
        initialParentTaskId: initialParentTaskId,
        onTaskCreated: onTaskCreated,
      );
    }
  }

  static Future<void> _createTaskImmediately({
    required BuildContext context,
    required Mediator mediator,
    required ITranslationService translationService,
    required TasksService tasksService,
    required IDefaultTaskSettingsService defaultSettingsService,
    List<String>? initialTagIds,
    DateTime? initialPlannedDate,
    DateTime? initialDeadlineDate,
    EisenhowerPriority? initialPriority,
    int? initialEstimatedTime,
    String? initialTitle,
    bool? initialCompleted,
    String? initialParentTaskId,
    Function(String taskId, TaskData taskData)? onTaskCreated,
  }) async {
    // Load defaults if not provided
    final estimatedTime = initialEstimatedTime ?? await defaultSettingsService.getDefaultEstimatedTime();

    final (reminderTime, customOffset) = await defaultSettingsService.getDefaultPlannedDateReminder();
    ReminderTime plannedDateReminderTime = reminderTime;
    int? plannedDateReminderCustomOffset = customOffset;

    // Only apply default reminder if scheduled date is set (manually or initially)
    // If no initialPlannedDate is provided, the reminder setting is irrelevant for creation
    if (initialPlannedDate == null) {
      plannedDateReminderTime = ReminderTime.none;
      plannedDateReminderCustomOffset = null;
    }

    if (!context.mounted) return;

    await AsyncErrorHandler.execute<SaveTaskCommandResponse>(
      context: context,
      errorMessage: translationService.translate(TaskTranslationKeys.saveTaskError),
      operation: () async {
        final finalTitle = initialTitle ?? translationService.translate(TaskTranslationKeys.newTaskDefaultTitle);

        final command = SaveTaskCommand(
          title: finalTitle,
          description: '',
          tagIdsToAdd: initialTagIds,
          priority: initialPriority,
          estimatedTime: estimatedTime,
          plannedDate: initialPlannedDate,
          deadlineDate: initialDeadlineDate,
          plannedDateReminderTime: plannedDateReminderTime,
          plannedDateReminderCustomOffset: plannedDateReminderCustomOffset,
          completedAt: (initialCompleted ?? false) ? DateTime.now().toUtc() : null,
          parentTaskId: initialParentTaskId,
        );
        return await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);
      },
      onSuccess: (response) => _handleTaskCreationSuccess(
        context: context,
        response: response,
        initialTitle: initialTitle,
        initialPriority: initialPriority,
        estimatedTime: estimatedTime,
        initialPlannedDate: initialPlannedDate,
        initialDeadlineDate: initialDeadlineDate,
        initialCompleted: initialCompleted,
        initialParentTaskId: initialParentTaskId,
        initialTagIds: initialTagIds,
        translationService: translationService,
        tasksService: tasksService,
        onTaskCreated: onTaskCreated,
      ),
    );
  }

  static void _handleTaskCreationSuccess({
    required BuildContext context,
    required SaveTaskCommandResponse response,
    required String? initialTitle,
    required EisenhowerPriority? initialPriority,
    required int? estimatedTime,
    required DateTime? initialPlannedDate,
    required DateTime? initialDeadlineDate,
    required bool? initialCompleted,
    required String? initialParentTaskId,
    required List<String>? initialTagIds,
    required ITranslationService translationService,
    required TasksService tasksService,
    required Function(String taskId, TaskData taskData)? onTaskCreated,
  }) {
    try {
      _notifyTaskCreated(tasksService, response.id);
      _showSuccessMessage(context, translationService, initialTitle);
      _invokeOnTaskCreatedCallback(
        onTaskCreated,
        response.id,
        initialTitle,
        initialPriority,
        estimatedTime,
        initialPlannedDate,
        initialDeadlineDate,
        initialCompleted,
        initialParentTaskId,
        initialTagIds,
      );
      _navigateToTaskDetails(context, response.id);
    } catch (e, stackTrace) {
      DomainLogger.error(
        'Error handling task creation success',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static void _notifyTaskCreated(TasksService tasksService, String taskId) {
    try {
      tasksService.notifyTaskCreated(taskId);
    } catch (e, stackTrace) {
      DomainLogger.error(
        'Failed to notify task created',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static void _showSuccessMessage(
    BuildContext context,
    ITranslationService translationService,
    String? initialTitle,
  ) {
    if (!context.mounted) return;

    try {
      if (initialTitle != null && initialTitle.isNotEmpty) {
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: translationService.translate(
            TaskTranslationKeys.taskAddedSuccessfully,
            namedArgs: {'title': initialTitle},
          ),
        );
      }
    } catch (e, stackTrace) {
      DomainLogger.error(
        'Failed to show success message',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static void _invokeOnTaskCreatedCallback(
    Function(String taskId, TaskData taskData)? onTaskCreated,
    String taskId,
    String? initialTitle,
    EisenhowerPriority? initialPriority,
    int? estimatedTime,
    DateTime? initialPlannedDate,
    DateTime? initialDeadlineDate,
    bool? initialCompleted,
    String? initialParentTaskId,
    List<String>? initialTagIds,
  ) {
    if (onTaskCreated == null) return;

    try {
      final taskData = TaskData(
        title: initialTitle ?? '',
        priority: initialPriority,
        estimatedTime: estimatedTime,
        plannedDate: initialPlannedDate?.toUtc(),
        deadlineDate: initialDeadlineDate?.toUtc(),
        tags: [],
        tagIds: initialTagIds ?? [],
        isCompleted: initialCompleted ?? false,
        parentTaskId: initialParentTaskId,
        createdDate: DateTime.now().toUtc(),
      );
      onTaskCreated(taskId, taskData);
    } catch (e, stackTrace) {
      DomainLogger.error(
        'Failed to invoke onTaskCreated callback',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static void _navigateToTaskDetails(BuildContext context, String taskId) {
    if (!context.mounted) return;

    try {
      ResponsiveDialogHelper.showResponsiveDialog(
        context: context,
        child: TaskDetailsPage(
          taskId: taskId,
          hideSidebar: true,
        ),
        size: DialogSize.max,
      );
    } catch (e, stackTrace) {
      DomainLogger.error(
        'Failed to navigate to task details',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
