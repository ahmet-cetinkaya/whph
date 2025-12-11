import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show DateTimeHelper, ResponsiveDialogHelper, DialogSize;
import 'package:whph/core/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/commands/remove_habit_tag_command.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_goal_dialog.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_reminder_settings_dialog.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

/// Controller for habit details business logic.
/// Separates data management and operations from UI concerns.
class HabitDetailsController extends ChangeNotifier {
  final Mediator _mediator;
  final HabitsService _habitsService;
  final ITranslationService _translationService;
  final ISoundManagerService _soundManagerService;

  // Habit state
  GetHabitQueryResponse? _habit;
  GetListHabitRecordsQueryResponse? _habitRecords;
  GetListHabitTagsQueryResponse? _habitTags;
  Timer? _debounce;
  bool _isNameFieldActive = false;
  bool _forceTagsRefresh = false;
  int _totalDuration = 0;
  DateTime _currentMonth = DateTime.now();

  // Optional field visibility
  final Set<String> _visibleOptionalFields = {};

  // Field keys
  static const String keyTags = 'tags';
  static const String keyEstimatedTime = 'estimatedTime';
  static const String keyElapsedTime = 'elapsedTime';
  static const String keyTimer = 'timer';
  static const String keyDescription = 'description';
  static const String keyReminder = 'reminder';
  static const String keyGoal = 'goal';

  // Callbacks
  VoidCallback? onHabitUpdated;
  Function(String)? onNameUpdated;

  HabitDetailsController({
    Mediator? mediator,
    HabitsService? habitsService,
    ITranslationService? translationService,
    ISoundManagerService? soundManagerService,
  })  : _mediator = mediator ?? container.resolve<Mediator>(),
        _habitsService = habitsService ?? container.resolve<HabitsService>(),
        _translationService = translationService ?? container.resolve<ITranslationService>(),
        _soundManagerService = soundManagerService ?? container.resolve<ISoundManagerService>();

  // Getters
  GetHabitQueryResponse? get habit => _habit;
  GetListHabitRecordsQueryResponse? get habitRecords => _habitRecords;
  GetListHabitTagsQueryResponse? get habitTags => _habitTags;
  Set<String> get visibleOptionalFields => _visibleOptionalFields;
  bool get isNameFieldActive => _isNameFieldActive;
  int get totalDuration => _totalDuration;
  DateTime get currentMonth => _currentMonth;
  ITranslationService get translationService => _translationService;
  HabitsService get habitsService => _habitsService;

  /// Initialize controller with habit ID
  Future<void> initialize(String habitId, BuildContext context) async {
    if (context.mounted) await loadHabit(habitId, context);
    if (context.mounted) await loadHabitRecordsForMonth(_currentMonth, habitId, context);
    if (context.mounted) await loadHabitTags(habitId, context);
    if (context.mounted) await refreshTotalDuration(habitId);
    if (context.mounted) _setupEventListeners(habitId, context);
  }

  void _setupEventListeners(String habitId, BuildContext context) {
    _habitsService.onHabitUpdated.addListener(() => _handleHabitUpdated(habitId, context));
    _habitsService.onHabitRecordAdded.addListener(() => _handleHabitRecordChanged(habitId, context));
    _habitsService.onHabitRecordRemoved.addListener(() => _handleHabitRecordChanged(habitId, context));
  }

  void _handleHabitUpdated(String habitId, BuildContext context) {
    if (_habitsService.onHabitUpdated.value != habitId) return;
    if (_isNameFieldActive) return;
    loadHabit(habitId, context);
    loadHabitTags(habitId, context);
  }

  void _handleHabitRecordChanged(String habitId, BuildContext context) {
    final addedHabitId = _habitsService.onHabitRecordAdded.value;
    final removedHabitId = _habitsService.onHabitRecordRemoved.value;
    if (addedHabitId != habitId && removedHabitId != habitId) return;

    loadHabitRecordsForMonth(_currentMonth, habitId, context);
    loadHabitStatisticsOnly(habitId, context);
    refreshTotalDuration(habitId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void setNameFieldActive(bool active) {
    _isNameFieldActive = active;
    notifyListeners();
  }

  // Data loading methods
  Future<void> loadHabit(String habitId, BuildContext context) async {
    await AsyncErrorHandler.execute<GetHabitQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingDetailsError),
      operation: () async {
        final query = GetHabitQuery(id: habitId);
        return await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
      },
      onSuccess: (result) {
        if (_habit == null) {
          _habit = result;
        } else {
          _habit!.name = result.name;
          _habit!.description = result.description;
          _habit!.estimatedTime = result.estimatedTime;
          _habit!.hasReminder = result.hasReminder;
          _habit!.reminderTime = result.reminderTime;
          _habit!.reminderDays = result.reminderDays;
          _habit!.hasGoal = result.hasGoal;
          _habit!.targetFrequency = result.targetFrequency;
          _habit!.periodDays = result.periodDays;
          _habit!.archivedDate = result.archivedDate;
        }
        _ensureValidReminderSettings();
        _processFieldVisibility();
        notifyListeners();
      },
    );
  }

