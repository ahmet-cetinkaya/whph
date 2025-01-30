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
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tasks/components/priority_select_field.dart';
import 'package:whph/presentation/shared/components/detail_table.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

class TaskDetailsContent extends StatefulWidget {
  final _mediator = container.resolve<Mediator>();
  final _tasksService = container.resolve<TasksService>();
  final _translationService = container.resolve<ITranslationService>();

  final String taskId;
  final VoidCallback? onTaskUpdated;
  final Function(String)? onTitleUpdated;
  final Function(bool)? onCompletedChanged;

  TaskDetailsContent({
    super.key,
    required this.taskId,
    this.onTaskUpdated,
    this.onTitleUpdated,
    this.onCompletedChanged,
  });

  @override
  State<TaskDetailsContent> createState() => _TaskDetailsContentState();
}

class _TaskDetailsContentState extends State<TaskDetailsContent> {
  GetTaskQueryResponse? _task;
  GetListTaskTagsQueryResponse? _taskTags;
  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _deadlineDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _titleController = TextEditingController();
  Timer? _debounce;

  late List<DropdownOption<EisenhowerPriority?>> _priorityOptions;

  @override
  void initState() {
    _getInitialData();
    widget._tasksService.onTaskSaved.addListener(_getTask);
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _debounce?.cancel();
    widget._tasksService.onTaskSaved.removeListener(_getTask);
    super.dispose();
  }

  Future<void> _getInitialData() async {
    await Future.wait([_getTask(), _getTaskTags()]);
  }

