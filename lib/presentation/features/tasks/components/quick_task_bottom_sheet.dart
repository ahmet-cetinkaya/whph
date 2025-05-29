import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tasks/models/task_data.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';

class QuickTaskBottomSheet extends StatefulWidget {
  final List<String>? initialTagIds;
  final DateTime? initialPlannedDate;
  final DateTime? initialDeadlineDate;
  final EisenhowerPriority? initialPriority;
  final int? initialEstimatedTime;
  final String? initialTitle;
  final bool? initialCompleted;
  final Function(String taskId, TaskData taskData)? onTaskCreated;
  final String? initialParentTaskId;

  const QuickTaskBottomSheet({
    super.key,
    this.initialTagIds,
    this.initialPlannedDate,
    this.initialDeadlineDate,
    this.initialPriority,
    this.initialEstimatedTime,
    this.initialTitle,
    this.initialCompleted,
    this.onTaskCreated,
    this.initialParentTaskId,
  });

  @override
  State<QuickTaskBottomSheet> createState() => _QuickTaskBottomSheetState();
}

class _QuickTaskBottomSheetState extends State<QuickTaskBottomSheet> {
  final _titleController = TextEditingController();
  final _mediator = container.resolve<Mediator>();
  final _tasksService = container.resolve<TasksService>();
  final _translationService = container.resolve<ITranslationService>();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  void _closeDialog() {
    Navigator.pop(context);
  }

  // Quick action state variables
  EisenhowerPriority? _selectedPriority;
  int? _estimatedTime;
  DateTime? _plannedDate;
  DateTime? _deadlineDate;
  List<DropdownOption<String>> _selectedTags = [];

  // Lock state variables
  bool _lockTags = false;
  bool _lockPriority = false;
  bool _lockEstimatedTime = false;
  bool _lockPlannedDate = false;
  bool _lockDeadlineDate = false;

  @override
  void initState() {
    super.initState();
    _plannedDate = widget.initialPlannedDate;
    _deadlineDate = widget.initialDeadlineDate;
    _selectedPriority = widget.initialPriority;
    _estimatedTime = widget.initialEstimatedTime;
    _selectedTags = widget.initialTagIds?.map((id) => DropdownOption(label: '', value: id)).toList() ?? [];
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      } else {
        _titleController.clear();
      }