  Future<void> loadHabitStatisticsOnly(String habitId, BuildContext context) async {
    await AsyncErrorHandler.execute<GetHabitQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingDetailsError),
      operation: () async {
        final query = GetHabitQuery(id: habitId);
        return await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
      },
      onSuccess: (result) {
        if (_habit != null) {
          _habit!.name = result.name;
          _habit!.description = result.description;
          _habit!.estimatedTime = result.estimatedTime;
          _habit!.hasReminder = result.hasReminder;
          _habit!.reminderTime = result.reminderTime;
          _habit!.reminderDays = result.reminderDays;
          _habit!.hasGoal = result.hasGoal;
          _habit!.targetFrequency = result.targetFrequency;
          _habit!.periodDays = result.periodDays;
          _habit!.archivedDate = result.archivedDate;
        }
        notifyListeners();
      },
    );
  }

  Future<void> loadHabitRecordsForMonth(DateTime month, String habitId, BuildContext context) async {
    await AsyncErrorHandler.execute<GetListHabitRecordsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingRecordsError),
      operation: () async {
        final firstDayOfMonth = DateTime(month.year, month.month, 1);
        final firstWeekdayOfMonth = firstDayOfMonth.weekday;
        final previousMonthDays = firstWeekdayOfMonth - 1;
        final firstDisplayedDate = firstDayOfMonth.subtract(Duration(days: previousMonthDays));

        final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
        final lastWeekdayOfMonth = lastDayOfMonth.weekday;
        final nextMonthDays = 7 - lastWeekdayOfMonth;
        final lastDisplayedDate = lastDayOfMonth.add(Duration(days: nextMonthDays));

        final query = GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: 50,
          habitId: habitId,
          startDate: firstDisplayedDate.toUtc(),
          endDate: lastDisplayedDate.toUtc(),
        );
        return await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
      },
      onSuccess: (result) {
        _habitRecords = result;
        notifyListeners();
      },
    );
  }

  Future<void> loadHabitTags(String habitId, BuildContext context) async {
    int pageIndex = 0;
    const int pageSize = 50;
    final existingTagIds = _habitTags?.items.map((tag) => tag.tagId).toSet() ?? <String>{};
    GetListHabitTagsQueryResponse? newHabitTags;

    while (true) {
      final query = GetListHabitTagsQuery(habitId: habitId, pageIndex: pageIndex, pageSize: pageSize);
      final result = await AsyncErrorHandler.execute<GetListHabitTagsQueryResponse>(
        context: context,
        errorMessage: _translationService.translate(HabitTranslationKeys.loadingTagsError),
        operation: () async => await _mediator.send<GetListHabitTagsQuery, GetListHabitTagsQueryResponse>(query),
        onSuccess: (response) {
          if (newHabitTags == null) {
            newHabitTags = response;
          } else {
            newHabitTags!.items.addAll(response.items);
          }
        },
      );

      if (result == null || result.items.isEmpty || result.items.length < pageSize) break;
      pageIndex++;
    }

    if (newHabitTags != null) {
      final newTagIds = newHabitTags!.items.map((tag) => tag.tagId).toSet();
      if (_forceTagsRefresh ||
          _habitTags == null ||
          existingTagIds.length != newTagIds.length ||
          !existingTagIds.containsAll(newTagIds)) {
        _habitTags = newHabitTags;
        _forceTagsRefresh = false;
        _processFieldVisibility();
        notifyListeners();
      }
    } else if (_habitTags == null) {
      _habitTags = GetListHabitTagsQueryResponse(items: [], pageIndex: 0, pageSize: 50, totalItemCount: 0);
      _processFieldVisibility();
      notifyListeners();
    }
  }

  void _ensureValidReminderSettings() {
    if (_habit == null || !_habit!.hasReminder) return;

    if (_habit!.reminderTime == null) {
      _habit!.setReminderTimeOfDay(TimeOfDay.now());
    }
    if (_habit!.reminderDays.isEmpty) {
      final allDays = List.generate(7, (index) => index + 1);
      _habit!.setReminderDaysFromList(allDays);
    }
  }

  // Field visibility
  void _processFieldVisibility() {
    if (_habit == null) return;

    if (_hasFieldContent(keyTags)) _visibleOptionalFields.add(keyTags);
    if (_hasFieldContent(keyEstimatedTime)) _visibleOptionalFields.add(keyEstimatedTime);
    if (_hasFieldContent(keyElapsedTime)) _visibleOptionalFields.add(keyElapsedTime);
    if (_hasFieldContent(keyTimer)) _visibleOptionalFields.add(keyTimer);
    if (_hasFieldContent(keyDescription)) _visibleOptionalFields.add(keyDescription);
    if (_hasFieldContent(keyReminder)) _visibleOptionalFields.add(keyReminder);
    if (_hasFieldContent(keyGoal)) _visibleOptionalFields.add(keyGoal);
  }

  bool _hasFieldContent(String fieldKey) {
    if (_habit == null) return false;

    switch (fieldKey) {
      case keyTags:
        return _habitTags != null && _habitTags!.items.isNotEmpty;
      case keyEstimatedTime:
        return _habit!.estimatedTime != null && _habit!.estimatedTime! > 0;
      case keyDescription:
        return _habit!.description.isNotEmpty;
      case keyReminder:
        return _habit!.hasReminder;
      case keyGoal:
        return _habit!.hasGoal;
      case keyElapsedTime:
        return _totalDuration > 0;
      case keyTimer:
        return false;
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
  bool shouldShowAsChip(String fieldKey) => !_visibleOptionalFields.contains(fieldKey) && !_hasFieldContent(fieldKey);

  // Save operations
  void saveHabitDebounced(String habitId, BuildContext context, {String? name}) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(SharedUiConstants.contentSaveDebounceTime, () {
      saveHabitImmediately(habitId, context, name: name);
    });
  }

  Future<void> saveHabitImmediately(String habitId, BuildContext context, {String? name}) async {
    if (_habit == null) return;

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.savingDetailsError),
      operation: () async {
        final command = _buildSaveCommand(habitId, name: name);
        await _mediator.send(command);
      },
      onSuccess: () {
        _habitsService.notifyHabitUpdated(habitId);
        onHabitUpdated?.call();
        notifyListeners();
      },
    );
  }

  SaveHabitCommand _buildSaveCommand(String habitId, {String? name, String? description}) {
    final reminderDaysList = _habit!.hasReminder ? _habit!.getReminderDaysAsList() : <int>[];

    if (_habit!.hasReminder && reminderDaysList.isEmpty) {
      final allDays = List.generate(7, (index) => index + 1);
      _habit!.setReminderDaysFromList(allDays);
    }

    if (_habit!.hasReminder) {
      if (_habit!.reminderTime == null) {
        _habit!.setReminderTimeOfDay(TimeOfDay.now());
      }
      if (_habit!.reminderDays.isEmpty) {
        final allDays = List.generate(7, (index) => index + 1);
        _habit!.setReminderDaysFromList(allDays);
      }
    }

    final List<int> reminderDaysToSend = _habit!.hasReminder ? _habit!.getReminderDaysAsList() : [];

    return SaveHabitCommand(
      id: habitId,
      name: name ?? _habit!.name,
      description: description ?? _habit!.description,
      estimatedTime: _habit!.estimatedTime,
      hasReminder: _habit!.hasReminder,
      reminderTime: _habit!.reminderTime,
      reminderDays: reminderDaysToSend,
      hasGoal: _habit!.hasGoal,
      targetFrequency: _habit!.targetFrequency,
      periodDays: _habit!.periodDays,
      dailyTarget: _habit!.dailyTarget,
    );
  }

  // Field updates
  void updateName(String value, String habitId, BuildContext context) {
    _isNameFieldActive = true;
    _habit?.name = value;
    onNameUpdated?.call(value);
    saveHabitDebounced(habitId, context, name: value);
  }

  void updateDescription(String value, String habitId, BuildContext context) {
    _habit?.description = value;
    saveHabitDebounced(habitId, context);
  }

  void updateEstimatedTime(int value, String habitId, BuildContext context) {
    _habit?.estimatedTime = value;
    saveHabitDebounced(habitId, context);
    notifyListeners();
  }

  // Tag operations
  Future<bool> addTag(String tagId, String habitId, BuildContext context) async {
    final result = await AsyncErrorHandler.execute<AddHabitTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.addingTagError),
      operation: () async {
        final command = AddHabitTagCommand(habitId: habitId, tagId: tagId);
        return await _mediator.send(command);
      },
    );

    if (result != null) {
      _forceTagsRefresh = true;
      if (!context.mounted) return false;
      await loadHabitTags(habitId, context);
      return true;
    }
    return false;
  }

  Future<bool> removeTag(String id, String habitId, BuildContext context) async {
    final result = await AsyncErrorHandler.execute<RemoveHabitTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.removingTagError),
      operation: () async {
        final command = RemoveHabitTagCommand(id: id);
        return await _mediator.send(command);
      },
    );

    if (result != null) {
      _forceTagsRefresh = true;
      if (!context.mounted) return false;
      await loadHabitTags(habitId, context);
      return true;
    }
    return false;
  }

  Future<void> processTagChanges(List<DropdownOption<String>> tagOptions, String habitId, BuildContext context) async {
    if (_habitTags == null) return;

    final tagsToAdd = tagOptions
        .where((tagOption) => !_habitTags!.items.any((habitTag) => habitTag.tagId == tagOption.value))
        .map((option) => option.value)
        .toList();

    final tagsToRemove =
        _habitTags!.items.where((habitTag) => !tagOptions.map((tag) => tag.value).contains(habitTag.tagId)).toList();

    for (final tagId in tagsToAdd) {
      if (!context.mounted) return;
      await addTag(tagId, habitId, context);
    }

    for (final habitTag in tagsToRemove) {
      if (!context.mounted) return;
      await removeTag(habitTag.id, habitId, context);
    }

    if (tagsToAdd.isNotEmpty || tagsToRemove.isNotEmpty) {
      _habitsService.notifyHabitUpdated(habitId);
    }
  }

  // Record operations
  Future<void> createHabitRecord(String habitId, DateTime date, BuildContext context) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.creatingRecordError),
      operation: () async {
        final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);
      },
      onSuccess: () {
        loadHabitRecordsForMonth(_currentMonth, habitId, context);
        loadHabitStatisticsOnly(habitId, context);
        _soundManagerService.playHabitCompletion();
        _habitsService.notifyHabitRecordAdded(habitId);
        onHabitUpdated?.call();
      },
    );
  }

  Future<void> deleteAllHabitRecordsForDay(DateTime date, String habitId, BuildContext context) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.deletingRecordError),
      operation: () async {
        final command = ToggleHabitCompletionCommand(habitId: habitId, date: date, useIncrementalBehavior: false);
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);
      },
      onSuccess: () async {
        if (context.mounted) await loadHabitRecordsForMonth(_currentMonth, habitId, context);
        if (context.mounted) await loadHabitStatisticsOnly(habitId, context);
        if (context.mounted) await refreshTotalDuration(habitId);
        _habitsService.notifyHabitRecordRemoved(habitId);
        onHabitUpdated?.call();
      },
    );
  }

  // Navigation
  void previousMonth(String habitId, BuildContext context) {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    loadHabitRecordsForMonth(_currentMonth, habitId, context);
    notifyListeners();
  }

  void nextMonth(String habitId, BuildContext context) {
    final now = DateTime.now();
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    if (nextMonth.isAfter(now)) return;

    _currentMonth = nextMonth;
    loadHabitRecordsForMonth(_currentMonth, habitId, context);
    notifyListeners();
  }

  // Timer operations
  void onTimerStop(Duration totalElapsed, String habitId) {
    if (_habit?.id == null) return;
    if (totalElapsed.inSeconds > 0) {
      final command = AddHabitTimeRecordCommand(
        habitId: habitId,
        duration: totalElapsed.inSeconds,
        customDateTime: DateTime.now(),
      );
      _mediator.send(command);
    }
  }

  // Time logging dialog
  Future<void> logTime({
    required BuildContext context,
    required String habitId,
    required bool isSetTotalMode,
    required int durationInSeconds,
    required DateTime date,
  }) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      operation: () async {
        if (isSetTotalMode) {
          await _mediator.send(SaveHabitTimeRecordCommand(
            habitId: habitId,
            totalDuration: durationInSeconds,
            targetDate: date,
          ));
        } else {
          await _mediator.send(AddHabitTimeRecordCommand(
            habitId: habitId,
            duration: durationInSeconds,
            customDateTime: date,
          ));
        }
      },
      onSuccess: () {
        _habitsService.notifyHabitUpdated(habitId);
      },
    );
  }

  // Total duration
  Future<void> refreshTotalDuration(String habitId) async {
    try {
      final query = GetTotalDurationByHabitIdQuery(habitId: habitId);
      final result =
          await _mediator.send<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse>(query);
      if (_totalDuration != result.totalDuration) {
        _totalDuration = result.totalDuration;
        _processFieldVisibility();
        notifyListeners();
      }
    } catch (e) {
      // Keep existing value on error
    }
  }

  int getTodayRecordCount() {
    if (_habitRecords == null) return 0;
    return _habitRecords!.items.where((record) => DateTimeHelper.isSameDay(record.date, DateTime.now())).length;
  }

  // Reminder operations
  String getReminderSummaryText() {
    if (_habit == null || !_habit!.hasReminder) {
      return _translationService.translate(HabitTranslationKeys.noReminder);
    }

    String summary = "";

    if (_habit!.reminderTime != null) {
      final timeOfDay = _habit!.getReminderTimeOfDay();
      if (timeOfDay != null) {
        summary += '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
      }
    }

    final reminderDays = _habit!.getReminderDaysAsList();
    if (reminderDays.isNotEmpty && reminderDays.length < 7) {
      final dayNames = reminderDays.map((dayNum) {
        return _translationService.translate(SharedTranslationKeys.getWeekDayTranslationKey(dayNum, short: true));
      }).join(', ');
      summary += ', $dayNames';
    } else if (reminderDays.length == 7) {
      summary += ', ${_translationService.translate(HabitTranslationKeys.everyDay)}';
    }

    return summary;
  }

  Future<void> openReminderDialog(BuildContext context, String habitId) async {
    if (_habit == null) return;

    final now = DateTime.now();
    final bool isArchived =
        _habit!.archivedDate != null && DateTimeHelper.toLocalDateTime(_habit!.archivedDate!).isBefore(now);

    if (isArchived) return;

    final result = await ResponsiveDialogHelper.showResponsiveDialog<HabitReminderSettingsResult>(
      context: context,
      size: DialogSize.medium,
      child: HabitReminderSettingsDialog(
        hasReminder: _habit!.hasReminder,
        reminderTime: _habit!.getReminderTimeOfDay(),
        reminderDays: _habit!.getReminderDaysAsList(),
        translationService: _translationService,
      ),
    );

    if (result != null && context.mounted) {
      _habit!.hasReminder = result.hasReminder;

      if (_habit!.hasReminder) {
        if (result.reminderTime != null) {
          _habit!.setReminderTimeOfDay(result.reminderTime!);
        }
        _habit!.setReminderDaysFromList(result.reminderDays);
      } else {
        _habit!.reminderTime = null;
      }

      await saveHabitImmediately(habitId, context);
      notifyListeners();
    }
  }

  // Goal operations
  Future<void> openGoalDialog(BuildContext context, String habitId) async {
    if (_habit == null) return;

    final now = DateTime.now();
    final bool isArchived =
        _habit!.archivedDate != null && DateTimeHelper.toLocalDateTime(_habit!.archivedDate!).isBefore(now);

    if (isArchived) return;

    final result = await ResponsiveDialogHelper.showResponsiveDialog<HabitGoalResult>(
      context: context,
      size: DialogSize.large,
      child: HabitGoalDialog(
        hasGoal: _habit!.hasGoal,
        targetFrequency: _habit!.targetFrequency,
        periodDays: _habit!.hasGoal ? _habit!.periodDays : 1,
        dailyTarget: _habit!.dailyTarget ?? 1,
        translationService: _translationService,
      ),
    );

    if (result != null && context.mounted) {
      _habit!.hasGoal = result.hasGoal;
      _habit!.dailyTarget = result.dailyTarget;
      if (result.hasGoal) {
        _habit!.targetFrequency = result.targetFrequency;
        _habit!.periodDays = result.periodDays;
      }
      await saveHabitImmediately(habitId, context);
      notifyListeners();
    }
  }
}
