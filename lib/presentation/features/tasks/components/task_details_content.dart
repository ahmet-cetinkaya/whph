import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:markdown_editor_plus/widgets/markdown_auto_preview.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/acore/components/date_time_picker_field.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/priority_select_field.dart';
import 'package:whph/presentation/features/tasks/components/task_complete_button.dart';
import 'package:whph/presentation/shared/components/detail_table.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/components/optional_field_chip.dart';

class TaskDetailsContent extends StatefulWidget {
  final String taskId;
  final VoidCallback? onTaskUpdated;
  final Function(String)? onTitleUpdated;
  final Function(bool)? onCompletedChanged;

  const TaskDetailsContent({
    super.key,
    required this.taskId,
    this.onTaskUpdated,
    this.onTitleUpdated,
    this.onCompletedChanged,
  });

  @override
  State<TaskDetailsContent> createState() => TaskDetailsContentState();
}

class TaskDetailsContentState extends State<TaskDetailsContent> {
  final _mediator = container.resolve<Mediator>();
  final _tasksService = container.resolve<TasksService>();
  final _translationService = container.resolve<ITranslationService>();

  GetTaskQueryResponse? _task;
  GetListTaskTagsQueryResponse? _taskTags;
  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _deadlineDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _titleController = TextEditingController();
  Timer? _debounce;

  // Set to track which optional fields are visible
  final Set<String> _visibleOptionalFields = {};

  // Define optional field keys
  static const String keyTags = 'tags';
  static const String keyPriority = 'priority';
  static const String keyEstimatedTime = 'estimatedTime';
  static const String keyPlannedDate = 'plannedDate';
  static const String keyDeadlineDate = 'deadlineDate';
  static const String keyDescription = 'description';

  late List<DropdownOption<EisenhowerPriority?>> _priorityOptions;

  @override
  void initState() {
    super.initState();
    refresh();
    _tasksService.onTaskUpdated.addListener(_getTask);
  }