  Future<void> _getTask() async {
    try {
      final query = GetTaskQuery(id: widget.taskId);
      final response = await widget._mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);

      if (mounted) {
        setState(() {
          _task = response;
          if (_titleController.text != response.title) {
            _titleController.text = response.title;
            widget.onTitleUpdated?.call(response.title);
          }
          widget.onCompletedChanged?.call(response.isCompleted);
          _priorityOptions = [
            DropdownOption(label: widget._translationService.translate(TaskTranslationKeys.priorityNone), value: null),
            DropdownOption(
                label: widget._translationService.translate(TaskTranslationKeys.priorityUrgentImportant),
                value: EisenhowerPriority.urgentImportant),
            DropdownOption(
                label: widget._translationService.translate(TaskTranslationKeys.priorityNotUrgentImportant),
                value: EisenhowerPriority.notUrgentImportant),
            DropdownOption(
                label: widget._translationService.translate(TaskTranslationKeys.priorityUrgentNotImportant),
                value: EisenhowerPriority.urgentNotImportant),
            DropdownOption(
                label: widget._translationService.translate(TaskTranslationKeys.priorityNotUrgentNotImportant),
                value: EisenhowerPriority.notUrgentNotImportant),
          ];
          _plannedDateController.text =
              _task!.plannedDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_task!.plannedDate!) : '';
          _deadlineDateController.text =
              _task!.deadlineDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_task!.deadlineDate!) : '';
          _descriptionController.text = _task!.description ?? '';
        });
      }
    } catch (e, stackTrace) {
      if (!mounted) return;

      if (e is BusinessException) {
        ErrorHelper.showError(context, e);
      } else {
        ErrorHelper.showUnexpectedError(
          context,
          Exception(e.toString()), // Wrap the error in an Exception
          stackTrace,
          message: widget._translationService.translate(TaskTranslationKeys.getTaskError),
        );
      }
    }
  }

  Future<void> _getTaskTags() async {
    int pageIndex = 0;
    const int pageSize = 50;

    while (true) {
      final query = GetListTaskTagsQuery(taskId: widget.taskId, pageIndex: pageIndex, pageSize: pageSize);
      try {
        final response = await widget._mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(query);

        if (mounted) {
          setState(() {
            if (_taskTags == null) {
              _taskTags = response;
            } else {
              _taskTags!.items.addAll(response.items);
            }
          });
        }
        pageIndex++;
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: widget._translationService.translate(TaskTranslationKeys.getTagsError),
          );
          break;
        }
      }
    }
  }

  Future<void> _updateTask() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final currentSelection = _titleController.selection;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
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
      try {
        final result = await widget._mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand);
        widget._tasksService.onTaskSaved.value = result;
        widget.onTaskUpdated?.call();

        if (mounted) {
          _titleController.selection = currentSelection;
        }
      } on BusinessException catch (e) {
        if (mounted) ErrorHelper.showError(context, e);
      } catch (e, stackTrace) {
        if (mounted) {
          ErrorHelper.showUnexpectedError(
            context,
            e as Exception,
            stackTrace,
            message: widget._translationService.translate(TaskTranslationKeys.saveTaskError),
          );
        }
      }
    });
  }

  Future<void> _addTag(String tagId) async {
    try {
      final command = AddTaskTagCommand(taskId: _task!.id, tagId: tagId);
      await widget._mediator.send(command);
      await _getTaskTags();
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: widget._translationService.translate(TaskTranslationKeys.addTagError),
        );
      }
    }
  }

  Future<void> _removeTag(String id) async {
    try {
      final command = RemoveTaskTagCommand(id: id);
      await widget._mediator.send(command);
      await _getTaskTags();
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: widget._translationService.translate(TaskTranslationKeys.removeTagError),
        );
      }
    }
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    final tagOptionsToAdd =
        tagOptions.where((tagOption) => !_taskTags!.items.any((taskTag) => taskTag.tagId == tagOption.value)).toList();
    final tagsToRemove =
        _taskTags!.items.where((taskTag) => !tagOptions.map((tag) => tag.value).contains(taskTag.tagId)).toList();

    for (final tagOption in tagOptionsToAdd) {
      _addTag(tagOption.value);
    }
    for (final taskTag in tagsToRemove) {
      _removeTag(taskTag.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null || _taskTags == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Title
            TextFormField(
              controller: _titleController,
              maxLines: null,
              onChanged: (value) async {
                await _updateTask();
                widget.onTitleUpdated?.call(value);
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: Tooltip(
                  message: widget._translationService.translate(TaskTranslationKeys.editTitleTooltip),
                  child: Icon(Icons.edit, size: AppTheme.iconSizeSmall),
                ),
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.sizeMedium),
            DetailTable(rowData: [
              _buildTagsSection(),
              _buildPrioritySection(),
              _buildEstimatedTimeSection(),
              _buildElapsedTimeSection(),
              _buildPlannedDateSection(),
              _buildDeadlineDateSection(),
            ]),
            _buildDescriptionSection(),
          ],
        ),
      ),
    );
  }

  DetailTableRowData _buildTagsSection() => DetailTableRowData(
        label: widget._translationService.translate(TaskTranslationKeys.tagsLabel),
        icon: TaskUiConstants.tagsIcon,
        hintText: widget._translationService.translate(TaskTranslationKeys.tagsHint),
        widget: TagSelectDropdown(
          key: ValueKey(_taskTags!.items.length),
          isMultiSelect: true,
          onTagsSelected: _onTagsSelected,
          showSelectedInDropdown: true,
          initialSelectedTags:
              _taskTags!.items.map((tag) => DropdownOption<String>(label: tag.tagName, value: tag.tagId)).toList(),
          icon: SharedUiConstants.addIcon,
        ),
      );

  DetailTableRowData _buildPrioritySection() => DetailTableRowData(
        label: widget._translationService.translate(TaskTranslationKeys.priorityLabel),
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
        label: widget._translationService.translate(TaskTranslationKeys.estimatedTimeLabel),
        icon: TaskUiConstants.estimatedTimeIcon,
        widget: Row(
          children: [
            IconButton(
              onPressed: () => _adjustEstimatedTime(-1),
              icon: const Icon(Icons.remove),
            ),
            Text(
              SharedUiConstants.formatMinutes(_task!.estimatedTime),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => _adjustEstimatedTime(1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      );

  DetailTableRowData _buildElapsedTimeSection() => DetailTableRowData(
        label: widget._translationService.translate(TaskTranslationKeys.elapsedTimeLabel),
        icon: TaskUiConstants.timerIcon,
        widget: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            SharedUiConstants.formatMinutes(_task!.totalDuration ~/ 60),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

  DetailTableRowData _buildPlannedDateSection() => DetailTableRowData(
        label: widget._translationService.translate(TaskTranslationKeys.plannedDateLabel),
        icon: TaskUiConstants.plannedDateIcon,
        widget: SizedBox(
          height: 36,
          child: DateTimePickerField(
            controller: _plannedDateController,
            hintText: '',
            onConfirm: (date) {
              _task?.plannedDate = date;
              _updateTask();
            },
          ),
        ),
      );

  DetailTableRowData _buildDeadlineDateSection() => DetailTableRowData(
        label: widget._translationService.translate(TaskTranslationKeys.deadlineDateLabel),
        icon: TaskUiConstants.deadlineDateIcon,
        widget: SizedBox(
          height: 36,
          child: DateTimePickerField(
            controller: _deadlineDateController,
            hintText: '',
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
            label: widget._translationService.translate(TaskTranslationKeys.descriptionLabel),
            icon: TaskUiConstants.descriptionIcon,
            hintText: widget._translationService.translate(SharedTranslationKeys.markdownEditorHint),
            widget: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MarkdownAutoPreview(
                controller: _descriptionController,
                onChanged: (value) {
                  final isEmptyWhitespace = value.trim().isEmpty;
                  if (isEmptyWhitespace) {
                    _descriptionController.clear();
                  }
                  _updateTask();
                },
                hintText: widget._translationService.translate(TaskTranslationKeys.addDescriptionHint),
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
}
