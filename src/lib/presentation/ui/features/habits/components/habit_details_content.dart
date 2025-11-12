import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show NumericInput, DateTimeHelper;
import 'package:whph/presentation/ui/shared/services/abstraction/i_sound_manager_service.dart';
import 'package:whph/presentation/ui/shared/components/markdown_editor.dart';
import 'package:whph/core/application/features/habits/commands/toggle_habit_completion_command.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/core/application/features/habits/commands/remove_habit_tag_command.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/core/application/features/habits/queries/get_total_duration_by_habit_id_query.dart';
import 'package:whph/presentation/ui/shared/components/time_logging_dialog.dart';
import 'package:whph/presentation/ui/features/tasks/components/timer.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_time_record_command.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_reminder_settings_dialog.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_goal_dialog.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/detail_table.dart';
import 'package:whph/presentation/ui/shared/components/time_display.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_calendar_view.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';

class HabitDetailsContent extends StatefulWidget {
  final String habitId;
  final VoidCallback? onHabitUpdated;
  final Function(String)? onNameUpdated;

  const HabitDetailsContent({
    super.key,
    required this.habitId,
    this.onHabitUpdated,
    this.onNameUpdated,
  });

  @override
  State<HabitDetailsContent> createState() => _HabitDetailsContentState();
}

class _HabitDetailsContentState extends State<HabitDetailsContent> {
  final _mediator = container.resolve<Mediator>();
  final _habitsService = container.resolve<HabitsService>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
    final _soundManagerService = container.resolve<ISoundManagerService>();

  GetHabitQueryResponse? _habit;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  Timer? _debounce;
  bool _isNameFieldActive = false;

  GetListHabitRecordsQueryResponse? _habitRecords;
  GetListHabitTagsQueryResponse? _habitTags;
  bool _forceTagsRefresh = false;
  int _totalDuration = 0; // Cache total duration to avoid repeated queries

  DateTime currentMonth = DateTime.now();

  // Set to track which optional fields are visible
  final Set<String> _visibleOptionalFields = {};

  // Define optional field keys
  static const String keyTags = 'tags';
  static const String keyEstimatedTime = 'estimatedTime';
  static const String keyElapsedTime = 'elapsedTime';
  static const String keyTimer = 'timer';
  static const String keyDescription = 'description';
  static const String keyReminder = 'reminder';
  static const String keyGoal = 'goal';

  @override
  void initState() {
    _getHabit();
    _getHabitRecordsForMonth(currentMonth);
    _getHabitTags();
    _refreshTotalDuration(); // Initialize total duration

    // Add event listeners
    _habitsService.onHabitUpdated.addListener(_handleHabitUpdated);
    _habitsService.onHabitRecordAdded.addListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.addListener(_handleHabitRecordChanged);

    // Track focus state to prevent text selection conflicts
    _nameFocusNode.addListener(_handleNameFocusChange);

    super.initState();
  }

