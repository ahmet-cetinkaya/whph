import 'dart:async';

import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show DateFormatService, DateFormatType, WeekDays;
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/components/recurrence_settings_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_complete_button.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_dates_section.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_description_section.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_field_helpers.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_parent_section.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_priority_section.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_recurrence_section.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_tags_section.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_time_section.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/components/task_timer_section.dart';
import 'package:whph/presentation/ui/features/tasks/components/task_details_content/controllers/task_details_controller.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/components/optional_field_chip.dart';
import 'package:whph/presentation/ui/shared/components/time_logging_dialog.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:acore/utils/dialog_size.dart';

/// Task details content widget - displays and edits task information.
/// Uses [TaskDetailsController] for business logic separation.
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
  late final TaskDetailsController _controller;
  late final TaskFieldHelpers _fieldHelpers;

  // Text controllers for form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _plannedDateController = TextEditingController();
  final TextEditingController _deadlineDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Focus nodes
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _plannedDateFocusNode = FocusNode();
  final FocusNode _deadlineDateFocusNode = FocusNode();

  // Track date picker interaction state
  bool _isPlannedDatePickerActive = false;
  bool _isDeadlineDatePickerActive = false;

  @override
  void initState() {
    super.initState();
    _controller = TaskDetailsController();
    _controller.onTaskUpdated = widget.onTaskUpdated;
    _controller.onTitleUpdated = widget.onTitleUpdated;
    _controller.onCompletedChanged = widget.onCompletedChanged;
    _controller.addListener(_onControllerChanged);
    _fieldHelpers = TaskFieldHelpers(translationService: _controller.translationService);
    _setupFocusListeners();
    _initializeController();
  }

  void _setupFocusListeners() {
    _titleFocusNode.addListener(_handleTitleFocusChange);
    _plannedDateFocusNode.addListener(() => setState(() {}));
    _deadlineDateFocusNode.addListener(() => setState(() {}));
  }

  void _handleTitleFocusChange() {
    if (!mounted) return;
    _controller.setTitleFieldActive(_titleFocusNode.hasFocus);
  }

  Future<void> _initializeController() async {
    await _controller.initialize(widget.taskId);
    _syncControllersFromTask();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _syncControllersFromTask();
    setState(() {});
  }

  void _syncControllersFromTask() {
    final task = _controller.task;
    if (task == null) return;

    if (_titleController.text != task.title) {
      _titleController.text = task.title;
    }

    if (!_isPlannedDatePickerActive && !_plannedDateFocusNode.hasFocus) {
      final plannedDateText = task.plannedDate != null
          ? DateFormatService.formatForInput(task.plannedDate, context, type: DateFormatType.dateTime)
          : '';
      if (_plannedDateController.text != plannedDateText) {
        _plannedDateController.text = plannedDateText;
      }
    }

    if (!_isDeadlineDatePickerActive && !_deadlineDateFocusNode.hasFocus) {
      final deadlineDateText = task.deadlineDate != null
          ? DateFormatService.formatForInput(task.deadlineDate, context, type: DateFormatType.dateTime)
          : '';
      if (_deadlineDateController.text != deadlineDateText) {
        _deadlineDateController.text = deadlineDateText;
      }
    }

    final descriptionText = task.description ?? '';
    if (_descriptionController.text != descriptionText) {
      _descriptionController.text = descriptionText;
    }
  }

  @override
  void didUpdateWidget(TaskDetailsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _initializeController();
    }
    _controller.onTaskUpdated = widget.onTaskUpdated;
    _controller.onTitleUpdated = widget.onTitleUpdated;
    _controller.onCompletedChanged = widget.onCompletedChanged;
  }

  @override
  void dispose() {
    _controller.saveTaskImmediately();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _plannedDateController.dispose();
    _plannedDateFocusNode.dispose();
    _deadlineDateController.dispose();
    _deadlineDateFocusNode.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    await _controller.initialize(widget.taskId);
  }

  // Event handlers
  void _onTitleChanged(String value) => _controller.updateTitle(value);
  void _onPriorityChanged(EisenhowerPriority? value) => _controller.updatePriority(value);
  void _onEstimatedTimeChanged(int value) => _controller.updateEstimatedTime(value);

  void _onPlannedDateChanged(DateTime? date) {
    _isPlannedDatePickerActive = true;
    if (date != null) {
      _plannedDateController.text = DateFormatService.formatForInput(date, context, type: DateFormatType.dateTime);
    } else {
      _plannedDateController.clear();
    }
    _controller.updatePlannedDate(date);
    Timer(const Duration(milliseconds: 100), () => _isPlannedDatePickerActive = false);
  }

  void _onPlannedReminderChanged(ReminderTime value, int? customOffset) =>
      _controller.updatePlannedReminder(value, customOffset);

  void _onDeadlineDateChanged(DateTime? date) {
    _isDeadlineDatePickerActive = true;
    if (date != null) {
      _deadlineDateController.text = DateFormatService.formatForInput(date, context, type: DateFormatType.dateTime);
    } else {
      _deadlineDateController.clear();
    }
    _controller.updateDeadlineDate(date);
    Timer(const Duration(milliseconds: 100), () => _isDeadlineDatePickerActive = false);
  }

  void _onDeadlineReminderChanged(ReminderTime value, int? customOffset) =>
      _controller.updateDeadlineReminder(value, customOffset);

  void _onDescriptionChanged(String value) {
    if (value.trim().isEmpty) {
      _descriptionController.clear();
      if (mounted) {
        _descriptionController.selection = const TextSelection.collapsed(offset: 0);
      }
    }
    _controller.updateDescription(value);
  }

  void _onTagsSelected(List<DropdownOption<String>> tagOptions) => _controller.processTagChanges(tagOptions, context);

  Future<void> _showTimeLoggingDialog() async {
    final task = _controller.task;
    if (task == null) return;

    final result = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.medium,
      child: TimeLoggingDialog(
        entityId: task.id,
        onCancel: () {},
        onTimeLoggingSubmitted: (event) async {
          await _controller.logTime(
            context: context,
            isSetTotalMode: event.isSetTotalMode,
            durationInSeconds: event.durationInSeconds,
            date: event.date,
          );
        },
      ),
    );

    if (result == true) {
      await _controller.loadTask(widget.taskId);
    }
  }

  Future<void> _openRecurrenceDialog() async {
    final task = _controller.task;
    if (task == null) return;

    final result = await ResponsiveDialogHelper.showResponsiveDialog<Map<String, dynamic>>(
      context: context,
      size: DialogSize.large,
      child: RecurrenceSettingsDialog(
        initialRecurrenceType: task.recurrenceType,
        initialRecurrenceInterval: task.recurrenceInterval,
        initialRecurrenceDays: _controller.taskRecurrenceService.getRecurrenceDays(task),
        initialRecurrenceStartDate: task.recurrenceStartDate,
        initialRecurrenceEndDate: task.recurrenceEndDate,
        initialRecurrenceCount: task.recurrenceCount,
        plannedDate: task.plannedDate,
      ),
    );

    if (result != null && mounted) {
      final recurrenceType = result['recurrenceType'] as RecurrenceType;
      final List<dynamic>? daysList = result['recurrenceDays'] as List<dynamic>?;

      _controller.updateRecurrence(
        recurrenceType: recurrenceType,
        recurrenceInterval: result['recurrenceInterval'] as int?,
        recurrenceDays: daysList?.cast<WeekDays>(),
        recurrenceStartDate: result['recurrenceStartDate'] as DateTime?,
        recurrenceEndDate: result['recurrenceEndDate'] as DateTime?,
        recurrenceCount: result['recurrenceCount'] as int?,
      );
    }
  }

  void _navigateToParentTask() {
    final task = _controller.task;
    if (task?.parentTask == null) return;

    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.max,
      child: TaskDetailsPage(
        taskId: task!.parentTask!.id,
        hideSidebar: true,
        onTaskDeleted: () {
          _controller.loadTask(widget.taskId);
          Navigator.of(context).pop();
        },
        onTaskCompleted: () => _controller.loadTask(widget.taskId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _controller.task;
    final taskTags = _controller.taskTags;

    if (task == null || taskTags == null) {
      return const SizedBox.shrink();
    }

    final visibleFields = _controller.visibleOptionalFields;
    final availableChipFields = [
      TaskDetailsController.keyTags,
      TaskDetailsController.keyPriority,
      TaskDetailsController.keyTimer,
      TaskDetailsController.keyElapsedTime,
      TaskDetailsController.keyEstimatedTime,
      TaskDetailsController.keyPlannedDate,
      TaskDetailsController.keyDeadlineDate,
      TaskDetailsController.keyRecurrence,
      TaskDetailsController.keyDescription,
      TaskDetailsController.keyPlannedDateReminder,
      TaskDetailsController.keyDeadlineDateReminder,
    ].where((field) => _controller.shouldShowAsChip(field)).toList();

    // Create section builders
    final tagsSection = TaskTagsSection(
      translationService: _controller.translationService,
      taskTags: taskTags,
      onTagsSelected: _onTagsSelected,
    );
    final prioritySection = TaskPrioritySection(
      translationService: _controller.translationService,
      priority: task.priority,
      onPriorityChanged: _onPriorityChanged,
    );
    final timeSection = TaskTimeSection(translationService: _controller.translationService);
    final datesSection = TaskDatesSection(translationService: _controller.translationService);
    final recurrenceSection = TaskRecurrenceSection(
      translationService: _controller.translationService,
      recurrenceType: task.recurrenceType,
      summaryText: _controller.getRecurrenceSummaryText(),
      onTap: _openRecurrenceDialog,
    );
    final descriptionSection = TaskDescriptionSection(
      translationService: _controller.translationService,
      controller: _descriptionController,
      onChanged: _onDescriptionChanged,
    );
    final timerSection = TaskTimerSection(
      translationService: _controller.translationService,
      onTick: _controller.handleTimerTick,
      onTimerStop: _controller.onTimerStop,
      onWorkSessionComplete: _controller.onWorkSessionComplete,
    );
    final parentSection = TaskParentSection(
      translationService: _controller.translationService,
      parentTitle: task.parentTask?.title,
      onTap: _navigateToParentTask,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with complete button
          Row(
            children: [
              TaskCompleteButton(
                taskId: widget.taskId,
                isCompleted: task.isCompleted,
                onToggleCompleted: _controller.toggleTaskCompletion,
                color: task.priority != null ? TaskUiConstants.getPriorityColor(task.priority) : null,
                subTasksCompletionPercentage: task.subTasksCompletionPercentage,
              ),
              const SizedBox(width: AppTheme.sizeSmall),
              Expanded(
                child: TextFormField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  maxLines: null,
                  onChanged: _onTitleChanged,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.size2XSmall),

          // Display optional fields section
          if (visibleFields.isNotEmpty) ...[
            DetailTable(
              rowData: [
                if (task.parentTask != null) parentSection.build(),
                if (visibleFields.contains(TaskDetailsController.keyTags)) tagsSection.build(),
                if (visibleFields.contains(TaskDetailsController.keyPriority)) prioritySection.build(),
                if (visibleFields.contains(TaskDetailsController.keyTimer)) timerSection.build(),
                if (visibleFields.contains(TaskDetailsController.keyElapsedTime))
                  timeSection.buildElapsedTime(
                    totalDuration: task.totalDuration,
                    onTap: _showTimeLoggingDialog,
                  ),
                if (visibleFields.contains(TaskDetailsController.keyEstimatedTime))
                  timeSection.buildEstimatedTime(
                    estimatedTime: task.estimatedTime,
                    onEstimatedTimeChanged: _onEstimatedTimeChanged,
                  ),
                if (visibleFields.contains(TaskDetailsController.keyPlannedDate))
                  datesSection.buildPlannedDate(
                    taskId: task.id,
                    controller: _plannedDateController,
                    focusNode: _plannedDateFocusNode,
                    context: context,
                    reminderValue: task.plannedDateReminderTime,
                    reminderCustomOffset: task.plannedDateReminderCustomOffset,
                    onDateChanged: _onPlannedDateChanged,
                    onReminderChanged: _onPlannedReminderChanged,
                  ),
                if (visibleFields.contains(TaskDetailsController.keyDeadlineDate))
                  datesSection.buildDeadlineDate(
                    taskId: task.id,
                    controller: _deadlineDateController,
                    focusNode: _deadlineDateFocusNode,
                    context: context,
                    minDateTime: _controller.getMinimumDeadlineDate(),
                    plannedDateTime: task.plannedDate,
                    reminderValue: task.deadlineDateReminderTime,
                    reminderCustomOffset: task.deadlineDateReminderCustomOffset,
                    onDateChanged: _onDeadlineDateChanged,
                    onReminderChanged: _onDeadlineReminderChanged,
                  ),
                if (visibleFields.contains(TaskDetailsController.keyRecurrence)) recurrenceSection.build(context),
              ],
              isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
            ),
          ],

          // Description section
          if (visibleFields.contains(TaskDetailsController.keyDescription)) ...[
            descriptionSection.build(context),
            const SizedBox(height: AppTheme.size2XSmall),
          ],

          // Chip section for hidden fields
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, task)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionalFieldChip(String fieldKey, dynamic task) {
    String? tooltip;

    if (fieldKey == TaskDetailsController.keyPlannedDateReminder ||
        fieldKey == TaskDetailsController.keyDeadlineDateReminder) {
      final hasDate = fieldKey == TaskDetailsController.keyPlannedDateReminder
          ? task.plannedDate != null
          : task.deadlineDate != null;

      tooltip = hasDate
          ? _controller.translationService.translate(TaskTranslationKeys.reminderHelpText)
          : _controller.translationService.translate(TaskTranslationKeys.reminderDateRequiredTooltip);
    }

    return OptionalFieldChip(
      label: _fieldHelpers.getFieldLabel(fieldKey),
      icon: _fieldHelpers.getFieldIcon(fieldKey),
      selected: _controller.isFieldVisible(fieldKey),
      onSelected: (_) => _controller.toggleOptionalField(fieldKey),
      backgroundColor: null,
      tooltip: tooltip,
    );
  }
}