      // Only reset values that are not locked
      if (!_lockPriority) {
        _selectedPriority = widget.initialPriority;
      }
      if (!_lockEstimatedTime) {
        _estimatedTime = widget.initialEstimatedTime;
      }
      if (!_lockPlannedDate) {
        _plannedDate = widget.initialPlannedDate;
      }
      if (!_lockDeadlineDate) {
        _deadlineDate = widget.initialDeadlineDate;
      }
      if (!_lockTags) {
        _selectedTags = widget.initialTagIds?.map((id) => DropdownOption(label: '', value: id)).toList() ?? [];
      }
    });
  }

  Future<void> _createTask() async {
    if (_isLoading || _titleController.text.isEmpty) return;

    setState(() => _isLoading = true);

    await AsyncErrorHandler.execute<SaveTaskCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.saveTaskError),
      operation: () async {
        final command = SaveTaskCommand(
          title: _titleController.text,
          description: "",
          tagIdsToAdd: _selectedTags.map((t) => t.value).toList(),
          priority: _selectedPriority,
          estimatedTime: _estimatedTime,
          plannedDate: _plannedDate,
          deadlineDate: _deadlineDate,
          isCompleted: widget.initialCompleted ?? false,
          parentTaskId: widget.initialParentTaskId,
        );
        return await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);
      },
      onSuccess: (response) {
        // Notify that a task was created with the task ID (using non-nullable parameter)
        _tasksService.notifyTaskCreated(response.id);

        if (widget.onTaskCreated != null) {
          // Create a TaskData object with all the task information
          final taskData = TaskData(
            title: _titleController.text,
            priority: _selectedPriority,
            estimatedTime: _estimatedTime,
            plannedDate: _plannedDate,
            deadlineDate: _deadlineDate,
            tags: _selectedTags
                .map((t) => TaskDataTag(
                      id: t.value,
                      name: t.label,
                    ))
                .toList(),
            isCompleted: false,
            parentTaskId: widget.initialParentTaskId,
            order: 0.0, // Default order
            createdDate: DateTimeHelper.toUtcDateTime(DateTime.now()),
          );

          widget.onTaskCreated!(response.id, taskData);
        }

        if (mounted) {
          setState(() {
            _clearAll();
          });
          _focusNode.requestFocus();
        }
      },
      finallyAction: () {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _selectDate(bool isDeadline) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isDeadline) {
          _deadlineDate = picked;
        } else {
          _plannedDate = picked;
        }
      });
    }
  }

  String? _getFormattedDate(DateTime? date) {
    if (date == null) return null;
    return DateTimeHelper.formatDate(date);
  }

  void _togglePriority() {
    setState(() {
      switch (_selectedPriority) {
        case null:
          _selectedPriority = EisenhowerPriority.urgentImportant;
          break;
        case EisenhowerPriority.urgentImportant:
          _selectedPriority = EisenhowerPriority.notUrgentImportant;
          break;
        case EisenhowerPriority.notUrgentImportant:
          _selectedPriority = EisenhowerPriority.urgentNotImportant;
          break;
        case EisenhowerPriority.urgentNotImportant:
          _selectedPriority = EisenhowerPriority.notUrgentNotImportant;
          break;
        case EisenhowerPriority.notUrgentNotImportant:
          _selectedPriority = null;
          break;
      }
    });
  }

  void _toggleEstimatedTime() {
    setState(() {
      final currentIndex = TaskUiConstants.defaultEstimatedTimeOptions.indexOf(_estimatedTime ?? 0);
      if (currentIndex == -1 || currentIndex == TaskUiConstants.defaultEstimatedTimeOptions.length - 1) {
        _estimatedTime = TaskUiConstants.defaultEstimatedTimeOptions.first;
      } else {
        _estimatedTime = TaskUiConstants.defaultEstimatedTimeOptions[currentIndex + 1];
      }
    });
  }

  Future<void> _showLockSettingsDialog() async {
    await ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.small,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_translationService.translate(TaskTranslationKeys.quickTaskLockSettings)),

                // Description
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _translationService.translate(TaskTranslationKeys.quickTaskLockDescription),
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.secondaryTextColor),
                  ),
                ),

                // Lock options
                CheckboxListTile(
                  title: Text(_translationService.translate(TaskTranslationKeys.tagsLabel)),
                  value: _lockTags,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      _lockTags = value ?? false;
                    });
                    setState(() {
                      _lockTags = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text(_translationService.translate(TaskTranslationKeys.priorityLabel)),
                  value: _lockPriority,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      _lockPriority = value ?? false;
                    });
                    setState(() {
                      _lockPriority = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text(_translationService.translate(TaskTranslationKeys.estimatedTimeLabel)),
                  value: _lockEstimatedTime,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      _lockEstimatedTime = value ?? false;
                    });
                    setState(() {
                      _lockEstimatedTime = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text(_translationService.translate(TaskTranslationKeys.plannedDateLabel)),
                  value: _lockPlannedDate,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      _lockPlannedDate = value ?? false;
                    });
                    setState(() {
                      _lockPlannedDate = value ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text(_translationService.translate(TaskTranslationKeys.deadlineDateLabel)),
                  value: _lockDeadlineDate,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      _lockDeadlineDate = value ?? false;
                    });
                    setState(() {
                      _lockDeadlineDate = value ?? false;
                    });
                  },
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getEstimatedTimeTooltip() {
    if (_estimatedTime == null) {
      return _translationService.translate(TaskTranslationKeys.quickTaskEstimatedTimeNotSet);
    }
    return _translationService.translate(
      TaskTranslationKeys.quickTaskEstimatedTime,
      namedArgs: {'time': SharedUiConstants.formatMinutes(_estimatedTime)},
    );
  }

  String _getDateTooltip(bool isDeadline) {
    final date = isDeadline ? _deadlineDate : _plannedDate;
    final formattedDate = _getFormattedDate(date);

    if (date == null) {
      return _translationService.translate(
        isDeadline ? TaskTranslationKeys.quickTaskDeadlineDateNotSet : TaskTranslationKeys.quickTaskPlannedDateNotSet,
      );
    }

    return _translationService.translate(
      isDeadline ? TaskTranslationKeys.quickTaskDeadlineDate : TaskTranslationKeys.quickTaskPlannedDate,
      namedArgs: {'date': formattedDate.toString()},
    );
  }

  Widget _buildQuickActionButtons() {
    final iconSize = AppTheme.iconSizeMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Clear all button
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.secondaryTextColor),
          onPressed: _clearAll,
          tooltip: _translationService.translate(TaskTranslationKeys.quickTaskClearAll),
          iconSize: iconSize,
        ),

        // Lock settings button
        IconButton(
          icon: const Icon(Icons.lock_outline, color: AppTheme.secondaryTextColor),
          onPressed: _showLockSettingsDialog,
          tooltip: _translationService.translate(TaskTranslationKeys.quickTaskLockSettings),
          iconSize: iconSize,
        ),

        // Tag select dropdown with lock indicator
        _buildActionButtonWithLock(
          child: TagSelectDropdown(
            initialSelectedTags: _selectedTags,
            isMultiSelect: true,
            onTagsSelected: (tags, _) => setState(() => _selectedTags = tags),
            iconSize: iconSize,
            color: _selectedTags.isEmpty ? Colors.white : TaskUiConstants.tagColor,
          ),
          isLocked: _lockTags,
        ),

        // Priority button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: Icon(
              _selectedPriority == null ? TaskUiConstants.priorityOutlinedIcon : TaskUiConstants.priorityIcon,
              color: TaskUiConstants.getPriorityColor(_selectedPriority),
            ),
            onPressed: _togglePriority,
            tooltip: _translationService.translate(TaskTranslationKeys.priorityNone),
            iconSize: iconSize,
          ),
          isLocked: _lockPriority,
        ),

        // Estimated time button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: _estimatedTime == null
                ? Icon(TaskUiConstants.estimatedTimeOutlinedIcon)
                : Text(
                    SharedUiConstants.formatMinutes(_estimatedTime!),
                    style: AppTheme.bodyMedium.copyWith(
                      color: TaskUiConstants.estimatedTimeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            onPressed: _toggleEstimatedTime,
            tooltip: _getEstimatedTimeTooltip(),
            iconSize: iconSize,
          ),
          isLocked: _lockEstimatedTime,
        ),

        // Planned date button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: Icon(
              _plannedDate == null ? TaskUiConstants.plannedDateOutlinedIcon : TaskUiConstants.plannedDateIcon,
              color: _plannedDate == null ? null : TaskUiConstants.plannedDateColor,
            ),
            onPressed: () => _selectDate(false),
            tooltip: _getDateTooltip(false),
            iconSize: iconSize,
          ),
          isLocked: _lockPlannedDate,
        ),

        // Deadline date button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: Icon(
              _deadlineDate == null ? TaskUiConstants.deadlineDateOutlinedIcon : TaskUiConstants.deadlineDateIcon,
              color: _deadlineDate == null ? null : TaskUiConstants.deadlineDateColor,
            ),
            onPressed: () => _selectDate(true),
            tooltip: _getDateTooltip(true),
            iconSize: iconSize,
          ),
          isLocked: _lockDeadlineDate,
        ),
      ],
    );
  }

  Widget _buildActionButtonWithLock({
    required Widget child,
    required bool isLocked,
  }) {
    return Stack(
      children: [
        child,
        if (isLocked)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.lock,
                size: 12,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenMedium);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        // Use different border radius based on platform
        borderRadius: isDesktop
            ? BorderRadius.circular(AppTheme.containerBorderRadius)
            : const BorderRadius.vertical(top: Radius.circular(AppTheme.sizeLarge)),
      ),
      // Use mainAxisSize.min to make the container fit its content
      child: Padding(
        // Use same padding for both platforms
        padding: EdgeInsets.fromLTRB(AppTheme.sizeLarge, AppTheme.sizeSmall, AppTheme.sizeLarge, AppTheme.sizeMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle for mobile, title for desktop
            if (isDesktop)
              Padding(
                padding: EdgeInsets.only(bottom: AppTheme.sizeLarge),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
                      style: AppTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _closeDialog,
                    ),
                  ],
                ),
              ),

            // Title input
            TextField(
              controller: _titleController,
              focusNode: _focusNode,
              autofocus: true,
              style: AppTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: _translationService.translate(TaskTranslationKeys.quickTaskTitleHint),
                // Use same content padding for both platforms
                contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
                // Send button in the text field
                suffixIcon: isDesktop
                    ? IconButton(
                        icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.send, color: AppTheme.primaryColor),
                        onPressed: _createTask,
                        tooltip: _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
                      )
                    : SizedBox(
                        width: AppTheme.iconSizeLarge - 4.0,
                        height: AppTheme.iconSizeLarge - 4.0,
                        child: IconButton(
                          icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.send, color: AppTheme.primaryColor),
                          onPressed: _createTask,
                          iconSize: AppTheme.iconSizeMedium,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: AppTheme.iconSizeLarge - 4.0,
                            minHeight: AppTheme.iconSizeLarge - 4.0,
                          ),
                        ),
                      ),
              ),
              onSubmitted: (_) => _createTask(),
            ),

            // Quick action buttons for all screen sizes
            Padding(
              padding: EdgeInsets.only(top: AppTheme.sizeSmall),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildQuickActionButtons(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