  @override
  void dispose() {
    _habitsService.onHabitUpdated.removeListener(_handleHabitUpdated);
    _habitsService.onHabitRecordAdded.removeListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.removeListener(_handleHabitRecordChanged);
    _nameFocusNode.removeListener(_handleNameFocusChange);

    // Notify parent about name changes before disposing
    if (widget.onNameUpdated != null && _nameController.text.isNotEmpty) {
      widget.onNameUpdated!(_nameController.text);
    }

    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleHabitUpdated() {
    if (!mounted || _habitsService.onHabitUpdated.value != widget.habitId) return;

    // Skip refresh if name field is actively being edited to prevent input conflicts
    if (_isNameFieldActive) return;

    _getHabit();
    _getHabitTags(); // Also refresh tags when habit is updated
  }

  void _handleNameFocusChange() {
    if (!mounted) return;
    setState(() {
      _isNameFieldActive = _nameFocusNode.hasFocus;
    });
  }

  void _handleHabitRecordChanged() {
    if (!mounted) return;

    // Check if the event is for this habit (either added or removed)
    final addedHabitId = _habitsService.onHabitRecordAdded.value;
    final removedHabitId = _habitsService.onHabitRecordRemoved.value;

    if (addedHabitId != widget.habitId && removedHabitId != widget.habitId) return;

    _getHabitRecordsForMonth(currentMonth);
    _getHabitStatisticsOnly(); // Refresh only statistics, not tags
    _refreshTotalDuration(); // Refresh elapsed time when records change
  }

  Future<void> _getHabitStatisticsOnly() async {
    await AsyncErrorHandler.execute<GetHabitQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingDetailsError),
      operation: () async {
        final query = GetHabitQuery(id: widget.habitId);
        return await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            // Only update statistics-related fields, preserve existing habit data
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
          });
        }
      },
    );
  }

  Future<void> _getHabitPreserveLocal() async {
    await AsyncErrorHandler.execute<GetHabitQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingDetailsError),
      operation: () async {
        final query = GetHabitQuery(id: widget.habitId);
        return await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            if (_habit == null) {
              _habit = result;
            } else {
              // Preserve local changes, only update server-synced fields
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

            // Only update name if it's different
            if (_nameController.text != _habit!.name) {
              _nameController.text = _habit!.name;
              widget.onNameUpdated?.call(_habit!.name);
            }

            // Only update description if it's different
            if (_descriptionController.text != _habit!.description) {
              _descriptionController.text = _habit!.description;
            }

            // Ensure habit has valid reminder settings if reminder is enabled
            if (_habit!.hasReminder) {
              // Ensure we have a valid time
              if (_habit!.reminderTime == null) {
                _habit!.setReminderTimeOfDay(TimeOfDay.now());
              }

              // Ensure we have valid days
              if (_habit!.reminderDays.isEmpty) {
                final allDays = List.generate(7, (index) => index + 1);
                _habit!.setReminderDaysFromList(allDays);

                // Save the updated habit with the default reminder days
                _saveHabitImmediately();
              }
            }
          });
          _processFieldVisibility();
        }
      },
    );
  }

  Future<void> _getHabit() async {
    await AsyncErrorHandler.execute<GetHabitQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingDetailsError),
      operation: () async {
        final query = GetHabitQuery(id: widget.habitId);
        return await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            if (_habit == null) {
              _habit = result;
            } else {
              // Preserve local changes, only update server-synced fields
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

            // Only update name if it's different
            if (_nameController.text != _habit!.name) {
              _nameController.text = _habit!.name;
              widget.onNameUpdated?.call(_habit!.name);
            }

            // Auto-focus if name is empty (newly created habit)
            if (_habit!.name.isEmpty) {
              // Use a small delay to ensure the UI is fully built
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  _nameFocusNode.requestFocus();
                }
              });
            }

            // Only update description if it's different
            if (_descriptionController.text != _habit!.description) {
              _descriptionController.text = _habit!.description;
            }

            // Ensure habit has valid reminder settings if reminder is enabled
            if (_habit!.hasReminder) {
              // Ensure we have a valid time
              if (_habit!.reminderTime == null) {
                _habit!.setReminderTimeOfDay(TimeOfDay.now());
              }

              // Ensure we have valid days
              if (_habit!.reminderDays.isEmpty) {
                final allDays = List.generate(7, (index) => index + 1);
                _habit!.setReminderDaysFromList(allDays);

                // Save the updated habit with the default reminder days
                _saveHabitImmediately();
              }
            }
          });
          _processFieldVisibility();
          _refreshTotalDuration(); // Refresh total duration after habit is loaded
        }
      },
    );
  }

  Future<void> _getHabitRecordsForMonth(DateTime month) async {
    await AsyncErrorHandler.execute<GetListHabitRecordsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingRecordsError),
      operation: () async {
        // Calculate the actual date range displayed in the calendar grid
        // This includes previous month's trailing days and next month's leading days
        final firstDayOfMonth = DateTime(month.year, month.month, 1);
        final firstWeekdayOfMonth = firstDayOfMonth.weekday;
        final previousMonthDays = firstWeekdayOfMonth - 1;

        // Get the first displayed date (could be from previous month)
        final firstDisplayedDate = firstDayOfMonth.subtract(Duration(days: previousMonthDays));

        // Calculate last day of current month
        final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
        final lastWeekdayOfMonth = lastDayOfMonth.weekday;
        final nextMonthDays = 7 - lastWeekdayOfMonth;

        // Get the last displayed date (could be from next month)
        final lastDisplayedDate = lastDayOfMonth.add(Duration(days: nextMonthDays));

        final query = GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: 50, // Increase page size to accommodate wider date range
          habitId: widget.habitId,
          startDate: firstDisplayedDate.toUtc(),
          endDate: lastDisplayedDate.toUtc(),
        );
        return await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            _habitRecords = result;
          });
        }
      },
    );
  }

  Future<void> _createHabitRecord(String habitId, DateTime date) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.creatingRecordError),
      operation: () async {
        final command = ToggleHabitCompletionCommand(habitId: habitId, date: date);
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);
      },
      onSuccess: () {
        if (mounted) {
          // Update records and statistics without triggering tag field refresh
          _getHabitRecordsForMonth(currentMonth);
          _getHabitStatisticsOnly();

          // Play sound feedback for record creation
          _soundManagerService.playHabitCompletion();

          // Notify service that a record was added to trigger statistics refresh
          _habitsService.notifyHabitRecordAdded(habitId);

          // Also notify parent component about the update
          widget.onHabitUpdated?.call();
        }
      },
    );
  }

  Future<void> _deleteAllHabitRecordsForDay(DateTime date) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.deletingRecordError),
      operation: () async {
        // Use ToggleHabitCompletionCommand to delete all records for a day
        // This handles both habit records and time records properly
        final command = ToggleHabitCompletionCommand(
          habitId: widget.habitId,
          date: date,
          useIncrementalBehavior: false, // Use calendar behavior (toggle)
        );
        await _mediator.send<ToggleHabitCompletionCommand, ToggleHabitCompletionCommandResponse>(command);
      },
      onSuccess: () async {
        if (mounted) {
          // Update records and statistics without triggering tag field refresh
          await _getHabitRecordsForMonth(currentMonth);
          await _getHabitStatisticsOnly();
          await _refreshTotalDuration(); // Explicitly refresh elapsed time after deletion

          // Notify service that a record was removed to trigger statistics refresh
          _habitsService.notifyHabitRecordRemoved(widget.habitId);

          // Also notify parent component about the update
          widget.onHabitUpdated?.call();
        }
      },
    );
  }

  Future<void> _getHabitTags() async {
    int pageIndex = 0;
    const int pageSize = 50;

    // Store existing tags to compare and avoid unnecessary UI updates
    final existingTagIds = _habitTags?.items.map((tag) => tag.tagId).toSet() ?? <String>{};
    GetListHabitTagsQueryResponse? newHabitTags;

    while (true) {
      final query = GetListHabitTagsQuery(habitId: widget.habitId, pageIndex: pageIndex, pageSize: pageSize);

      final result = await AsyncErrorHandler.execute<GetListHabitTagsQueryResponse>(
        context: context,
        errorMessage: _translationService.translate(HabitTranslationKeys.loadingTagsError),
        operation: () async {
          return await _mediator.send<GetListHabitTagsQuery, GetListHabitTagsQueryResponse>(query);
        },
        onSuccess: (response) {
          if (newHabitTags == null) {
            newHabitTags = response;
          } else {
            newHabitTags!.items.addAll(response.items);
          }
        },
      );

      // If no result or empty items, break the loop
      if (result == null || result.items.isEmpty || result.items.length < pageSize) {
        break;
      }

      // Continue to next page
      pageIndex++;
    }

    // Update state with new tags - check if we should force refresh or if tags actually changed
    if (mounted) {
      // If we have new tags or if this is the first load (_habitTags is null)
      if (newHabitTags != null) {
        final newTagIds = newHabitTags!.items.map((tag) => tag.tagId).toSet();

        // Always update if forced refresh is requested, first load, or if tags actually changed
        if (_forceTagsRefresh ||
            _habitTags == null ||
            existingTagIds.length != newTagIds.length ||
            !existingTagIds.containsAll(newTagIds)) {
          setState(() {
            _habitTags = newHabitTags;
            _forceTagsRefresh = false; // Reset flag after update
          });
          _processFieldVisibility();
        }
      } else if (_habitTags == null) {
        // If no result and _habitTags is still null, initialize with empty response
        setState(() {
          _habitTags = GetListHabitTagsQueryResponse(items: [], pageIndex: 0, pageSize: 50, totalItemCount: 0);
        });
        _processFieldVisibility();
      }
    }
  }

  // Remove redundant _addTag and _removeTag methods since we already have _addTagToHabit and _removeTagFromHabit
  void _onTagsSelected(List<DropdownOption<String>> tagOptions) {
    if (_habitTags == null) return;

    final tagsToAdd = tagOptions
        .where((tagOption) => !_habitTags!.items.any((habitTag) => habitTag.tagId == tagOption.value))
        .map((option) => option.value)
        .toList();

    final tagsToRemove =
        _habitTags!.items.where((habitTag) => !tagOptions.map((tag) => tag.value).contains(habitTag.tagId)).toList();

    // Batch process all tag operations
    Future<void> processTags() async {
      // Add all tags
      for (final tagId in tagsToAdd) {
        await _addTagToHabit(tagId);
      }

      // Remove all tags
      for (final habitTag in tagsToRemove) {
        await _removeTagFromHabit(habitTag.id);
      }

      // Notify only once after all tag operations are complete
      if (tagsToAdd.isNotEmpty || tagsToRemove.isNotEmpty) {
        _habitsService.notifyHabitUpdated(widget.habitId);
      }
    }

    // Execute the tag operations
    processTags();
  }

  void _onDescriptionChanged(String value) {
    // Handle empty whitespace
    if (value.trim().isEmpty) {
      _descriptionController.clear();

      // Set cursor at beginning after clearing
      if (mounted) {
        _descriptionController.selection = const TextSelection.collapsed(offset: 0);
      }
    }

    // Simply trigger the update
    _saveHabit();
  }

  // Add methods to handle tag operations
  Future<bool> _addTagToHabit(String tagId) async {
    final result = await AsyncErrorHandler.execute<AddHabitTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.addingTagError),
      operation: () async {
        final command = AddHabitTagCommand(habitId: widget.habitId, tagId: tagId);
        return await _mediator.send(command);
      },
    );

    // If operation succeeded, refresh tags and return true
    if (result != null) {
      _forceTagsRefresh = true; // Force refresh after successful addition
      await _getHabitTags();
      return true;
    }

    // Operation failed
    return false;
  }

  Future<bool> _removeTagFromHabit(String id) async {
    final result = await AsyncErrorHandler.execute<RemoveHabitTagCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.removingTagError),
      operation: () async {
        final command = RemoveHabitTagCommand(id: id);
        return await _mediator.send(command);
      },
    );

    // If operation succeeded, refresh tags and return true
    if (result != null) {
      _forceTagsRefresh = true; // Force refresh after successful removal
      await _getHabitTags();
      return true;
    }

    // Operation failed
    return false;
  }

  // Helper methods for repeated patterns
  void _forceImmediateUpdate() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
  }

  SaveHabitCommand _buildSaveCommand() {
    // Force update the reminderDays list from the current string value
    final reminderDaysList = _habit!.hasReminder ? _habit!.getReminderDaysAsList() : [];

    // If reminder is enabled but no days are selected, select all days by default
    if (_habit!.hasReminder && reminderDaysList.isEmpty) {
      final allDays = List.generate(7, (index) => index + 1);
      _habit!.setReminderDaysFromList(allDays);
    }

    // Ensure we have valid reminder data before saving
    if (_habit!.hasReminder) {
      // Ensure we have a valid time
      if (_habit!.reminderTime == null) {
        _habit!.setReminderTimeOfDay(TimeOfDay.now());
      }

      // Ensure we have valid days
      if (_habit!.reminderDays.isEmpty) {
        final allDays = List.generate(7, (index) => index + 1);
        _habit!.setReminderDaysFromList(allDays);
      }
    }

    // Get the final reminder days list to send in the command
    final List<int> reminderDaysToSend = _habit!.hasReminder ? _habit!.getReminderDaysAsList() : [];

    return SaveHabitCommand(
      id: widget.habitId,
      name: _nameController.text,
      description: _descriptionController.text,
      estimatedTime: _habit!.estimatedTime,
      hasReminder: _habit!.hasReminder,
      reminderTime: _habit!.reminderTime,
      reminderDays: reminderDaysToSend, // Always use the latest list from the habit object
      hasGoal: _habit!.hasGoal,
      targetFrequency: _habit!.targetFrequency,
      periodDays: _habit!.periodDays,
      dailyTarget: _habit!.dailyTarget,
    );
  }

  Future<void> _executeSaveCommand() async {
    await _mediator.send(_buildSaveCommand());
  }

  void _handleFieldChange<T>(T value, VoidCallback? onUpdate) {
    _forceImmediateUpdate();
    _saveHabit();
    onUpdate?.call();
  }

  // Event handler methods
  void _onNameChanged(String value) {
    // Update active state to prevent data refresh conflicts during typing
    _isNameFieldActive = true;
    _handleFieldChange(value, () => widget.onNameUpdated?.call(value));
  }

  // Save habit with debounce for text inputs
  Future<void> _saveHabit() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(SharedUiConstants.contentSaveDebounceTime, () async {
      await _saveHabitImmediately();
    });
  }

  // Save habit immediately without debounce
  Future<void> _saveHabitImmediately() async {
    if (!mounted) return;

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.savingDetailsError),
      operation: _executeSaveCommand,
      onSuccess: () {
        // Notify that habit was updated
        _habitsService.notifyHabitUpdated(widget.habitId);
        widget.onHabitUpdated?.call();

        // Force rebuild of the UI to ensure everything is in sync
        if (mounted) {
          setState(() {});
        }

        // Refresh habit data from repository while preserving local changes
        _getHabitPreserveLocal();
      },
    );
  }

  void _previousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);

    if (nextMonth.isAfter(now)) return; // Don't allow navigation to future months

    setState(() {
      currentMonth = nextMonth;
      _getHabitRecordsForMonth(currentMonth);
    });
  }

  // Process field content and update UI after habit data is loaded
  void _processFieldVisibility() {
    if (_habit == null) return;

    setState(() {
      // Make fields with content automatically visible
      if (_hasFieldContent(keyTags)) _visibleOptionalFields.add(keyTags);
      if (_hasFieldContent(keyEstimatedTime)) _visibleOptionalFields.add(keyEstimatedTime);
      if (_hasFieldContent(keyElapsedTime)) _visibleOptionalFields.add(keyElapsedTime);
      if (_hasFieldContent(keyTimer)) _visibleOptionalFields.add(keyTimer);
      if (_hasFieldContent(keyDescription)) _visibleOptionalFields.add(keyDescription);
      if (_hasFieldContent(keyReminder)) _visibleOptionalFields.add(keyReminder);
      if (_hasFieldContent(keyGoal)) _visibleOptionalFields.add(keyGoal);
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
    // Don't show chip if field is already visible OR if it has content
    return !_visibleOptionalFields.contains(fieldKey) && !_hasFieldContent(fieldKey);
  }

  // Method to determine if a field has content
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
        return false; // Timer is always available as an optional field, never auto-shown
      default:
        return false;
    }
  }

  // Get descriptive label for field chips
  String _getFieldLabel(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return _translationService.translate(HabitTranslationKeys.tagsLabel);
      case keyEstimatedTime:
        return _translationService.translate(SharedTranslationKeys.timeDisplayEstimated);
      case keyDescription:
        return _translationService.translate(HabitTranslationKeys.descriptionLabel);
      case keyReminder:
        return _translationService.translate(HabitTranslationKeys.enableReminders);
      case keyGoal:
        return _translationService.translate(HabitTranslationKeys.goalSettings);
      case keyElapsedTime:
        return _translationService.translate(SharedTranslationKeys.timeDisplayElapsed);
      case keyTimer:
        return _translationService.translate(SharedTranslationKeys.timerLabel);
      default:
        return '';
    }
  }

  // Get icon for field chips
  IconData _getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return TagUiConstants.tagIcon;
      case keyEstimatedTime:
        return HabitUiConstants.estimatedTimeIcon;
      case keyDescription:
        return HabitUiConstants.descriptionIcon;
      case keyReminder:
        return Icons.notifications;
      case keyGoal:
        return Icons.track_changes;
      case keyElapsedTime:
        return HabitUiConstants.estimatedTimeIcon;
      case keyTimer:
        return Icons.timer;
      default:
        return Icons.add;
    }
  }

  // Widget to build optional field chips
  Widget _buildOptionalFieldChip(String fieldKey, bool hasContent) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_getFieldLabel(fieldKey)),
          const SizedBox(width: 4),
          Icon(Icons.add, size: AppTheme.iconSizeSmall),
        ],
      ),
      avatar: Icon(
        _getFieldIcon(fieldKey),
        size: AppTheme.iconSizeSmall,
      ),
      selected: _isFieldVisible(fieldKey),
      onSelected: (_) => _toggleOptionalField(fieldKey),
      backgroundColor: hasContent ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : null,
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_habit == null) {
      return const SizedBox.shrink();
    }

    // Don't show fields with content in the chips section
    final List<String> availableChipFields = [
      keyTags,
      keyTimer,
      keyElapsedTime,
      keyEstimatedTime,
      if (!_habit!.isArchived) keyReminder,
      if (!_habit!.isArchived) keyGoal,
      keyDescription,
    ].where((field) => _shouldShowAsChip(field)).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Daily Record Button
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: _buildDailyRecordButton(),
              ),

              // Habit Name
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  maxLines: null,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: _translationService.translate(HabitTranslationKeys.namePlaceholder),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.size2XSmall),

          // Tags, Estimated Time, and Reminder Table
          if (_isFieldVisible(keyTags) ||
              _isFieldVisible(keyEstimatedTime) ||
              _isFieldVisible(keyElapsedTime) ||
              _isFieldVisible(keyTimer) ||
              _isFieldVisible(keyReminder) ||
              _isFieldVisible(keyGoal) ||
              _habit!.archivedDate != null) ...[
            DetailTable(
              rowData: [
                if (_isFieldVisible(keyTags)) _buildTagsSection(),
                if (_isFieldVisible(keyTimer)) _buildTimerSection(),
                if (_isFieldVisible(keyElapsedTime)) _buildElapsedTimeSection(),
                if (_isFieldVisible(keyEstimatedTime)) _buildEstimatedTimeSection(),
                if (_isFieldVisible(keyReminder)) _buildReminderSection(),
                if (_isFieldVisible(keyGoal)) _buildGoalSection(),
                if (_habit!.archivedDate != null) _buildArchivedDateSection(),
              ],
              isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
            ),
          ],

          // Description Table
          if (_isFieldVisible(keyDescription)) ...[
            DetailTable(
              forceVertical: true,
              rowData: [
                DetailTableRowData(
                  label: _translationService.translate(HabitTranslationKeys.descriptionLabel),
                  icon: HabitUiConstants.descriptionIcon,
                  widget: MarkdownEditor(
                    controller: _descriptionController,
                    onChanged: _onDescriptionChanged,
                    height: 250,
                  ),
                  removePadding: true,
                ),
              ],
              isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
            ),
            const SizedBox(height: AppTheme.size2XSmall),
          ],

          // Optional field chips moved to just above Records header
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
            ),
            const SizedBox(height: AppTheme.size2XSmall),
          ],

          // Records and Statistics Section
          _buildRecordsHeader(),
          if (_habitRecords != null) ...[
            HabitCalendarView(
              currentMonth: currentMonth,
              records: _habitRecords!.items,
              onDeleteAllRecordsForDay: _deleteAllHabitRecordsForDay,
              onCreateRecord: _createHabitRecord,
              onPreviousMonth: _previousMonth,
              onNextMonth: _nextMonth,
              onRecordChanged: () {
                // Refresh records when changed
                _getHabitRecordsForMonth(currentMonth);
              },
              habitId: widget.habitId,
              archivedDate: _habit!.archivedDate != null ? DateTimeHelper.toLocalDateTime(_habit!.archivedDate!) : null,
              hasGoal: _habit!.hasGoal,
              targetFrequency: _habit!.targetFrequency,
              periodDays: _habit!.periodDays,
              dailyTarget: _habit!.dailyTarget ?? 1,
            ),
          ],
        ],
      ),
    );
  }

  DetailTableRowData _buildTagsSection() => DetailTableRowData(
        label: _translationService.translate(HabitTranslationKeys.tagsLabel),
        icon: TagUiConstants.tagIcon,
        hintText: _translationService.translate(HabitTranslationKeys.tagsHint),
        widget: TagSelectDropdown(
          key: ValueKey('habit_${widget.habitId}_tags'),
          isMultiSelect: true,
          onTagsSelected: (List<DropdownOption<String>> tagOptions, bool _) => _onTagsSelected(tagOptions),
          showSelectedInDropdown: true,
          initialSelectedTags: _habitTags?.items
                  .map((tag) => DropdownOption<String>(
                      value: tag.tagId,
                      label: tag.tagName.isNotEmpty
                          ? tag.tagName
                          : _translationService.translate(SharedTranslationKeys.untitled)))
                  .toList() ??
              [],
          icon: SharedUiConstants.addIcon,
        ),
      );

  DetailTableRowData _buildEstimatedTimeSection() => DetailTableRowData(
        label: _translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
        icon: HabitUiConstants.estimatedTimeIcon,
        widget: NumericInput(
          initialValue: _habit!.estimatedTime ?? HabitUiConstants.defaultEstimatedTimeOptions.first,
          minValue: 0,
          incrementValue: 5,
          decrementValue: 5,
          onValueChanged: (value) {
            if (!mounted) return;
            setState(() {
              _habit!.estimatedTime = value;
              _saveHabit();
            });
          },
          decrementTooltip: _translationService.translate(HabitTranslationKeys.decreaseEstimatedTime),
          incrementTooltip: _translationService.translate(HabitTranslationKeys.increaseEstimatedTime),
          iconColor: AppTheme.secondaryTextColor,
          iconSize: AppTheme.iconSizeSmall,
          valueSuffix: _translationService.translate(SharedTranslationKeys.minutesShort),
        ),
      );

  DetailTableRowData _buildElapsedTimeSection() => DetailTableRowData(
        label: _translationService.translate(SharedTranslationKeys.timeDisplayElapsed),
        icon: HabitUiConstants.estimatedTimeIcon,
        widget: TimeDisplay(
          totalSeconds: _totalDuration,
          onTap: _showHabitTimeLoggingDialog,
        ),
      );

  DetailTableRowData _buildTimerSection() => DetailTableRowData(
        label: _translationService.translate(SharedTranslationKeys.timerLabel),
        icon: Icons.timer,
        widget: Container(
          constraints: BoxConstraints(
            maxHeight: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium) ? 200 : 300,
          ),
          child: AppTimer(
            onTimerStop: _onHabitTimerStop,
            isMiniLayout: true,
          ),
        ),
      );

  DetailTableRowData _buildReminderSection() {
    return DetailTableRowData(
      label: _translationService.translate(HabitTranslationKeys.reminderSettings),
      icon: Icons.notifications,
      widget: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
        onTap: _openReminderDialog,
        child: Row(
          children: [
            // Main Content Section
            Expanded(
              child: Text(
                _getReminderSummaryText(),
                style: AppTheme.bodyMedium.copyWith(
                  color: !_habit!.hasReminder ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getReminderSummaryText() {
    if (_habit == null || !_habit!.hasReminder) {
      return _translationService.translate(HabitTranslationKeys.noReminder);
    }

    String summary = "";

    // Add time if set
    if (_habit!.reminderTime != null) {
      final timeOfDay = _habit!.getReminderTimeOfDay();
      if (timeOfDay != null) {
        summary += '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
      }
    }

    // Add days information
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

  Future<void> _openReminderDialog() async {
    if (_habit == null) return;

    // Check if habit is archived and archived date is in the past
    final now = DateTime.now();
    final bool isArchived =
        _habit!.archivedDate != null && DateTimeHelper.toLocalDateTime(_habit!.archivedDate!).isBefore(now);

    if (isArchived) return; // Don't open dialog for archived habits

    final result = await showDialog<HabitReminderSettingsResult>(
      context: context,
      builder: (context) => HabitReminderSettingsDialog(
        hasReminder: _habit!.hasReminder,
        reminderTime: _habit!.getReminderTimeOfDay(),
        reminderDays: _habit!.getReminderDaysAsList(),
        translationService: _translationService,
      ),
    );

    if (result != null) {
      if (!mounted) return;

      setState(() {
        _habit!.hasReminder = result.hasReminder;

        if (_habit!.hasReminder) {
          if (result.reminderTime != null) {
            _habit!.setReminderTimeOfDay(result.reminderTime!);
          }
          _habit!.setReminderDaysFromList(result.reminderDays);
        } else {
          // Clear reminder time when disabling reminders
          _habit!.reminderTime = null;
          // Keep reminderDays to preserve selection for when reminders are re-enabled
        }
      });

      // Save changes immediately
      await _saveHabitImmediately();
    }
  }

  DetailTableRowData _buildArchivedDateSection() => DetailTableRowData(
        label: _translationService.translate(HabitTranslationKeys.archivedStatus),
        icon: Icons.archive_outlined,
        widget: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: AppTheme.iconSizeSmall,
                color: AppTheme.textColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                DateTimeHelper.formatDate(_habit!.archivedDate!),
                style: AppTheme.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

  DetailTableRowData _buildGoalSection() {
    final now = DateTime.now();
    final bool isArchived =
        _habit!.archivedDate != null && DateTimeHelper.toLocalDateTime(_habit!.archivedDate!).isBefore(now);

    return DetailTableRowData(
      label: _translationService.translate(HabitTranslationKeys.goalSettings),
      icon: Icons.track_changes,
      widget: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onTap: isArchived
              ? null
              : () async {
                  final result = await showDialog<HabitGoalResult>(
                    context: context,
                    builder: (context) => HabitGoalDialog(
                      hasGoal: _habit!.hasGoal,
                      targetFrequency: _habit!.targetFrequency,
                      periodDays: _habit!.hasGoal ? _habit!.periodDays : 1,
                      dailyTarget: _habit!.dailyTarget ?? 1,
                      translationService: _translationService,
                    ),
                  );

                  if (result != null && mounted) {
                    setState(() {
                      _habit!.hasGoal = result.hasGoal;
                      _habit!.dailyTarget = result.dailyTarget;
                      if (result.hasGoal) {
                        _habit!.targetFrequency = result.targetFrequency;
                        _habit!.periodDays = result.periodDays;
                      }
                    });
                    await _saveHabitImmediately();
                  }
                },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              // Main Content Section
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _habit!.hasGoal
                            ? '${_habit!.dailyTarget ?? 1} ${_translationService.translate(HabitTranslationKeys.dailyTargetHint)}, ${_translationService.translate(HabitTranslationKeys.goalFormat, namedArgs: {
                                    'count': _habit!.targetFrequency.toString(),
                                    'dayCount': _habit!.periodDays.toString()
                                  })}'
                            : _translationService.translate(SharedTranslationKeys.notSetTime),
                        style: AppTheme.bodyMedium.copyWith(
                          color: isArchived
                              ? Theme.of(context).disabledColor
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _buildSectionHeader(
          HabitUiConstants.recordIcon, _translationService.translate(HabitTranslationKeys.recordsLabel)),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Icon(icon),
        ),
        Text(title, style: AppTheme.bodyLarge),
      ],
    );
  }

  /// Gets the count of habit records for today
  int _getTodayRecordCount() {
    if (_habitRecords == null) return 0;
    return _habitRecords!.items.where((record) => DateTimeHelper.isSameDay(record.date, DateTime.now())).length;
  }

  /// Builds the daily record button with cross or chain icon based on completion status
  Widget _buildDailyRecordButton() {
    final int dailyCompletionCount = _getTodayRecordCount();
    final bool hasCustomGoals = _habit!.hasGoal;
    final int dailyTarget = hasCustomGoals ? (_habit!.dailyTarget ?? 1) : 1;
    final bool isDailyGoalMet = dailyCompletionCount >= dailyTarget;
    final bool hasRecords = dailyCompletionCount > 0;
    final now = DateTime.now();
    final bool isArchived = _habit!.archivedDate != null &&
        DateTimeHelper.toLocalDateTime(_habit!.archivedDate!).isBefore(DateTime(now.year, now.month, now.day));

    final tooltipText = isArchived
        ? _translationService.translate(HabitTranslationKeys.archivedStatus)
        : (hasCustomGoals && isDailyGoalMet)
            ? _translationService.translate(HabitTranslationKeys.removeRecordTooltip)
            : _translationService.translate(HabitTranslationKeys.createRecordTooltip);

    // Determine icon and color based on daily target progress
    IconData icon;
    Color iconColor;

    if (isArchived) {
      icon = Icons.close;
      iconColor = Colors.grey;
    } else if (hasCustomGoals && isDailyGoalMet) {
      icon = Icons.link;
      iconColor = Colors.green;
    } else if (hasCustomGoals && dailyTarget > 1 && hasRecords) {
      icon = Icons.add;
      iconColor = Colors.blue;
    } else if (hasRecords) {
      icon = Icons.link;
      iconColor = hasCustomGoals ? Colors.orange : Colors.green;
    } else {
      icon = Icons.close;
      iconColor = Colors.red;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _themeService.primaryColor.withValues(alpha: isArchived ? 0.05 : 0.1),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              size: AppTheme.fontSizeLarge,
              color: iconColor,
            ),
            onPressed: isArchived
                ? null
                : () async {
                    if (hasCustomGoals && isDailyGoalMet) {
                      // Reset to 0 (remove all records for today)
                      await _deleteAllHabitRecordsForDay(DateTime.now());
                    } else if (!hasCustomGoals && hasRecords) {
                      // For habits without custom goals, remove ALL records for today
                      // (handles case where multiple records exist from when custom goals were enabled)
                      await _deleteAllHabitRecordsForDay(DateTime.now());
                    } else {
                      // Add a new record
                      await _createHabitRecord(widget.habitId, DateTime.now().toUtc());
                    }
                  },
            tooltip: tooltipText,
          ),
        ),
        // Show count badge for multiple daily targets (only when custom goals enabled)
        if (hasCustomGoals && dailyTarget > 1 && !isArchived && dailyCompletionCount > 0)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: isDailyGoalMet
                    ? Colors.green
                    : hasRecords
                        ? Colors.orange
                        : Colors.red.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$dailyCompletionCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Get total duration for the habit
  Future<int> _getHabitTotalDuration() async {
    try {
      final query = GetTotalDurationByHabitIdQuery(habitId: widget.habitId);
      final result =
          await _mediator.send<GetTotalDurationByHabitIdQuery, GetTotalDurationByHabitIdQueryResponse>(query);
      return result.totalDuration;
    } catch (e) {
      return 0;
    }
  }

  // Refresh total duration and update the state
  Future<void> _refreshTotalDuration() async {
    try {
      final newTotalDuration = await _getHabitTotalDuration();
      if (mounted && _totalDuration != newTotalDuration) {
        setState(() {
          _totalDuration = newTotalDuration;
        });
        _processFieldVisibility(); // Update field visibility when total duration changes
      } else {}
    } catch (e) {
      // Error getting total duration, keep existing value
    }
  }

  // Show habit time logging dialog
  Future<void> _showHabitTimeLoggingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TimeLoggingDialog(
        entityId: widget.habitId,
        onCancel: () {
          // Handle cancel if needed
        },
        onTimeLoggingSubmitted: (event) async {
          await AsyncErrorHandler.executeVoid(
            context: context,
            operation: () async {
              if (event.isSetTotalMode) {
                // Set total duration for the day
                await _mediator.send(SaveHabitTimeRecordCommand(
                  habitId: event.entityId,
                  totalDuration: event.durationInSeconds,
                  targetDate: event.date,
                ));
              } else {
                // Add duration to existing
                await _mediator.send(AddHabitTimeRecordCommand(
                  habitId: event.entityId,
                  duration: event.durationInSeconds,
                  customDateTime: event.date,
                ));
              }
            },
          );
        },
      ),
    );

    // If time was logged successfully, refresh the habit data
    if (result == true) {
      await _getHabitStatisticsOnly();
      await _refreshTotalDuration(); // Refresh elapsed time after manual logging
    }
  }

  // Timer event handlers
  void _onHabitTimerStop(Duration totalElapsed) {
    if (!mounted) return;
    if (_habit?.id == null) return;

    // Only save if there's actual time elapsed
    if (totalElapsed.inSeconds > 0) {
      final command = AddHabitTimeRecordCommand(
          habitId: _habit!.id, duration: totalElapsed.inSeconds, customDateTime: DateTime.now());
      _mediator.send(command);
    }
  }
}