  @override
  void didUpdateWidget(TaskDetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      refresh();
    }
  }

  // Process field content and update UI after task data is loaded
  void _processFieldVisibility() {
    if (_task == null) return;

    setState(() {
      // Make fields with content automatically visible
      if (_hasFieldContent(keyTags)) _visibleOptionalFields.add(keyTags);
      if (_hasFieldContent(keyPriority)) _visibleOptionalFields.add(keyPriority);
      if (_hasFieldContent(keyEstimatedTime)) _visibleOptionalFields.add(keyEstimatedTime);
      if (_hasFieldContent(keyPlannedDate)) _visibleOptionalFields.add(keyPlannedDate);
      if (_hasFieldContent(keyDeadlineDate)) _visibleOptionalFields.add(keyDeadlineDate);
      if (_hasFieldContent(keyDescription)) _visibleOptionalFields.add(keyDescription);
    });
  }

  // Toggles visibility of an optional field
  void _toggleOptionalField(String fieldKey) {
    setState(() {
      if (_visibleOptionalFields.contains(fieldKey)) {
        _visibleOptionalFields.remove(fieldKey);
      } else {
        _visibleOptionalFields.add(fieldKey);
      }
    });
  }

  // Checks if field should be shown in the content
  bool _isFieldVisible(String fieldKey) {
    return _visibleOptionalFields.contains(fieldKey);
  }

  // Check if the field should be displayed in the chips section
  bool _shouldShowAsChip(String fieldKey) {
    return !_visibleOptionalFields.contains(fieldKey);
  }

  // Method to determine if a field has content
  bool _hasFieldContent(String fieldKey) {
    if (_task == null) return false;

    switch (fieldKey) {
      case keyTags:
        return _taskTags != null && _taskTags!.items.isNotEmpty;
      case keyPriority:
        return _task!.priority != null;
      case keyEstimatedTime:
        return _task!.estimatedTime != null && _task!.estimatedTime! > 0;
      case keyPlannedDate:
        return _task!.plannedDate != null;
      case keyDeadlineDate:
        return _task!.deadlineDate != null;
      case keyDescription:
        return _task!.description != null && _task!.description!.trim().isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> refresh() async {
    await _getInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _debounce?.cancel();
    _tasksService.onTaskUpdated.removeListener(_getTask);
    super.dispose();
  }

  Future<void> _getInitialData() async {
    await Future.wait([_getTask(), _getTaskTags()]);
  }

  Future<void> _getTask() async {
    await AsyncErrorHandler.execute<GetTaskQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.getTaskError),
      operation: () async {
        final query = GetTaskQuery(id: widget.taskId);
        return await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
      },
      onSuccess: (response) {
        if (!mounted) return;

        // Store current selections before updating
        final titleSelection = _titleController.selection;
        final descriptionSelection = _descriptionController.selection;
        final plannedDateSelection = _plannedDateController.selection;
        final deadlineDateSelection = _deadlineDateController.selection;

        setState(() {
          _task = response;

          // Only update title if it's different
          if (_titleController.text != response.title) {
            _titleController.text = response.title;
            widget.onTitleUpdated?.call(response.title);
            // Don't restore selection for title if it changed
          } else if (titleSelection.isValid) {
            // Restore selection if title didn't change
            _titleController.selection = titleSelection;
          }

          widget.onCompletedChanged?.call(response.isCompleted);
          _priorityOptions = [
            DropdownOption(label: _translationService.translate(TaskTranslationKeys.priorityNone), value: null),
            DropdownOption(
                label: _translationService.translate(TaskTranslationKeys.priorityUrgentImportant),
                value: EisenhowerPriority.urgentImportant),
            DropdownOption(
                label: _translationService.translate(TaskTranslationKeys.priorityNotUrgentImportant),
                value: EisenhowerPriority.notUrgentImportant),
            DropdownOption(
                label: _translationService.translate(TaskTranslationKeys.priorityUrgentNotImportant),
                value: EisenhowerPriority.urgentNotImportant),
            DropdownOption(
                label: _translationService.translate(TaskTranslationKeys.priorityNotUrgentNotImportant),
                value: EisenhowerPriority.notUrgentNotImportant),
          ];

          // Only update planned date if it's different
          final plannedDateText =
              _task!.plannedDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_task!.plannedDate!) : '';
          if (_plannedDateController.text != plannedDateText) {
            _plannedDateController.text = plannedDateText;
            // Don't restore selection if text changed
          } else if (plannedDateSelection.isValid) {
            // Restore selection if text didn't change
            _plannedDateController.selection = plannedDateSelection;
          }

          // Only update deadline date if it's different
          final deadlineDateText =
              _task!.deadlineDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_task!.deadlineDate!) : '';
          if (_deadlineDateController.text != deadlineDateText) {
            _deadlineDateController.text = deadlineDateText;
            // Don't restore selection if text changed
          } else if (deadlineDateSelection.isValid) {
            // Restore selection if text didn't change
            _deadlineDateController.selection = deadlineDateSelection;
          }

          // Only update description if it's different
          final descriptionText = _task!.description ?? '';
          if (_descriptionController.text != descriptionText) {
            _descriptionController.text = descriptionText;
            // Don't restore selection if text changed
          } else if (descriptionSelection.isValid) {
            // Restore selection if text didn't change
            _descriptionController.selection = descriptionSelection;
          }
        });
        _processFieldVisibility();
      },
    );
  }

  Future<void> _getTaskTags() async {
    if (!mounted) return;
    setState(() => _taskTags = null);

    int pageIndex = 0;
    const int pageSize = 50;

    while (true) {
      final query = GetListTaskTagsQuery(taskId: widget.taskId, pageIndex: pageIndex, pageSize: pageSize);

      final result = await AsyncErrorHandler.execute<GetListTaskTagsQueryResponse>(
        context: context,
        errorMessage: _translationService.translate(TaskTranslationKeys.getTagsError),
        operation: () => _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(query),
        onSuccess: (response) {
          if (!mounted) return;
          setState(() {
            if (_taskTags == null) {
              _taskTags = response;
            } else {
              _taskTags!.items.addAll(response.items);
            }
          });
          _processFieldVisibility();
        },
      );

      if (result == null || result.items.length < pageSize) break;
      pageIndex++;
    }
  }

  Future<void> _updateTask() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;

      final saveCommand = SaveTaskCommand(
        id: _task!.id,
        title: _titleController.text,
        description: _descriptionController.text,
        plannedDate: DateTime.tryParse(_plannedDateController.text),
        deadlineDate: DateTime.tryParse(_deadlineDateController.text),
        priority: _task!.priority,
        estimatedTime: _task!.estimatedTime,
        isCompleted: _task!.isCompleted,
      );

      await AsyncErrorHandler.execute<SaveTaskCommandResponse>(
        context: context,
        errorMessage: _translationService.translate(TaskTranslationKeys.saveTaskError),
        operation: () => _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand),
        onSuccess: (result) {
          _tasksService.notifyTaskUpdated(result.id);
          widget.onTaskUpdated?.call();
        },
      );
    });
  }

  Future<bool> _addTag(String tagId) async {
    final result = await AsyncErrorHandler.execute<AddTaskTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.addTagError),
      operation: () async {
        final command = AddTaskTagCommand(taskId: _task!.id, tagId: tagId);
        return await _mediator.send(command);
      },
      onSuccess: (_) async {
        _tasksService.notifyTaskUpdated(_task!.id);
        await _getTaskTags();
      },
    );
    return result != null;
  }

  Future<bool> _removeTag(String id) async {
    final result = await AsyncErrorHandler.execute<RemoveTaskTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.removeTagError),
      operation: () async {
        final command = RemoveTaskTagCommand(id: id);
        return await _mediator.send(command);
      },
      onSuccess: (_) async {
        _tasksService.notifyTaskUpdated(_task!.id);
        await _getTaskTags();
      },
    );
    return result != null;
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    final tagOptionsToAdd =
        tagOptions.where((tagOption) => !_taskTags!.items.any((taskTag) => taskTag.tagId == tagOption.value)).toList();
    final tagsToRemove =
        _taskTags!.items.where((taskTag) => !tagOptions.map((tag) => tag.value).contains(taskTag.tagId)).toList();

    // Batch process all tag operations
    Future<void> processTags() async {
      // Add all tags
      for (final tagOption in tagOptionsToAdd) {
        await _addTag(tagOption.value);
      }

      // Remove all tags
      for (final taskTag in tagsToRemove) {
        await _removeTag(taskTag.id);
      }

      // Notify only once after all tag operations are complete
      if (tagOptionsToAdd.isNotEmpty || tagsToRemove.isNotEmpty) {
        _tasksService.notifyTaskUpdated(_task!.id);
      }
    }

    // Execute the tag operations
    processTags();
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null || _taskTags == null) {
      return const SizedBox.shrink();
    }

    // Don't show fields with content in the chips section
    final List<String> availableChipFields = [
      keyTags,
      keyPriority,
      keyEstimatedTime,
      keyPlannedDate,
      keyDeadlineDate,
      keyDescription,
    ].where((field) => _shouldShowAsChip(field)).toList();

    // Should hide elapsed time if it's 0
    final bool showElapsedTime = _task!.totalDuration > 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_task != null)
                TaskCompleteButton(
                  taskId: widget.taskId,
                  isCompleted: _task!.isCompleted,
                  onToggleCompleted: () {
                    _task!.isCompleted = !_task!.isCompleted;
                    widget.onCompletedChanged?.call(_task!.isCompleted);
                  },
                ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _titleController,
                  maxLines: null,
                  onChanged: (value) {
                    _updateTask();
                    widget.onTitleUpdated?.call(value);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: Tooltip(
                      message: _translationService.translate(TaskTranslationKeys.editTitleTooltip),
                      child: Icon(Icons.edit, size: AppTheme.iconSizeSmall),
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sizeSmall),

          // Only show elapsed time if greater than 0
          if (showElapsedTime)
            DetailTable(rowData: [
              _buildElapsedTimeSection(),
            ]),

          // Display optional fields section
          if (_visibleOptionalFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeXSmall),
            // Only fields that are manually set as visible (excluding description which is handled separately)
            DetailTable(
                rowData: [
              if (_visibleOptionalFields.contains(keyTags)) _buildTagsSection(),
              if (_visibleOptionalFields.contains(keyPriority)) _buildPrioritySection(),
              if (_visibleOptionalFields.contains(keyEstimatedTime)) _buildEstimatedTimeSection(),
              if (_visibleOptionalFields.contains(keyPlannedDate)) _buildPlannedDateSection(),
              if (_visibleOptionalFields.contains(keyDeadlineDate)) _buildDeadlineDateSection(),
            ].toList()),
          ],

          // Description section if enabled (handled separately due to its different layout)
          if (_visibleOptionalFields.contains(keyDescription)) _buildDescriptionSection(),

          // Only show chip section if we have available fields to add
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  DetailTableRowData _buildTagsSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.tagsLabel),
        icon: TaskUiConstants.tagsIcon,
        hintText: _translationService.translate(TaskTranslationKeys.tagsHint),
        widget: TagSelectDropdown(
          key: ValueKey(_taskTags!.items.length),
          isMultiSelect: true,
          onTagsSelected: (options, _) => _onTagsSelected(options),
          showSelectedInDropdown: true,
          initialSelectedTags:
              _taskTags!.items.map((tag) => DropdownOption<String>(label: tag.tagName, value: tag.tagId)).toList(),
          icon: SharedUiConstants.addIcon,
        ),
      );

  DetailTableRowData _buildPrioritySection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.priorityLabel),
        icon: TaskUiConstants.priorityIcon,
        widget: PrioritySelectField(
          value: _task!.priority,
          options: _priorityOptions,
          onChanged: (value) {
            if (!mounted) return;
            setState(() {
              _task!.priority = value;
              _updateTask();
            });
          },
        ),
      );

  DetailTableRowData _buildEstimatedTimeSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.estimatedTimeLabel),
        icon: TaskUiConstants.estimatedTimeIcon,
        widget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _adjustEstimatedTime(-1),
              icon: const Icon(Icons.remove),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            Text(
              SharedUiConstants.formatDurationHuman(_task!.estimatedTime, _translationService),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => _adjustEstimatedTime(1),
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );

  DetailTableRowData _buildElapsedTimeSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.elapsedTimeLabel),
        icon: TaskUiConstants.timerIcon,
        widget: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            SharedUiConstants.formatDurationHuman(_task!.totalDuration ~/ 60, _translationService),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

  DetailTableRowData _buildPlannedDateSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.plannedDateLabel),
        icon: TaskUiConstants.plannedDateIcon,
        widget: SizedBox(
          height: 36,
          child: DateTimePickerField(
            controller: _plannedDateController,
            hintText: '',
            minDateTime: DateTime.now(),
            onConfirm: (date) {
              _task?.plannedDate = date;
              _updateTask();
            },
          ),
        ),
      );

  DetailTableRowData _buildDeadlineDateSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.deadlineDateLabel),
        icon: TaskUiConstants.deadlineDateIcon,
        widget: SizedBox(
          height: 36,
          child: DateTimePickerField(
            controller: _deadlineDateController,
            hintText: '',
            minDateTime: DateTime.now(),
            onConfirm: (date) {
              _task?.deadlineDate = date;
              _updateTask();
            },
          ),
        ),
      );

  Widget _buildDescriptionSection() => DetailTable(
        forceVertical: true,
        rowData: [
          DetailTableRowData(
            label: _translationService.translate(TaskTranslationKeys.descriptionLabel),
            icon: TaskUiConstants.descriptionIcon,
            hintText: _translationService.translate(SharedTranslationKeys.markdownEditorHint),
            widget: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MarkdownAutoPreview(
                controller: _descriptionController,
                onChanged: (value) {
                  // Handle empty whitespace
                  final isEmptyWhitespace = value.trim().isEmpty;
                  if (isEmptyWhitespace) {
                    _descriptionController.clear();

                    // Set cursor at beginning after clearing
                    if (mounted) {
                      _descriptionController.selection = const TextSelection.collapsed(offset: 0);
                    }
                  }

                  // Simply trigger the update
                  _updateTask();
                },
                hintText: _translationService.translate(TaskTranslationKeys.addDescriptionHint),
                toolbarBackground: AppTheme.surface1,
              ),
            ),
          ),
        ],
      );

  void _adjustEstimatedTime(int adjustment) {
    if (!mounted) return;
    setState(() {
      final currentIndex = TaskUiConstants.defaultEstimatedTimeOptions.indexOf(_task!.estimatedTime ?? 0);
      if (currentIndex == -1) {
        _task!.estimatedTime = TaskUiConstants.defaultEstimatedTimeOptions.first;
      } else {
        final newIndex = (currentIndex + adjustment).clamp(
          0,
          TaskUiConstants.defaultEstimatedTimeOptions.length - 1,
        );
        _task!.estimatedTime = TaskUiConstants.defaultEstimatedTimeOptions[newIndex];
      }
      _updateTask();
    });
  }

  // Widget to build optional field chips
  Widget _buildOptionalFieldChip(String fieldKey, bool hasContent) {
    return OptionalFieldChip(
      label: _getFieldLabel(fieldKey),
      icon: _getFieldIcon(fieldKey),
      selected: _isFieldVisible(fieldKey),
      onSelected: (_) => _toggleOptionalField(fieldKey),
      backgroundColor: hasContent ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : null,
    );
  }

  // Get descriptive label for field chips
  String _getFieldLabel(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return _translationService.translate(TaskTranslationKeys.tagsLabel);
      case keyPriority:
        return _translationService.translate(TaskTranslationKeys.priorityLabel);
      case keyEstimatedTime:
        return _translationService.translate(TaskTranslationKeys.estimatedTimeLabel);
      case keyPlannedDate:
        return _translationService.translate(TaskTranslationKeys.plannedDateLabel);
      case keyDeadlineDate:
        return _translationService.translate(TaskTranslationKeys.deadlineDateLabel);
      case keyDescription:
        return _translationService.translate(TaskTranslationKeys.descriptionLabel);
      default:
        return '';
    }
  }

  // Get icon for field chips
  IconData _getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return TaskUiConstants.tagsIcon;
      case keyPriority:
        return TaskUiConstants.priorityIcon;
      case keyEstimatedTime:
        return TaskUiConstants.estimatedTimeIcon;
      case keyPlannedDate:
        return TaskUiConstants.plannedDateIcon;
      case keyDeadlineDate:
        return TaskUiConstants.deadlineDateIcon;
      case keyDescription:
        return TaskUiConstants.descriptionIcon;
      default:
        return Icons.add;
    }
  }
}
