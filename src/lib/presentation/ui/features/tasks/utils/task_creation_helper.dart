import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/components/quick_add_task_dialog/quick_add_task_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/tasks/services/abstraction/i_default_task_settings_service.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_draft.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:acore/acore.dart';

class TaskCreationHelper {
  static Future<void> createTask({
    required BuildContext context,
    TaskDraft draft = const TaskDraft(),
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
      Logger.error(
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
        draft: draft,
        onTaskCreated: onTaskCreated,
      );
    } else {
      // Show dialog
      await QuickAddTaskDialog.show(
        context: context,
        initialTagIds: draft.tagIds,
        initialPlannedDate: draft.plannedDate,
        initialDeadlineDate: draft.deadlineDate,
        initialPriority: draft.priority,
        initialEstimatedTime: draft.estimatedTime,
        initialTitle: draft.title,
        initialCompleted: draft.completed,
        initialParentTaskId: draft.parentTaskId,
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
    required TaskDraft draft,
    Function(String taskId, TaskData taskData)? onTaskCreated,
  }) async {
    // Load defaults if not provided
    final estimatedTime = draft.estimatedTime ?? await defaultSettingsService.getDefaultEstimatedTime();

    final (reminderTime, customOffset) = await defaultSettingsService.getDefaultPlannedDateReminder();
    ReminderTime plannedDateReminderTime = reminderTime;
    int? plannedDateReminderCustomOffset = customOffset;

    // Only apply default reminder if scheduled date is set (manually or initially)
    // If no draft.plannedDate is provided, the reminder setting is irrelevant for creation
    if (draft.plannedDate == null) {
      plannedDateReminderTime = ReminderTime.none;
      plannedDateReminderCustomOffset = null;
    }

    if (!context.mounted) return;

    await AsyncErrorHandler.execute<SaveTaskCommandResponse>(
      context: context,
      errorMessage: translationService.translate(TaskTranslationKeys.saveTaskError),
      operation: () async {
        final finalTitle = draft.title ?? translationService.translate(TaskTranslationKeys.newTaskDefaultTitle);

        final command = SaveTaskCommand(
          title: finalTitle,
          description: '',
          tagIdsToAdd: draft.tagIds,
          priority: draft.priority,
          estimatedTime: estimatedTime,
          plannedDate: draft.plannedDate,
          deadlineDate: draft.deadlineDate,
          plannedDateReminderTime: plannedDateReminderTime,
          plannedDateReminderCustomOffset: plannedDateReminderCustomOffset,
          completedAt: (draft.completed ?? false) ? DateTime.now().toUtc() : null,
          parentTaskId: draft.parentTaskId,
        );
        return await mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);
      },
      onSuccess: (response) => _handleTaskCreationSuccess(
        context: context,
        response: response,
        draft: draft,
        estimatedTime: estimatedTime,
        translationService: translationService,
        tasksService: tasksService,
        onTaskCreated: onTaskCreated,
      ),
    );
  }

  static void _handleTaskCreationSuccess({
    required BuildContext context,
    required SaveTaskCommandResponse response,
    required TaskDraft draft,
    required int? estimatedTime,
    required ITranslationService translationService,
    required TasksService tasksService,
    required Function(String taskId, TaskData taskData)? onTaskCreated,
  }) {
    try {
      _notifyTaskCreated(tasksService, response.id);
      _showSuccessMessage(context, translationService, draft.title);
      _invokeOnTaskCreatedCallback(
        onTaskCreated,
        response.id,
        draft: draft,
        estimatedTime: estimatedTime,
      );
      _navigateToTaskDetails(context, response.id);
    } catch (e, stackTrace) {
      Logger.error(
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
      Logger.error(
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
      Logger.error(
        'Failed to show success message',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static void _invokeOnTaskCreatedCallback(
    Function(String taskId, TaskData taskData)? onTaskCreated,
    String taskId, {
    required TaskDraft draft,
    required int? estimatedTime,
  }) {
    if (onTaskCreated == null) return;

    try {
      final taskData = TaskData(
        title: draft.title ?? '',
        priority: draft.priority,
        estimatedTime: estimatedTime,
        plannedDate: draft.plannedDate?.toUtc(),
        deadlineDate: draft.deadlineDate?.toUtc(),
        tags: [],
        tagIds: draft.tagIds ?? [],
        isCompleted: draft.completed ?? false,
        parentTaskId: draft.parentTaskId,
        createdDate: DateTime.now().toUtc(),
      );
      onTaskCreated(taskId, taskData);
    } catch (e, stackTrace) {
      Logger.error(
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
      Logger.error(
        'Failed to navigate to task details',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
