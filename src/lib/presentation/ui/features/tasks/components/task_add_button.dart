import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_creation_helper.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Model to hold parent task data
class _ParentTaskData {
  final List<String> tagIds;
  final EisenhowerPriority? priority;

  _ParentTaskData({required this.tagIds, this.priority});
}

class TaskAddButton extends StatefulWidget {
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final Function(String taskId, TaskData taskData)? onTaskCreated;
  final List<String>? initialTagIds;
  final DateTime? initialPlannedDate;
  final DateTime? initialDeadlineDate;
  final EisenhowerPriority? initialPriority;
  final int? initialEstimatedTime;
  final String? initialParentTaskId;
  final String? initialTitle;
  final bool? initialCompleted;

  const TaskAddButton({
    super.key,
    this.buttonColor,
    this.buttonBackgroundColor,
    this.onTaskCreated,
    this.initialTagIds,
    this.initialPlannedDate,
    this.initialDeadlineDate,
    this.initialPriority,
    this.initialEstimatedTime,
    this.initialParentTaskId,
    this.initialTitle,
    this.initialCompleted,
  });

  @override
  State<TaskAddButton> createState() => _TaskAddButtonState();
}

class _TaskAddButtonState extends State<TaskAddButton> {
  final _translationService = container.resolve<ITranslationService>();
  final _mediator = container.resolve<Mediator>();
  bool isLoading = false;

  /// Loads parent task data (tags and priority) if initialParentTaskId is provided
  Future<_ParentTaskData> _getParentTaskData() async {
    if (widget.initialParentTaskId == null) {
      return _ParentTaskData(
        tagIds: widget.initialTagIds ?? [],
        priority: widget.initialPriority,
      );
    }

    try {
      // Get parent task details
      final taskResponse = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(
        GetTaskQuery(id: widget.initialParentTaskId!),
      );

      // Get parent task tags
      List<String> parentTagIds = [];
      int pageIndex = 0;
      const int pageSize = 50;

      // Load all parent tags with pagination
      while (true) {
        final tagsResponse = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(
          GetListTaskTagsQuery(taskId: widget.initialParentTaskId!, pageIndex: pageIndex, pageSize: pageSize),
        );

        // Add current page tags to the list
        parentTagIds.addAll(tagsResponse.items.map((tagItem) => tagItem.tagId));

        // If there are no more pages, break the loop
        if (!tagsResponse.hasNext) {
          break;
        }

        pageIndex++;
      }

      // Merge parent tags with initial tag IDs (unique combination)
      List<String> allTagIds = [...parentTagIds];
      if (widget.initialTagIds != null) {
        for (String tagId in widget.initialTagIds!) {
          if (!allTagIds.contains(tagId)) {
            allTagIds.add(tagId);
          }
        }
      }

      return _ParentTaskData(
        tagIds: allTagIds,
        priority: widget.initialPriority ??
            taskResponse.priority, // Use initial priority if provided, otherwise parent's priority
      );
    } catch (e) {
      Logger.error('Error loading parent task data: $e');
      return _ParentTaskData(
        tagIds: widget.initialTagIds ?? [],
        priority: widget.initialPriority,
      );
    }
  }

  Future<void> _createTask(BuildContext context) async {
    // Get parent task data (tags and priority) if available
    final parentData = await _getParentTaskData();

    if (context.mounted) {
      await TaskCreationHelper.createTask(
        context: context,
        initialTagIds: parentData.tagIds.isNotEmpty ? parentData.tagIds : null,
        initialPriority: parentData.priority,
        initialPlannedDate: widget.initialPlannedDate,
        initialDeadlineDate: widget.initialDeadlineDate,
        initialEstimatedTime: widget.initialEstimatedTime,
        initialTitle: widget.initialTitle,
        initialCompleted: widget.initialCompleted,
        initialParentTaskId: widget.initialParentTaskId,
        onTaskCreated: (taskId, taskData) {
          if (widget.onTaskCreated != null) {
            widget.onTaskCreated!(taskId, taskData);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _createTask(context),
      icon: Icon(SharedUiConstants.addIcon),
      color: widget.buttonColor,
      tooltip: _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
      style: ButtonStyle(
        backgroundColor:
            widget.buttonBackgroundColor != null ? WidgetStatePropertyAll<Color>(widget.buttonBackgroundColor!) : null,
      ),
    );
  }
}
