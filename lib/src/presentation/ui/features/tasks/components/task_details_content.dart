import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/presentation/ui/shared/components/markdown_editor.dart';
import 'package:whph/src/core/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/src/core/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/src/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/src/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/src/core/application/features/tasks/queries/get_task_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/priority_select_field.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/recurrence_settings_dialog.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/task_complete_button.dart';
import 'package:whph/src/presentation/ui/features/tasks/components/task_date_field.dart';
import 'package:whph/src/presentation/ui/features/tasks/pages/task_details_page.dart';
import 'package:whph/src/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/components/optional_field_chip.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/src/presentation/ui/features/tags/services/tags_service.dart';

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
  final _taskRecurrenceService = container.resolve<ITaskRecurrenceService>();
  final _tagsService = container.resolve<TagsService>();

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
  static const String keyPlannedDateReminder = 'plannedDateReminder';
  static const String keyDeadlineDateReminder = 'deadlineDateReminder';
  static const String keyRecurrence = 'recurrence';
  static const String keyParentTask = 'parentTask';

  late List<DropdownOption<EisenhowerPriority?>> _priorityOptions;

  @override
  void initState() {
    super.initState();
    refresh();
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _tasksService.onTaskUpdated.addListener(_getTask);
    _tagsService.onTagUpdated.addListener(_handleTagUpdated);
  }

  void _removeEventListeners() {
    _tasksService.onTaskUpdated.removeListener(_getTask);
    _tagsService.onTagUpdated.removeListener(_handleTagUpdated);
  }

  void _handleTagUpdated() {
    if (!mounted) return;
    // Refresh task tags when any tag is updated to get the latest tag names/colors
    _getTaskTags();
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
      if (_hasFieldContent(keyRecurrence)) _visibleOptionalFields.add(keyRecurrence);

      // Make reminder fields visible if their corresponding date fields are visible
      if (_visibleOptionalFields.contains(keyPlannedDate)) _visibleOptionalFields.add(keyPlannedDateReminder);
      if (_visibleOptionalFields.contains(keyDeadlineDate)) _visibleOptionalFields.add(keyDeadlineDateReminder);

      // Also make reminder fields visible if they have non-default values
      if (_hasFieldContent(keyPlannedDateReminder)) _visibleOptionalFields.add(keyPlannedDateReminder);
      if (_hasFieldContent(keyDeadlineDateReminder)) _visibleOptionalFields.add(keyDeadlineDateReminder);
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
      case keyPlannedDateReminder:
        return _task!.plannedDateReminderTime != ReminderTime.none;
      case keyDeadlineDateReminder:
        return _task!.deadlineDateReminderTime != ReminderTime.none;
      case keyRecurrence:
        return _task!.recurrenceType != RecurrenceType.none;
      case keyParentTask:
        return _task!.parentTask != null;
      default:
        return false;
    }
  }

  Future<void> refresh() async {
    await _getInitialData();
  }

  @override
  void dispose() {
    // If there's a pending debounced update, save immediately before disposing
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      // Save immediately without debounce when disposing
      // We can't await in dispose, but we can start the save operation
      _saveTaskImmediately();
    } else {
      // Always save on dispose to ensure no data loss, avoid context access in dispose
      _saveTaskImmediately();
    }

    // Ensure title changes are notified even on dispose
    if (_task != null && _titleController.text != _task!.title) {
      widget.onTitleUpdated?.call(_titleController.text);
    }

    _titleController.dispose();
    _plannedDateController.dispose();
    _deadlineDateController.dispose();
    _descriptionController.dispose();
    _removeEventListeners();
    super.dispose();
  }

  Future<void> _getInitialData() async {
    await Future.wait([_getTask(), _getTaskTags()]);
  }

  Future<void> _getTask() async {
    if (kDebugMode) {
      print('Refreshing task data for task ${widget.taskId}');
    }

    await AsyncErrorHandler.execute<GetTaskQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.getTaskError),
      operation: () async {
        final query = GetTaskQuery(id: widget.taskId);
        return await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);
      },
      onSuccess: (response) {
        if (!mounted) return;

        if (kDebugMode) {
          print('Task refresh successful: planned=${response.plannedDate}, deadline=${response.deadlineDate}');
        }

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

          // Only update planned date if it's different - handle conversion in presentation layer
          final plannedDateText = _task!.plannedDate != null
              ? DateFormatService.formatForDisplay(_task!.plannedDate, context, type: DateFormatType.dateTime)
              : '';

          if (kDebugMode) {
            print(
                'Updating planned date: server=${_task!.plannedDate}, formatted="$plannedDateText", current="${_plannedDateController.text}"');
          }

          // Only update if different and preserve user input if server returned null unexpectedly
          if (_plannedDateController.text != plannedDateText) {
            // Check if we're clearing a user-entered date due to server issue
            if (plannedDateText.isEmpty && _plannedDateController.text.isNotEmpty) {
              if (kDebugMode) {
                print(
                    'Warning: Server returned null planned date, preserving user input: "${_plannedDateController.text}"');
              }
              // Don't clear the field if user had entered a date but server returned null
              // This could happen if save failed or there was a parsing issue
            } else {
              _plannedDateController.text = plannedDateText;
            }
            // Don't restore selection if text changed
          } else if (plannedDateSelection.isValid) {
            // Restore selection if text didn't change
            _plannedDateController.selection = plannedDateSelection;
          }

          // Only update deadline date if it's different - handle conversion in presentation layer
          final deadlineDateText = _task!.deadlineDate != null
              ? DateFormatService.formatForDisplay(_task!.deadlineDate, context, type: DateFormatType.dateTime)
              : '';

          if (kDebugMode) {
            print(
                'Updating deadline date: server=${_task!.deadlineDate}, formatted="$deadlineDateText", current="${_deadlineDateController.text}"');
          }

          // Only update if different and preserve user input if server returned null unexpectedly
          if (_deadlineDateController.text != deadlineDateText) {
            // Check if we're clearing a user-entered date due to server issue
            if (deadlineDateText.isEmpty && _deadlineDateController.text.isNotEmpty) {
              if (kDebugMode) {
                print(
                    'Warning: Server returned null deadline date, preserving user input: "${_deadlineDateController.text}"');
              }
              // Don't clear the field if user had entered a date but server returned null
            } else {
              _deadlineDateController.text = deadlineDateText;
            }
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

  // Immediately save the task without debounce
  Future<void> _saveTaskImmediately() async {
    if (!mounted || _task == null) return;

    final saveCommand = _buildSaveCommand();
    await _executeSaveCommand(saveCommand);
  }

  /// Helper method to force immediate update without debounce
  void _forceImmediateUpdate() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _saveTaskImmediately();
  }

  /// Helper method to parse dates from controllers with error handling
  DateTime? _parseDateFromController(TextEditingController controller) {
    if (controller.text.isEmpty) return null;

    try {
      // Check if context is mounted and safe to use
      if (mounted && context.mounted) {
        // Use DateFormatService.parseFromInput to match the format used in formatForDisplay
        final parsedDate = DateFormatService.parseFromInput(controller.text, context);
        final result = parsedDate != null ? DateTimeHelper.toUtcDateTime(parsedDate) : null;

        if (kDebugMode) {
          print('Parsing date controller: "${controller.text}" -> $result');
        }

        return result;
      } else {
        // Fallback to direct parsing without context when context is not safe
        final parsedDate = DateFormatService.parseDateTime(controller.text, assumeLocal: true);
        final result = parsedDate != null ? DateTimeHelper.toUtcDateTime(parsedDate) : null;

        if (kDebugMode) {
          print('Parsing date controller (fallback): "${controller.text}" -> $result');
        }

        return result;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing date: "${controller.text}", Error: $e');
      }
      // Return null on parse error to avoid corrupting data
      return null;
    }
  }

  /// Helper method to build save command with current form data
  SaveTaskCommand _buildSaveCommand() {
    final plannedDate = _parseDateFromController(_plannedDateController);
    final deadlineDate = _parseDateFromController(_deadlineDateController);

    if (kDebugMode) {
      print('Building save command with dates:');
      print('  Planned date text: "${_plannedDateController.text}" -> $plannedDate');
      print('  Deadline date text: "${_deadlineDateController.text}" -> $deadlineDate');
    }

    // Validate that if user entered date text, it was successfully parsed
    if (_plannedDateController.text.isNotEmpty && plannedDate == null) {
      if (kDebugMode) {
        print('ERROR: Failed to parse planned date: "${_plannedDateController.text}"');
        print('This should not happen with the improved parsing. Please report this format.');
      }
      // Clear the invalid text to prevent user confusion
      _plannedDateController.clear();
    }
    if (_deadlineDateController.text.isNotEmpty && deadlineDate == null) {
      if (kDebugMode) {
        print('ERROR: Failed to parse deadline date: "${_deadlineDateController.text}"');
        print('This should not happen with the improved parsing. Please report this format.');
      }
      // Clear the invalid text to prevent user confusion
      _deadlineDateController.clear();
    }

    final recurrenceStartDate =
        _task!.recurrenceStartDate != null ? DateTimeHelper.toUtcDateTime(_task!.recurrenceStartDate!) : null;

    final recurrenceEndDate =
        _task!.recurrenceEndDate != null ? DateTimeHelper.toUtcDateTime(_task!.recurrenceEndDate!) : null;

    return SaveTaskCommand(
      id: _task!.id,
      title: _titleController.text,
      description: _descriptionController.text,
      plannedDate: plannedDate,
      deadlineDate: deadlineDate,
      priority: _task!.priority,
      estimatedTime: _task!.estimatedTime,
      isCompleted: _task!.isCompleted,
      // Pass reminder settings
      plannedDateReminderTime: _task!.plannedDateReminderTime,
      deadlineDateReminderTime: _task!.deadlineDateReminderTime,
      // Pass all recurrence settings
      recurrenceType: _task!.recurrenceType,
      recurrenceInterval: _task!.recurrenceInterval,
      recurrenceDays: _taskRecurrenceService.getRecurrenceDays(_task!),
      recurrenceStartDate: recurrenceStartDate,
      recurrenceEndDate: recurrenceEndDate,
      recurrenceCount: _task!.recurrenceCount,
    );
  }

  /// Helper method to execute save command
  Future<void> _executeSaveCommand(SaveTaskCommand saveCommand) async {
    if (kDebugMode) {
      print('Executing save command for task ${saveCommand.id}');
      print('  Planned date: ${saveCommand.plannedDate}');
      print('  Deadline date: ${saveCommand.deadlineDate}');
    }

    // Check if context is still mounted and safe to use before executing async operations
    if (!mounted || !context.mounted) {
      if (kDebugMode) {
        print('Skipping save command execution - context not mounted');
      }
      return;
    }

    await AsyncErrorHandler.execute<SaveTaskCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.saveTaskError),
      operation: () => _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand),
      onSuccess: (result) {
        if (kDebugMode) {
          print('Save command succeeded for task ${result.id}');
        }
        _tasksService.notifyTaskUpdated(result.id);
        widget.onTaskUpdated?.call();
        // Removed _getTask() call to prevent race condition with title editing
        // The task will be reloaded automatically via the onTaskUpdated listener
      },
    );
  }

  /// Generic event handler for field changes that require immediate save
  void _handleFieldChange<T>(T value, void Function(T) updateField) {
    if (!mounted) return;
    setState(() {
      updateField(value);
    });
    _forceImmediateUpdate();
  }

  /// Event handler for priority changes
  void _onPriorityChanged(EisenhowerPriority? value) {
    _handleFieldChange(value, (val) => _task!.priority = val);
  }

  /// Event handler for estimated time changes
  void _onEstimatedTimeChanged(int value) {
    _handleFieldChange(value, (val) => _task!.estimatedTime = val);
  }

  /// Event handler for planned date changes
  void _onPlannedDateChanged(DateTime? date) {
    _handleFieldChange(date, (val) {
      _task?.plannedDate = val;
      // If date is set and reminder is not, set default reminder
      if (val != null && _task!.plannedDateReminderTime == ReminderTime.none) {
        _task!.plannedDateReminderTime = ReminderTime.atTime;
      }
    });
  }

  /// Event handler for planned date reminder changes
  void _onPlannedReminderChanged(ReminderTime value) {
    _handleFieldChange(value, (val) => _task!.plannedDateReminderTime = val);
  }

  /// Event handler for deadline date changes
  void _onDeadlineDateChanged(DateTime? date) {
    _handleFieldChange(date, (val) {
      _task?.deadlineDate = val;
      // If date is set and reminder is not, set default reminder
      if (val != null && _task!.deadlineDateReminderTime == ReminderTime.none) {
        _task!.deadlineDateReminderTime = ReminderTime.atTime;
      }
    });
  }

  /// Event handler for deadline date reminder changes
  void _onDeadlineReminderChanged(ReminderTime value) {
    _handleFieldChange(value, (val) => _task!.deadlineDateReminderTime = val);
  }

  /// Event handler for description changes
  void _onDescriptionChanged(String value) {
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
  }

  /// Event handler for title changes
  void _onTitleChanged(String value) {
    // Notify title change immediately
    widget.onTitleUpdated?.call(value);
    // Trigger debounced save
    _updateTask();
  }

  String _getRecurrenceSummaryText() {
    if (_task == null || _task!.recurrenceType == RecurrenceType.none) {
      return _translationService.translate(TaskTranslationKeys.recurrenceNone);
    }

    String summary = '';
    switch (_task!.recurrenceType) {
      case RecurrenceType.daily:
        summary = _translationService.translate(TaskTranslationKeys.recurrenceDaily);
        if (_task!.recurrenceInterval != null && _task!.recurrenceInterval! > 1) {
          summary +=
              ' (${_translationService.translate(TaskTranslationKeys.recurrenceIntervalPrefix)} ${_task!.recurrenceInterval} ${_translationService.translate(TaskTranslationKeys.recurrenceIntervalSuffixDays)})';
        }
        break;
      case RecurrenceType.weekly:
        summary = _translationService.translate(TaskTranslationKeys.recurrenceWeekly);
        final days = _taskRecurrenceService.getRecurrenceDays(_task!);
        if (days != null && days.isNotEmpty) {
          final dayNames = days
              .map((day) => _translationService
                  .translate(SharedTranslationKeys.getWeekDayNameTranslationKey(day.name, short: true)))
              .join(', ');
          summary += ' ${_translationService.translate(TaskTranslationKeys.on)} $dayNames';
        }
        if (_task!.recurrenceInterval != null && _task!.recurrenceInterval! > 1) {
          summary +=
              ' (${_translationService.translate(TaskTranslationKeys.recurrenceIntervalPrefix)} ${_task!.recurrenceInterval} ${_translationService.translate(TaskTranslationKeys.recurrenceIntervalSuffixWeeks)})';
        }
        break;
      case RecurrenceType.monthly:
        summary = _translationService.translate(TaskTranslationKeys.recurrenceMonthly);
        if (_task!.recurrenceInterval != null && _task!.recurrenceInterval! > 1) {
          summary +=
              ' (${_translationService.translate(TaskTranslationKeys.recurrenceIntervalPrefix)} ${_task!.recurrenceInterval} ${_translationService.translate(TaskTranslationKeys.recurrenceIntervalSuffixMonths)})';
        }
        break;
      case RecurrenceType.yearly:
        summary = _translationService.translate(TaskTranslationKeys.recurrenceYearly);
        if (_task!.recurrenceInterval != null && _task!.recurrenceInterval! > 1) {
          summary +=
              ' (${_translationService.translate(TaskTranslationKeys.recurrenceIntervalPrefix)} ${_task!.recurrenceInterval} ${_translationService.translate(TaskTranslationKeys.recurrenceIntervalSuffixYears)})';
        }
        break;
      default:
        summary = _translationService.translate(TaskTranslationKeys.recurrenceNone);
    }

    if (_task!.recurrenceStartDate != null) {
      summary +=
          '; ${_translationService.translate(TaskTranslationKeys.starts)} ${DateTimeHelper.formatDate(_task!.recurrenceStartDate!)}';
    }

    if (_task!.recurrenceEndDate != null) {
      summary +=
          '; ${_translationService.translate(TaskTranslationKeys.endsOnDate)} ${DateTimeHelper.formatDate(_task!.recurrenceEndDate!)}';
    } else if (_task!.recurrenceCount != null) {
      summary +=
          '; ${_translationService.translate(TaskTranslationKeys.endsAfter)} ${_task!.recurrenceCount} ${_translationService.translate(TaskTranslationKeys.occurrences)}';
    }
    return summary;
  }

  Future<void> _updateTask() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      final saveCommand = _buildSaveCommand();
      await _executeSaveCommand(saveCommand);
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
      keyRecurrence,
      // keyParentTask - Parent task should never appear as chip, only when data exists
      // Reminder fields are handled with their corresponding date fields
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
                  color: _task!.priority != null ? TaskUiConstants.getPriorityColor(_task!.priority) : null,
                  subTasksCompletionPercentage: _task!.subTasksCompletionPercentage,
                ),
              const SizedBox(width: AppTheme.sizeSmall),
              Expanded(
                child: TextFormField(
                  controller: _titleController,
                  maxLines: null,
                  onChanged: _onTitleChanged,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: Tooltip(
                      message: _translationService.translate(TaskTranslationKeys.editTitleTooltip),
                      child: Icon(Icons.edit, size: AppTheme.iconSizeSmall, color: AppTheme.secondaryTextColor),
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.size2XSmall),

          // Display optional fields section
          if (_visibleOptionalFields.isNotEmpty || (_task!.parentTask != null)) ...[
            // Only fields that are manually set as visible (excluding description which is handled separately)
            DetailTable(
              rowData: [
                if (showElapsedTime) _buildElapsedTimeSection(),
                if (_task!.parentTask != null) _buildParentTaskSection(),
                if (_visibleOptionalFields.contains(keyTags)) _buildTagsSection(),
                if (_visibleOptionalFields.contains(keyPriority)) _buildPrioritySection(),
                if (_visibleOptionalFields.contains(keyEstimatedTime)) _buildEstimatedTimeSection(),
                if (_visibleOptionalFields.contains(keyPlannedDate)) _buildPlannedDateSection(),
                if (_visibleOptionalFields.contains(keyDeadlineDate)) _buildDeadlineDateSection(),
                if (_visibleOptionalFields.contains(keyRecurrence)) _buildRecurrenceSection(),
              ].toList(),
              isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
            ),
          ],

          // Description section if enabled (handled separately due to its different layout)
          if (_visibleOptionalFields.contains(keyDescription)) ...[
            _buildDescriptionSection(),
            const SizedBox(height: AppTheme.size2XSmall),
          ],

          // Only show chip section if we have available fields to add
          if (availableChipFields.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  DetailTableRowData _buildTagsSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.tagsLabel),
        icon: TagUiConstants.tagIcon,
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
          onChanged: _onPriorityChanged,
        ),
      );

  DetailTableRowData _buildEstimatedTimeSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.estimatedTimeLabel),
        icon: TaskUiConstants.estimatedTimeIcon,
        widget: NumericInput(
          initialValue: _task!.estimatedTime ?? TaskUiConstants.defaultEstimatedTimeOptions.first,
          incrementValue: 5,
          decrementValue: 5,
          onValueChanged: _onEstimatedTimeChanged,
          decrementTooltip: _translationService.translate(TaskTranslationKeys.decreaseEstimatedTime),
          incrementTooltip: _translationService.translate(TaskTranslationKeys.increaseEstimatedTime),
          iconColor: AppTheme.secondaryTextColor,
          iconSize: AppTheme.iconSizeSmall,
          valueSuffix: _translationService.translate(SharedTranslationKeys.minutesShort),
        ),
      );

  DetailTableRowData _buildElapsedTimeSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.elapsedTimeLabel),
        icon: TaskUiConstants.timerIcon,
        widget: Text(
          SharedUiConstants.formatDurationHuman((_task!.totalDuration / 60).round(), _translationService),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  DetailTableRowData _buildPlannedDateSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.plannedDateLabel),
        icon: TaskUiConstants.plannedDateIcon,
        widget: TaskDateField(
          controller: _plannedDateController,
          hintText: '',
          minDateTime: DateTime.now(),
          onDateChanged: _onPlannedDateChanged,
          onReminderChanged: _onPlannedReminderChanged,
          reminderValue: _task!.plannedDateReminderTime,
          translationService: _translationService,
          reminderLabelPrefix: 'tasks.reminder.planned',
          dateIcon: TaskUiConstants.plannedDateIcon,
        ),
      );

  DetailTableRowData _buildDeadlineDateSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.deadlineDateLabel),
        icon: TaskUiConstants.deadlineDateIcon,
        widget: TaskDateField(
          controller: _deadlineDateController,
          hintText: '',
          minDateTime: DateTime.now(),
          onDateChanged: _onDeadlineDateChanged,
          onReminderChanged: _onDeadlineReminderChanged,
          reminderValue: _task!.deadlineDateReminderTime,
          translationService: _translationService,
          reminderLabelPrefix: 'tasks.reminder.deadline',
          dateIcon: TaskUiConstants.deadlineDateIcon,
        ),
      );

  Future<void> _openRecurrenceDialog() async {
    if (_task == null) return;

    final result = await ResponsiveDialogHelper.showResponsiveDialog<Map<String, dynamic>>(
      context: context,
      size: DialogSize.min,
      child: RecurrenceSettingsDialog(
        initialRecurrenceType: _task!.recurrenceType,
        initialRecurrenceInterval: _task!.recurrenceInterval,
        initialRecurrenceDays: _taskRecurrenceService.getRecurrenceDays(_task!),
        initialRecurrenceStartDate: _task!.recurrenceStartDate,
        initialRecurrenceEndDate: _task!.recurrenceEndDate,
        initialRecurrenceCount: _task!.recurrenceCount,
      ),
    );

    if (result != null) {
      if (!mounted) return;

      setState(() {
        // Update recurrence type first since it affects other fields
        final recurrenceType = result['recurrenceType'] as RecurrenceType;
        _task!.recurrenceType = recurrenceType;

        if (_task!.recurrenceType == RecurrenceType.none) {
          // Clear all recurrence settings if type is none
          _task!.recurrenceInterval = null;
          _task!.setRecurrenceDays(null);
          _task!.recurrenceStartDate = null;
          _task!.recurrenceEndDate = null;
          _task!.recurrenceCount = null;
          // Remove visibility if needed
          if (_visibleOptionalFields.contains(keyRecurrence)) {
            _visibleOptionalFields.remove(keyRecurrence);
          }
        } else {
          // Update all recurrence settings
          _task!.recurrenceInterval = result['recurrenceInterval'] as int?;

          final List<dynamic>? daysList = result['recurrenceDays'] as List<dynamic>?;
          _task!.setRecurrenceDays(daysList?.cast<WeekDays>());

          _task!.recurrenceStartDate = result['recurrenceStartDate'] as DateTime?;
          _task!.recurrenceEndDate = result['recurrenceEndDate'] as DateTime?;
          _task!.recurrenceCount = result['recurrenceCount'] as int?;

          // Show recurrence section
          _visibleOptionalFields.add(keyRecurrence);
        }
      });

      // Save changes immediately
      await _saveTaskImmediately();
    }
  }

  DetailTableRowData _buildRecurrenceSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.recurrenceLabel),
        icon: Icons.repeat,
        widget: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
          onTap: _openRecurrenceDialog,
          child: Row(
            children: [
              // Main Content Section
              Expanded(
                child: Text(
                  _getRecurrenceSummaryText(),
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _task!.recurrenceType == RecurrenceType.none
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                        : null,
                  ),
                ),
              ),
              // Edit Icon Section
              Icon(SharedUiConstants.editIcon, size: AppTheme.iconSizeSmall, color: AppTheme.secondaryTextColor),
            ],
          ),
        ),
      );

  Widget _buildDescriptionSection() => DetailTable(
        forceVertical: true,
        rowData: [
          DetailTableRowData(
            label: _translationService.translate(TaskTranslationKeys.descriptionLabel),
            icon: TaskUiConstants.descriptionIcon,
            widget: MarkdownEditor(
              controller: _descriptionController,
              onChanged: _onDescriptionChanged,
              height: 250,
            ),
            removePadding: true,
          ),
        ],
        isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
      );

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
      case keyPlannedDateReminder:
        return _translationService.translate(TaskTranslationKeys.reminderPlannedLabel);
      case keyDeadlineDateReminder:
        return _translationService.translate(TaskTranslationKeys.reminderDeadlineLabel);
      case keyRecurrence:
        return _translationService.translate(TaskTranslationKeys.recurrenceLabel);
      case keyParentTask:
        return _translationService.translate(TaskTranslationKeys.parentTaskLabel);
      default:
        return '';
    }
  }

  // Get icon for field chips
  IconData _getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return TagUiConstants.tagIcon;
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
      case keyPlannedDateReminder:
        return Icons.notifications;
      case keyDeadlineDateReminder:
        return Icons.notifications;
      case keyRecurrence:
        return Icons.repeat;
      case keyParentTask:
        return TaskUiConstants.parentTaskIcon;
      default:
        return Icons.add;
    }
  }

  DetailTableRowData _buildParentTaskSection() => DetailTableRowData(
        label: _translationService.translate(TaskTranslationKeys.parentTaskLabel),
        icon: TaskUiConstants.parentTaskIcon,
        widget: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
          onTap: () => _navigateToParentTask(),
          child: Row(
            children: [
              // Main Content Section
              Expanded(
                child: Text(
                  _task!.parentTask?.title ?? '',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Navigate Icon Section
              Icon(
                Icons.open_in_new,
                size: AppTheme.iconSizeSmall,
                color: AppTheme.secondaryTextColor,
              ),
            ],
          ),
        ),
      );

  void _navigateToParentTask() {
    if (_task?.parentTask == null) return;

    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.large,
      child: TaskDetailsPage(
        taskId: _task!.parentTask!.id,
        hideSidebar: true,
        onTaskDeleted: () {
          // Refresh current task when parent is deleted
          _getTask();
          Navigator.of(context).pop();
        },
        onTaskCompleted: () {
          // Refresh current task when parent is completed
          _getTask();
        },
      ),
    );
  }
}
