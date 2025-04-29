import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:intl/intl.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tasks/models/task_data.dart';

class QuickTaskBottomSheet extends StatefulWidget {
  final List<String>? initialTagIds;
  final DateTime? initialPlannedDate;
  final Function(String taskId, TaskData taskData)? onTaskCreated;
  final String? initialParentTaskId;

  const QuickTaskBottomSheet({
    super.key,
    this.initialTagIds,
    this.initialPlannedDate,
    this.onTaskCreated,
    this.initialParentTaskId,
  });

  @override
  State<QuickTaskBottomSheet> createState() => _QuickTaskBottomSheetState();
}

class _QuickTaskBottomSheetState extends State<QuickTaskBottomSheet> {
  final _titleController = TextEditingController();
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  // Quick action state variables
  EisenhowerPriority? _selectedPriority;
  int? _estimatedTime;
  DateTime? _plannedDate;
  DateTime? _deadlineDate;
  List<DropdownOption<String>> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _plannedDate = widget.initialPlannedDate;
    _selectedTags = widget.initialTagIds?.map((id) => DropdownOption(label: '', value: id)).toList() ?? [];
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _resetState() {
    _titleController.clear();
  }

  void _clearAll() {
    setState(() {
      _titleController.clear();
      _selectedPriority = null;
      _estimatedTime = null;
      _plannedDate = widget.initialPlannedDate;
      _deadlineDate = null;
      _selectedTags = [];
    });
  }

  Future<void> _createTask() async {
    if (_isLoading || _titleController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final command = SaveTaskCommand(
        title: _titleController.text,
        description: "",
        tagIdsToAdd: _selectedTags.map((t) => t.value).toList(),
        priority: _selectedPriority,
        estimatedTime: _estimatedTime,
        plannedDate: _plannedDate,
        deadlineDate: _deadlineDate,
        isCompleted: false,
        parentTaskId: widget.initialParentTaskId, // Use initialParentTaskId
      );
      final response = await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);

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
          createdDate: DateTime.now(),
        );

        widget.onTaskCreated!(response.id, taskData);
      }

      if (mounted) {
        setState(() {
          _titleController.clear();
          _resetState();
        });
        _focusNode.requestFocus();
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e as Exception, stackTrace, message: 'Error creating task');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    return DateFormat('dd.MM.yy').format(date);
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

  List<Widget> _buildQuickActionButtons() {
    return [
      IconButton(
        icon: const Icon(Icons.close, color: AppTheme.secondaryTextColor),
        onPressed: _clearAll,
        tooltip: 'Clear all fields',
      ),
      TagSelectDropdown(
        initialSelectedTags: _selectedTags,
        isMultiSelect: true,
        onTagsSelected: (tags) {
          setState(() => _selectedTags = tags);
        },
        iconSize: AppTheme.iconSizeMedium,
        color: _selectedTags.isEmpty ? AppTheme.secondaryTextColor : TaskUiConstants.tagColor,
      ),
      IconButton(
        icon: Icon(
          _selectedPriority == null ? TaskUiConstants.priorityOutlinedIcon : TaskUiConstants.priorityIcon,
          color: TaskUiConstants.getPriorityColor(_selectedPriority),
        ),
        onPressed: _togglePriority,
        tooltip: _translationService.translate(TaskTranslationKeys.priorityNone),
      ),
      IconButton(
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
      ),
      IconButton(
        icon: Icon(
          _plannedDate == null ? TaskUiConstants.plannedDateOutlinedIcon : TaskUiConstants.plannedDateIcon,
          color: _plannedDate == null ? null : TaskUiConstants.plannedDateColor,
        ),
        onPressed: () => _selectDate(false),
        tooltip: _getDateTooltip(false),
      ),
      IconButton(
        icon: Icon(
          _deadlineDate == null ? TaskUiConstants.deadlineDateOutlinedIcon : TaskUiConstants.deadlineDateIcon,
          color: _deadlineDate == null ? null : TaskUiConstants.deadlineDateColor,
        ),
        onPressed: () => _selectDate(true),
        tooltip: _getDateTooltip(true),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = AppThemeHelper.isSmallScreen(context);

    return PopScope(
      canPop: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {}, // Prevent tap from propagating
              child: DraggableScrollableSheet(
                initialChildSize: AppThemeHelper.isSmallScreen(context) ? 0.33 : 0.15,
                minChildSize: 0.15,
                maxChildSize: 0.9,
                builder: (context, controller) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: SingleChildScrollView(
                      controller: controller,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Title input
                          TextField(
                            controller: _titleController,
                            focusNode: _focusNode,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: _translationService.translate(TaskTranslationKeys.quickTaskTitleHint),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Quick action buttons (large screen)
                                  if (!isSmallScreen) ..._buildQuickActionButtons(),

                                  // Send button
                                  IconButton(
                                    icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.send,
                                        color: AppTheme.primaryColor),
                                    onPressed: _createTask,
                                  ),
                                ],
                              ),
                            ),
                            onSubmitted: (_) => _createTask(),
                          ),

                          // Quick action buttons (small screen)
                          if (isSmallScreen)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _buildQuickActionButtons(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
