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
    int? estimatedTime = initialEstimatedTime;
    if (estimatedTime == null) {
      try {
        final setting = await mediator.send<GetSettingQuery, Setting?>(
          GetSettingQuery(key: SettingKeys.taskDefaultEstimatedTime),
        );
        if (setting != null) {
          final value = setting.getValue<int?>();
          if (value != null && value > 0) estimatedTime = value;
        }
      } catch (e, stackTrace) {
        Logger.error(
          'Failed to load default estimated time setting',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    ReminderTime plannedDateReminderTime = ReminderTime.none;
    int? plannedDateReminderCustomOffset;

    try {
      final setting = await mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.taskDefaultPlannedDateReminder),
      );
      if (setting != null) {
        final value = setting.getValue<String>();
        plannedDateReminderTime = ReminderTimeExtension.fromString(value);

        if (plannedDateReminderTime == ReminderTime.custom) {
          final offsetSetting = await mediator.send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.taskDefaultPlannedDateReminderCustomOffset),
          );
          if (offsetSetting != null) {
            plannedDateReminderCustomOffset = offsetSetting.getValue<int?>();
          }
        }
      } else {
        plannedDateReminderTime = TaskConstants.defaultReminderTime;
      }
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to load default planned date reminder setting',
        error: e,
        stackTrace: stackTrace,
      );
      plannedDateReminderTime = TaskConstants.defaultReminderTime;
    }

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
      onSuccess: (response) {
        tasksService.notifyTaskCreated(response.id);

        if (initialTitle != null && initialTitle.isNotEmpty) {
          OverlayNotificationHelper.showSuccess(
            context: context,
            message: translationService.translate(
              TaskTranslationKeys.taskAddedSuccessfully,
              namedArgs: {'title': initialTitle},
            ),
          );
        }

        if (onTaskCreated != null) {
          final taskData = TaskData(
            title: initialTitle ?? '',
            priority: initialPriority,
            estimatedTime: estimatedTime,
            plannedDate: initialPlannedDate?.toUtc(),
            deadlineDate: initialDeadlineDate?.toUtc(),
            tags: [], // Tags handling would require fetching, skipping for now as UI usually refreshes
            isCompleted: initialCompleted ?? false,
            parentTaskId: initialParentTaskId,
            createdDate: DateTime.now().toUtc(),
          );
          onTaskCreated(response.id, taskData);
        }

        if (context.mounted) {
          ResponsiveDialogHelper.showResponsiveDialog(
            context: context,
            child: TaskDetailsPage(
              taskId: response.id,
              hideSidebar: true,
            ),
            size: DialogSize.max,
          );
        }
      },
    );
  }
}
