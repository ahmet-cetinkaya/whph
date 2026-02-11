import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show DateTimeHelper, WeekDays;
import 'package:whph/core/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/commands/update_task_tags_order_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:domain/features/tasks/models/recurrence_configuration.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/features/tags/services/tags_service.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';

/// Controller for task details business logic.
/// Separates data management and operations from UI concerns.
class TaskDetailsController extends ChangeNotifier {
  final Mediator _mediator;
  final TasksService _tasksService;
  final ITranslationService _translationService;
  final ITaskRecurrenceService _taskRecurrenceService;
  final TagsService _tagsService;

  // Task state
  GetTaskQueryResponse? _task;
  GetListTaskTagsQueryResponse? _taskTags;
  Timer? _debounce;

  // Track date picker interaction state
  bool _isPlannedDatePickerActive = false;
  bool _isDeadlineDatePickerActive = false;
  bool _isTitleFieldActive = false;
  bool _isDescriptionFieldActive = false;

  // Time tracking
  Duration _timeSinceLastSave = Duration.zero;

  // Optional field visibility
  final Set<String> _visibleOptionalFields = {};

  // Field keys
  static const String keyTags = 'tags';
  static const String keyPriority = 'priority';
  static const String keyEstimatedTime = 'estimatedTime';
  static const String keyElapsedTime = 'elapsedTime';
  static const String keyPlannedDate = 'plannedDate';
  static const String keyDeadlineDate = 'deadlineDate';
  static const String keyDescription = 'description';
  static const String keyPlannedDateReminder = 'plannedDateReminder';
  static const String keyDeadlineDateReminder = 'deadlineDateReminder';
  static const String keyRecurrence = 'recurrence';
  static const String keyParentTask = 'parentTask';
  static const String keyTimer = 'timer';

  // Callbacks
  VoidCallback? onTaskUpdated;
  Function(String)? onTitleUpdated;
  Function(bool)? onCompletedChanged;

  TaskDetailsController({
    Mediator? mediator,
    TasksService? tasksService,
    ITranslationService? translationService,
    ITaskRecurrenceService? taskRecurrenceService,
    TagsService? tagsService,
  })  : _mediator = mediator ?? container.resolve<Mediator>(),
        _tasksService = tasksService ?? container.resolve<TasksService>(),
        _translationService = translationService ?? container.resolve<ITranslationService>(),
        _taskRecurrenceService = taskRecurrenceService ?? container.resolve<ITaskRecurrenceService>(),
        _tagsService = tagsService ?? container.resolve<TagsService>();

  // Getters
  GetTaskQueryResponse? get task => _task;
  GetListTaskTagsQueryResponse? get taskTags => _taskTags;
  Set<String> get visibleOptionalFields => _visibleOptionalFields;
  bool get isPlannedDatePickerActive => _isPlannedDatePickerActive;
  bool get isDeadlineDatePickerActive => _isDeadlineDatePickerActive;
  bool get isTitleFieldActive => _isTitleFieldActive;
  ITranslationService get translationService => _translationService;
  ITaskRecurrenceService get taskRecurrenceService => _taskRecurrenceService;

  /// Initialize controller with task ID
  Future<void> initialize(String taskId) async {
    await loadTask(taskId);
    await loadTaskTags(taskId);
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _tasksService.onTaskUpdated.addListener(_handleTaskServiceUpdate);
    _tasksService.onTaskDeleted.addListener(_handleTaskDeleted);
    _tagsService.onTagUpdated.addListener(_handleTagUpdated);
  }

  void _handleTaskServiceUpdate() {
    // This will be called when task is updated externally
    notifyListeners();
  }

  void _handleTaskDeleted() {
    if (_tasksService.onTaskDeleted.value == _task?.id) {
      _isDeleted = true;
      notifyListeners();
    }
  }

  void _handleTagUpdated() {
    notifyListeners();
  }

