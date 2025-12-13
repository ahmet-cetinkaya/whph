import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show DateTimeHelper;
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'helpers/habit_data_loader.dart';
import 'helpers/habit_tag_operations.dart';
import 'helpers/habit_record_operations.dart';
import 'helpers/habit_dialog_helper.dart';

/// Controller for habit details business logic.
/// Separates data management and operations from UI concerns.
class HabitDetailsController extends ChangeNotifier {
  final Mediator _mediator;
  final HabitsService _habitsService;
  final ITranslationService _translationService;

  // Helpers
  late final HabitDataLoader _dataLoader;
  late final HabitTagOperations _tagOperations;
  late final HabitRecordOperations _recordOperations;
  late final HabitDialogHelper _dialogHelper;

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
        _translationService = translationService ?? container.resolve<ITranslationService>() {
    final resolvedSoundManager = soundManagerService ?? container.resolve<ISoundManagerService>();

    _dataLoader = HabitDataLoader(mediator: _mediator, translationService: _translationService);
    _tagOperations = HabitTagOperations(
      mediator: _mediator,
      translationService: _translationService,
      habitsService: _habitsService,
    );
    _recordOperations = HabitRecordOperations(
      mediator: _mediator,
      translationService: _translationService,
      soundManagerService: resolvedSoundManager,
      habitsService: _habitsService,
    );
    _dialogHelper = HabitDialogHelper(translationService: _translationService);
  }

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

  // Data loading methods (delegated to helper)
  Future<void> loadHabit(String habitId, BuildContext context) async {
    final result = await _dataLoader.loadHabit(habitId, context);
    if (result != null) {
      if (_habit == null) {
        _habit = result;
      } else {
        _updateHabitFields(result);
      }
      _ensureValidReminderSettings();
      _processFieldVisibility();
      notifyListeners();
    }
  }

  void _updateHabitFields(GetHabitQueryResponse result) {
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

  Future<void> loadHabitStatisticsOnly(String habitId, BuildContext context) async {
    final result = await _dataLoader.loadHabit(habitId, context);
    if (result != null && _habit != null) {
      _updateHabitFields(result);
      notifyListeners();
    }
  }

  Future<void> loadHabitRecordsForMonth(DateTime month, String habitId, BuildContext context) async {
    final result = await _dataLoader.loadHabitRecordsForMonth(month, habitId, context);
    if (result != null) {
      _habitRecords = result;
      notifyListeners();
    }
  }

  Future<void> loadHabitTags(String habitId, BuildContext context) async {
    final existingTagIds = _habitTags?.items.map((tag) => tag.tagId).toSet() ?? <String>{};
    final result = await _dataLoader.loadHabitTags(habitId, context);

    if (result != null) {
      final newTagIds = result.items.map((tag) => tag.tagId).toSet();
      if (_forceTagsRefresh ||
          _habitTags == null ||
          existingTagIds.length != newTagIds.length ||
          !existingTagIds.containsAll(newTagIds)) {
        _habitTags = result;
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

  Future<void> refreshTotalDuration(String habitId) async {
    final newDuration = await _dataLoader.refreshTotalDuration(habitId);
    if (_totalDuration != newDuration) {
      _totalDuration = newDuration;
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

  // Tag operations (delegated to helper)
  Future<bool> addTag(String tagId, String habitId, BuildContext context) async {
    final success = await _tagOperations.addTag(tagId, habitId, context);
    if (success) {
      _forceTagsRefresh = true;
      if (!context.mounted) return false;
      await loadHabitTags(habitId, context);
      return true;
    }
    return false;
  }

  Future<bool> removeTag(String id, String habitId, BuildContext context) async {
    final success = await _tagOperations.removeTag(id, context);
    if (success) {
      _forceTagsRefresh = true;
      if (!context.mounted) return false;
      await loadHabitTags(habitId, context);
      return true;
    }
    return false;
  }

  Future<void> processTagChanges(List<DropdownOption<String>> tagOptions, String habitId, BuildContext context) async {
    await _tagOperations.processTagChanges(
      tagOptions: tagOptions,
      habitId: habitId,
      context: context,
      currentTags: _habitTags,
      reloadTags: loadHabitTags,
    );
  }

  // Record operations (delegated to helper)
  Future<void> createHabitRecord(String habitId, DateTime date, BuildContext context) async {
    await _recordOperations.createHabitRecord(
      habitId: habitId,
      date: date,
      context: context,
      onSuccess: () {
        loadHabitRecordsForMonth(_currentMonth, habitId, context);
        loadHabitStatisticsOnly(habitId, context);
        onHabitUpdated?.call();
      },
    );
  }

  Future<void> deleteAllHabitRecordsForDay(DateTime date, String habitId, BuildContext context) async {
    await _recordOperations.deleteAllHabitRecordsForDay(
      date: date,
      habitId: habitId,
      context: context,
      onSuccess: () async {
        if (context.mounted) await loadHabitRecordsForMonth(_currentMonth, habitId, context);
        if (context.mounted) await loadHabitStatisticsOnly(habitId, context);
        if (context.mounted) await refreshTotalDuration(habitId);
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

  // Timer operations (delegated to helper)
  void onTimerStop(Duration totalElapsed, String habitId) {
    if (_habit?.id == null) return;
    _recordOperations.onTimerStop(totalElapsed, habitId);
  }

  Future<void> logTime({
    required BuildContext context,
    required String habitId,
    required bool isSetTotalMode,
    required int durationInSeconds,
    required DateTime date,
  }) async {
    await _recordOperations.logTime(
      context: context,
      habitId: habitId,
      isSetTotalMode: isSetTotalMode,
      durationInSeconds: durationInSeconds,
      date: date,
    );
  }

  int getTodayRecordCount() {
    if (_habitRecords == null) return 0;
    return _habitRecords!.items.where((record) => DateTimeHelper.isSameDay(record.date, DateTime.now())).length;
  }

  // Dialog operations (delegated to helper)
  String getReminderSummaryText() => _dialogHelper.getReminderSummaryText(_habit);

  Future<void> openReminderDialog(BuildContext context, String habitId) async {
    if (_habit == null) return;

    final result = await _dialogHelper.openReminderDialog(context, _habit!);
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

  Future<void> openGoalDialog(BuildContext context, String habitId) async {
    if (_habit == null) return;

    final result = await _dialogHelper.openGoalDialog(context, _habit!);
    if (result != null && context.mounted) {
      _habit!.hasGoal = result.hasGoal;
      _habit!.dailyTarget = result.dailyTarget;
      if (result.hasGoal) {
        if (result.targetFrequency != null) _habit!.targetFrequency = result.targetFrequency!;
        if (result.periodDays != null) _habit!.periodDays = result.periodDays!;
      }
      await saveHabitImmediately(habitId, context);
      notifyListeners();
    }
  }
}