  // Track deletion state to prevent saving after deletion
  bool _isDeleted = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _tasksService.onTaskUpdated.removeListener(_handleTaskServiceUpdate);
    _tasksService.onTaskDeleted.removeListener(_handleTaskDeleted);
    _tagsService.onTagUpdated.removeListener(_handleTagUpdated);
    super.dispose();
  }

  /// Load task data
  Future<void> loadTask(String taskId) async {
    if (_isDatePickerInteractionActive()) return;
    if (_isTitleFieldActive || _isDescriptionFieldActive) return;

    final query = GetTaskQuery(id: taskId);
    final response = await _mediator.send<GetTaskQuery, GetTaskQueryResponse>(query);

    // Check if fields became active during the async operation
    if (_isTitleFieldActive || _isDescriptionFieldActive) return;

    _task = response;
    _processFieldVisibility();
    notifyListeners();
  }

  /// Load task tags
  Future<void> loadTaskTags(String taskId) async {
    _taskTags = null;
    int pageIndex = 0;
    const int pageSize = 50;

    while (true) {
      final query = GetListTaskTagsQuery(taskId: taskId, pageIndex: pageIndex, pageSize: pageSize);
      final response = await _mediator.send<GetListTaskTagsQuery, GetListTaskTagsQueryResponse>(query);

      if (_taskTags == null) {
        _taskTags = response;
      } else {
        _taskTags!.items.addAll(response.items);
      }

      if (response.items.length < pageSize) break;
      pageIndex++;
    }
    _processFieldVisibility();
    notifyListeners();
  }

  void _processFieldVisibility() {
    if (_task == null) return;

    if (_hasFieldContent(keyTags)) _visibleOptionalFields.add(keyTags);
    if (_hasFieldContent(keyPriority)) _visibleOptionalFields.add(keyPriority);
    if (_hasFieldContent(keyElapsedTime)) _visibleOptionalFields.add(keyElapsedTime);
    if (_hasFieldContent(keyEstimatedTime)) _visibleOptionalFields.add(keyEstimatedTime);
    if (_hasFieldContent(keyPlannedDate)) _visibleOptionalFields.add(keyPlannedDate);
    if (_hasFieldContent(keyDeadlineDate)) _visibleOptionalFields.add(keyDeadlineDate);
    if (_hasFieldContent(keyDescription)) _visibleOptionalFields.add(keyDescription);
    if (_hasFieldContent(keyRecurrence)) _visibleOptionalFields.add(keyRecurrence);

    if (_visibleOptionalFields.contains(keyPlannedDate)) _visibleOptionalFields.add(keyPlannedDateReminder);
    if (_visibleOptionalFields.contains(keyDeadlineDate)) _visibleOptionalFields.add(keyDeadlineDateReminder);
    if (_hasFieldContent(keyPlannedDateReminder)) _visibleOptionalFields.add(keyPlannedDateReminder);
    if (_hasFieldContent(keyDeadlineDateReminder)) _visibleOptionalFields.add(keyDeadlineDateReminder);

    _visibleOptionalFields.add(keyPlannedDateReminder);
    _visibleOptionalFields.add(keyDeadlineDateReminder);
  }

  bool _hasFieldContent(String fieldKey) {
    if (_task == null) return false;

    switch (fieldKey) {
      case keyTags:
        return _taskTags != null && _taskTags!.items.isNotEmpty;
      case keyPriority:
        return _task!.priority != null;
      case keyEstimatedTime:
        return _task!.estimatedTime != null && _task!.estimatedTime! > 0;
      case keyElapsedTime:
        return _task!.totalDuration > 0;
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

  void toggleOptionalField(String fieldKey) {
    if (_visibleOptionalFields.contains(fieldKey)) {
      _visibleOptionalFields.remove(fieldKey);
    } else {
      _visibleOptionalFields.add(fieldKey);
    }
    notifyListeners();
  }

  bool isFieldVisible(String fieldKey) => _visibleOptionalFields.contains(fieldKey);
  bool shouldShowAsChip(String fieldKey) => !_visibleOptionalFields.contains(fieldKey);

  bool _isDatePickerInteractionActive() => _isPlannedDatePickerActive || _isDeadlineDatePickerActive;

  void setTitleFieldActive(bool active) {
    _isTitleFieldActive = active;
    notifyListeners();
  }

  void setDescriptionFieldActive(bool active) {
    _isDescriptionFieldActive = active;
    notifyListeners();
  }

  /// Save task with debounce
  void saveTaskDebounced() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      saveTaskImmediately();
    });
  }

  /// Save task immediately
  Future<void> saveTaskImmediately() async {
    if (_task == null || _isDeleted) return;

    final saveCommand = buildSaveCommand();
    await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(saveCommand);
    _tasksService.notifyTaskUpdated(_task!.id);
    onTaskUpdated?.call();
  }

  SaveTaskCommand buildSaveCommand({
    String? title,
    String? description,
    DateTime? plannedDate,
    DateTime? deadlineDate,
  }) {
    final recurrenceStartDate =
        _task!.recurrenceStartDate != null ? DateTimeHelper.toUtcDateTime(_task!.recurrenceStartDate!) : null;
    final recurrenceEndDate =
        _task!.recurrenceEndDate != null ? DateTimeHelper.toUtcDateTime(_task!.recurrenceEndDate!) : null;

    return SaveTaskCommand(
      id: _task!.id,
      title: title ?? _task!.title,
      description: description ?? _task!.description,
      plannedDate: plannedDate ?? _task!.plannedDate,
      deadlineDate: deadlineDate ?? _task!.deadlineDate,
      priority: _task!.priority,
      estimatedTime: _task!.estimatedTime,
      completedAt: _task!.completedAt,
      plannedDateReminderTime: _task!.plannedDateReminderTime,
      plannedDateReminderCustomOffset: _task!.plannedDateReminderCustomOffset,
      deadlineDateReminderTime: _task!.deadlineDateReminderTime,
      deadlineDateReminderCustomOffset: _task!.deadlineDateReminderCustomOffset,
      recurrenceType: _task!.recurrenceType,
      recurrenceInterval: _task!.recurrenceInterval,
      recurrenceDays: _taskRecurrenceService.getRecurrenceDays(_task!),
      recurrenceStartDate: recurrenceStartDate,
      recurrenceEndDate: recurrenceEndDate,
      recurrenceCount: _task!.recurrenceCount,
      recurrenceConfiguration: _task!.recurrenceConfiguration,
    );
  }

  // Field update handlers
  void updatePriority(EisenhowerPriority? value) {
    _task!.priority = value;
    notifyListeners();
    saveTaskImmediately();
  }

  void updateEstimatedTime(int value) {
    _task!.estimatedTime = value;
    notifyListeners();
    saveTaskImmediately();
  }

  void updatePlannedDate(DateTime? date) {
    _isPlannedDatePickerActive = true;
    _task!.plannedDate = date;
    if (date != null && _task!.plannedDateReminderTime == ReminderTime.none) {
      _task!.plannedDateReminderTime = ReminderTime.atTime;
    }
    _validateAndAdjustDeadlineDate();
    notifyListeners();
    saveTaskDebounced();
    Timer(const Duration(milliseconds: 100), () {
      _isPlannedDatePickerActive = false;
    });
  }

  void updatePlannedReminder(ReminderTime value, int? customOffset) {
    _task!.plannedDateReminderTime = value;
    _task!.plannedDateReminderCustomOffset = customOffset;
    notifyListeners();
    saveTaskImmediately();
  }

  void updateDeadlineDate(DateTime? date) {
    _isDeadlineDatePickerActive = true;
    _task!.deadlineDate = date;
    if (date != null && _task!.deadlineDateReminderTime == ReminderTime.none) {
      _task!.deadlineDateReminderTime = ReminderTime.atTime;
    }
    notifyListeners();
    saveTaskDebounced();
    Timer(const Duration(milliseconds: 100), () {
      _isDeadlineDatePickerActive = false;
    });
  }

  void updateDeadlineReminder(ReminderTime value, int? customOffset) {
    _task!.deadlineDateReminderTime = value;
    _task!.deadlineDateReminderCustomOffset = customOffset;
    notifyListeners();
    saveTaskImmediately();
  }

  void updateDescription(String value) {
    _isDescriptionFieldActive = true;
    _task!.description = value.trim().isEmpty ? null : value;
    saveTaskDebounced();
  }

  void updateTitle(String value) {
    _isTitleFieldActive = true;
    _task!.title = value;
    onTitleUpdated?.call(value);
    saveTaskDebounced();
  }

  void _validateAndAdjustDeadlineDate() {
    if (_task?.plannedDate != null && _task?.deadlineDate != null) {
      if (_task!.deadlineDate!.isBefore(_task!.plannedDate!)) {
        _task!.deadlineDate = null;
      }
    }
  }

  DateTime getMinimumDeadlineDate() {
    if (_task?.plannedDate != null) {
      final plannedDate = _task!.plannedDate!;
      return DateTime(plannedDate.year, plannedDate.month, plannedDate.day, plannedDate.hour, plannedDate.minute);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // Tag operations
  Future<bool> addTag(String tagId, BuildContext context) async {
    if (!context.mounted) return false;
    final result = await AsyncErrorHandler.execute<AddTaskTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.addTagError),
      operation: () async {
        final command = AddTaskTagCommand(taskId: _task!.id, tagId: tagId);
        return await _mediator.send(command);
      },
      onSuccess: (_) async {
        _tasksService.notifyTaskUpdated(_task!.id);
        await loadTaskTags(_task!.id);
      },
    );
    return result != null;
  }

  Future<bool> removeTag(String id, BuildContext context) async {
    final result = await AsyncErrorHandler.execute<RemoveTaskTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.removeTagError),
      operation: () async {
        final command = RemoveTaskTagCommand(id: id);
        return await _mediator.send(command);
      },
      onSuccess: (_) async {
        _tasksService.notifyTaskUpdated(_task!.id);
        await loadTaskTags(_task!.id);
      },
    );
    return result != null;
  }

  Future<void> processTagChanges(
    List<DropdownOption<String>> tagOptions,
    BuildContext context,
  ) async {
    if (_taskTags == null) return;

    final tagOptionsToAdd =
        tagOptions.where((tagOption) => !_taskTags!.items.any((taskTag) => taskTag.tagId == tagOption.value)).toList();
    final tagsToRemove =
        _taskTags!.items.where((taskTag) => !tagOptions.map((tag) => tag.value).contains(taskTag.tagId)).toList();

    for (final tagOption in tagOptionsToAdd) {
      if (!context.mounted) return;
      await addTag(tagOption.value, context);
    }

    for (final taskTag in tagsToRemove) {
      if (!context.mounted) return;
      await removeTag(taskTag.id, context);
    }

    if (tagOptions.isNotEmpty) {
      final tagOrders = {for (int i = 0; i < tagOptions.length; i++) tagOptions[i].value: i};
      final orderCommand = UpdateTaskTagsOrderCommand(taskId: _task!.id, tagOrders: tagOrders);
      await _mediator.send(orderCommand);
    }

    if (tagOptionsToAdd.isNotEmpty || tagsToRemove.isNotEmpty || tagOptions.isNotEmpty) {
      await loadTaskTags(_task!.id);
      _tasksService.notifyTaskUpdated(_task!.id);
    }
  }

  // Timer operations
  void handleTimerTick(Duration elapsedIncrement) {
    _timeSinceLastSave += elapsedIncrement;
    if (_timeSinceLastSave.inSeconds >= TaskUiConstants.kPeriodicSaveIntervalSeconds) {
      saveTaskTime(_timeSinceLastSave);
      _timeSinceLastSave = Duration.zero;
    }
  }

  void saveTaskTime(Duration elapsed) {
    if (_task?.id == null) return;
    if (elapsed.inSeconds <= 0) return;

    final command = AddTaskTimeRecordCommand(
      duration: elapsed.inSeconds,
      taskId: _task!.id,
      customDateTime: DateTime.now(),
    );
    _mediator.send(command);
    _tasksService.notifyTaskUpdated(_task!.id);
  }

  void onWorkSessionComplete(Duration totalElapsed) {
    if (_timeSinceLastSave > Duration.zero) {
      saveTaskTime(_timeSinceLastSave);
      _timeSinceLastSave = Duration.zero;
    }
  }

  void onTimerStop(Duration totalElapsed) {
    if (_timeSinceLastSave > Duration.zero) {
      saveTaskTime(_timeSinceLastSave);
      _timeSinceLastSave = Duration.zero;
    }
  }

  // Time logging dialog
  Future<void> logTime({
    required BuildContext context,
    required bool isSetTotalMode,
    required int durationInSeconds,
    required DateTime date,
  }) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      operation: () async {
        if (isSetTotalMode) {
          await _mediator.send(SaveTaskTimeRecordCommand(
            taskId: _task!.id,
            duration: durationInSeconds,
            targetDate: date,
          ));
        } else {
          await _mediator.send(AddTaskTimeRecordCommand(
            taskId: _task!.id,
            duration: durationInSeconds,
            customDateTime: date,
          ));
        }
      },
      onSuccess: () {
        _tasksService.notifyTaskUpdated(_task!.id);
      },
    );
  }

  // Recurrence operations
  void updateRecurrence({
    RecurrenceConfiguration? recurrenceConfiguration,
    DateTime? recurrenceStartDate,
  }) {
    _task!.recurrenceConfiguration = recurrenceConfiguration;
    _task!.recurrenceStartDate = recurrenceStartDate;

    // Sync legacy fields for backward compatibility
    if (recurrenceConfiguration == null) {
      _task!.recurrenceType = RecurrenceType.none;
      _task!.recurrenceInterval = null;
      _task!.setRecurrenceDays(null);
      _task!.recurrenceEndDate = null;
      _task!.recurrenceCount = null;
      _visibleOptionalFields.remove(keyRecurrence);
    } else {
      switch (recurrenceConfiguration.frequency) {
        case RecurrenceFrequency.daily:
          _task!.recurrenceType = RecurrenceType.daily;
          break;
        case RecurrenceFrequency.weekly:
          if (recurrenceConfiguration.daysOfWeek != null && recurrenceConfiguration.daysOfWeek!.isNotEmpty) {
            _task!.recurrenceType = RecurrenceType.daysOfWeek;
          } else {
            _task!.recurrenceType = RecurrenceType.weekly;
          }
          break;
        case RecurrenceFrequency.monthly:
          _task!.recurrenceType = RecurrenceType.monthly;
          break;
        case RecurrenceFrequency.yearly:
          _task!.recurrenceType = RecurrenceType.yearly;
          break;
        case RecurrenceFrequency.hourly:
          _task!.recurrenceType = RecurrenceType.hourly;
          break;
        case RecurrenceFrequency.minutely:
          _task!.recurrenceType = RecurrenceType.minutely;
          break;
      }

      _task!.recurrenceInterval = recurrenceConfiguration.interval;

      if (recurrenceConfiguration.daysOfWeek != null) {
        final days = recurrenceConfiguration.daysOfWeek!.map((d) => WeekDays.values[d - 1]).toList();
        _task!.setRecurrenceDays(days);
      } else {
        // If generic weekly without specific days, we might want null or empty string.
        // Legacy 'weekly' means every X weeks. Legacy 'daysOfWeek' means every X weeks on [days].
        // setRecurrenceDays(null) clears it.
        _task!.setRecurrenceDays(null);
      }

      _task!.recurrenceEndDate = recurrenceConfiguration.endDate;
      _task!.recurrenceCount = recurrenceConfiguration.occurrenceCount;
      _visibleOptionalFields.add(keyRecurrence);
    }

    notifyListeners();
    saveTaskImmediately();
  }

  String getRecurrenceSummaryText() {
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
      case RecurrenceType.daysOfWeek:
        final days = _taskRecurrenceService.getRecurrenceDays(_task!);
        if (days != null && days.isNotEmpty) {
          if (days.length == WeekDays.values.length && WeekDays.values.every((weekDay) => days.contains(weekDay))) {
            summary = _translationService.translate(TaskTranslationKeys.everyDay);
          } else {
            final dayNames = days
                .map((day) => _translationService
                    .translate(SharedTranslationKeys.getWeekDayNameTranslationKey(day.name, short: true)))
                .join(', ');
            summary = dayNames;
          }
        } else {
          summary = _translationService.translate(TaskTranslationKeys.recurrenceDaysOfWeek);
        }
        break;
      case RecurrenceType.weekly:
        summary = _translationService.translate(TaskTranslationKeys.recurrenceWeekly);
        if (_task!.recurrenceInterval != null && _task!.recurrenceInterval! > 1) {
          summary +=
              ' (${_translationService.translate(TaskTranslationKeys.recurrenceIntervalPrefix)} ${_task!.recurrenceInterval} ${_translationService.translate(TaskTranslationKeys.recurrenceIntervalSuffixWeeks)})';
        }
        break;
      case RecurrenceType.monthly:
        if (_task!.recurrenceConfiguration?.monthlyPatternType == MonthlyPatternType.relativeDay) {
          final config = _task!.recurrenceConfiguration!;
          final weekModifierKey = switch (config.weekOfMonth) {
            1 => TaskTranslationKeys.recurrenceWeekModifierFirst,
            2 => TaskTranslationKeys.recurrenceWeekModifierSecond,
            3 => TaskTranslationKeys.recurrenceWeekModifierThird,
            4 => TaskTranslationKeys.recurrenceWeekModifierFourth,
            _ => TaskTranslationKeys.recurrenceWeekModifierLast,
          };

          final dayName = _translationService
              .translate(SharedTranslationKeys.getWeekDayTranslationKey(config.dayOfWeek!, short: false));

          summary =
              '${_translationService.translate(TaskTranslationKeys.recurrenceOnThe)} ${_translationService.translate(weekModifierKey)} $dayName';
        } else if (_task!.recurrenceConfiguration?.monthlyPatternType == MonthlyPatternType.specificDay &&
            _task!.recurrenceConfiguration!.dayOfMonth != null) {
          summary =
              '${_translationService.translate(TaskTranslationKeys.recurrenceOnThe)} ${_task!.recurrenceConfiguration!.dayOfMonth}${_translationService.translate(TaskTranslationKeys.recurrenceDaySuffix)}';
        } else {
          summary = _translationService.translate(TaskTranslationKeys.recurrenceMonthly);
        }

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
      case RecurrenceType.hourly:
        summary = _translationService.translate(TaskTranslationKeys.recurrenceHourly);
        if (_task!.recurrenceInterval != null && _task!.recurrenceInterval! > 1) {
          summary +=
              ' (${_translationService.translate(TaskTranslationKeys.recurrenceIntervalPrefix)} ${_task!.recurrenceInterval} ${_translationService.translate(TaskTranslationKeys.recurrenceIntervalSuffixHours)})';
        }
        break;
      case RecurrenceType.minutely:
        summary = _translationService.translate(TaskTranslationKeys.recurrenceMinutely);
        if (_task!.recurrenceInterval != null && _task!.recurrenceInterval! > 1) {
          summary +=
              ' (${_translationService.translate(TaskTranslationKeys.recurrenceIntervalPrefix)} ${_task!.recurrenceInterval} ${_translationService.translate(TaskTranslationKeys.recurrenceIntervalSuffixMinutes)})';
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

  void toggleTaskCompletion() {
    if (_task!.isCompleted) {
      _task!.markNotCompleted();
    } else {
      _task!.markCompleted();
    }
    onCompletedChanged?.call(_task!.isCompleted);
    notifyListeners();
  }
}
