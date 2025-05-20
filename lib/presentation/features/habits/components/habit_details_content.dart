import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/application/features/habits/commands/remove_habit_tag_command.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/components/habit_reminder_selector.dart';
import 'package:whph/presentation/features/habits/components/habit_goal_dialog.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/detail_table.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/presentation/features/habits/components/habit_calendar_view.dart';
import 'package:whph/presentation/features/habits/components/habit_statistics_view.dart';
import 'package:whph/presentation/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';

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

  GetHabitQueryResponse? _habit;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Timer? _debounce;

  GetListHabitRecordsQueryResponse? _habitRecords;
  GetListHabitTagsQueryResponse? _habitTags;

  DateTime currentMonth = DateTime.now();

  // Set to track which optional fields are visible
  final Set<String> _visibleOptionalFields = {};

  // Define optional field keys
  static const String keyTags = 'tags';
  static const String keyEstimatedTime = 'estimatedTime';
  static const String keyDescription = 'description';
  static const String keyReminder = 'reminder';
  static const String keyGoal = 'goal';

  @override
  void initState() {
    _getHabit();
    _getHabitRecordsForMonth(currentMonth);
    _getHabitTags();

    // Add event listeners
    _habitsService.onHabitUpdated.addListener(_handleHabitUpdated);
    _habitsService.onHabitRecordAdded.addListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.addListener(_handleHabitRecordChanged);

    super.initState();
  }

  @override
  void dispose() {
    _habitsService.onHabitUpdated.removeListener(_handleHabitUpdated);
    _habitsService.onHabitRecordAdded.removeListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.removeListener(_handleHabitRecordChanged);

    _nameController.dispose();
    _descriptionController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleHabitUpdated() {
    if (!mounted || _habitsService.onHabitUpdated.value != widget.habitId) return;
    _getHabit();
    _getHabitTags(); // Also refresh tags when habit is updated
  }

  void _handleHabitRecordChanged() {
    if (!mounted || _habitsService.onHabitRecordAdded.value != widget.habitId) return;
    _getHabitRecordsForMonth(currentMonth);
    _getHabit(); // Refresh statistics
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
          // Store current selections before updating
          final nameSelection = _nameController.selection;
          final descriptionSelection = _descriptionController.selection;

          setState(() {
            _habit = result;

            // Only update name if it's different
            if (_nameController.text != result.name) {
              _nameController.text = result.name;
              widget.onNameUpdated?.call(result.name);
              // Don't restore selection for name if it changed
            } else if (nameSelection.isValid) {
              // Restore selection if name didn't change
              _nameController.selection = nameSelection;
            }

            // Only update description if it's different
            if (_descriptionController.text != _habit!.description) {
              _descriptionController.text = _habit!.description;
              // Don't restore selection if text changed
            } else if (descriptionSelection.isValid) {
              // Restore selection if text didn't change
              _descriptionController.selection = descriptionSelection;
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

  Future<void> _getHabitRecordsForMonth(DateTime month) async {
    await AsyncErrorHandler.execute<GetListHabitRecordsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingRecordsError),
      operation: () async {
        final firstDayOfMonth = DateTime(month.year, month.month - 1, 23).toUtc();
        final lastDayOfMonth = DateTime(month.year, month.month + 1, 0).toUtc();

        final query = GetListHabitRecordsQuery(
          pageIndex: 0,
          pageSize: 37,
          habitId: widget.habitId,
          startDate: firstDayOfMonth,
          endDate: lastDayOfMonth,
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
        final command = AddHabitRecordCommand(habitId: habitId, date: DateTimeHelper.toUtcDateTime(date));
        await _mediator.send<AddHabitRecordCommand, AddHabitRecordCommandResponse>(command);
      },
      onSuccess: () {
        if (mounted) {
          setState(() {
            _getHabitRecordsForMonth(currentMonth);
            _getHabit();
          });
        }
      },
    );
  }

  Future<void> _deleteHabitRecord(String id) async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.deletingRecordError),
      operation: () async {
        final command = DeleteHabitRecordCommand(id: id);
        await _mediator.send<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse>(command);
      },
      onSuccess: () {
        if (mounted) {
          setState(() {
            _getHabitRecordsForMonth(currentMonth);
            _getHabit();
          });
        }
      },
    );
  }

  Future<void> _getHabitTags() async {
    int pageIndex = 0;
    const int pageSize = 50;

    // Clear existing tags first to avoid duplications
    if (mounted) {
      setState(() {
        if (_habitTags != null) {
          _habitTags!.items.clear();
        }
      });
    }

    while (true) {
      final query = GetListHabitTagsQuery(habitId: widget.habitId, pageIndex: pageIndex, pageSize: pageSize);

      final result = await AsyncErrorHandler.execute<GetListHabitTagsQueryResponse>(
        context: context,
        errorMessage: _translationService.translate(HabitTranslationKeys.loadingTagsError),
        operation: () async {
          return await _mediator.send<GetListHabitTagsQuery, GetListHabitTagsQueryResponse>(query);
        },
        onSuccess: (response) {
          if (mounted) {
            setState(() {
              if (_habitTags == null) {
                _habitTags = response;
              } else {
                _habitTags!.items.addAll(response.items);
              }
            });

            // Process field visibility again after tags are loaded
            _processFieldVisibility();
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
      await _getHabitTags();
      return true;
    }

    // Operation failed
    return false;
  }

  // Save habit with debounce for text inputs
  Future<void> _saveHabit() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await _saveHabitImmediately();
    });
  }

  // Save habit immediately without debounce
  Future<void> _saveHabitImmediately() async {
    if (!mounted) return;

    // Force update the reminderDays list from the current string value
    // This ensures we're using the latest value
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

    final command = SaveHabitCommand(
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
    );

    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.savingDetailsError),
      operation: () async {
        await _mediator.send<SaveHabitCommand, SaveHabitCommandResponse>(command);
      },
      onSuccess: () {
        // Notify that habit was updated
        _habitsService.notifyHabitUpdated(widget.habitId);
        widget.onHabitUpdated?.call();

        // Force rebuild of the UI to ensure everything is in sync
        if (mounted) {
          setState(() {});
        }

        // Refresh habit data from repository to ensure we have the latest data
        _getHabit();
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
        return _translationService.translate(HabitTranslationKeys.estimatedTimeLabel);
      case keyDescription:
        return _translationService.translate(HabitTranslationKeys.descriptionLabel);
      case keyReminder:
        return _translationService.translate(HabitTranslationKeys.enableReminders);
      case keyGoal:
        return _translationService.translate(HabitTranslationKeys.goalSettings);
      default:
        return '';
    }
  }

  // Get icon for field chips
  IconData _getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return HabitUiConstants.tagsIcon;
      case keyEstimatedTime:
        return HabitUiConstants.estimatedTimeIcon;
      case keyDescription:
        return HabitUiConstants.descriptionIcon;
      case keyReminder:
        return Icons.notifications;
      case keyGoal:
        return Icons.track_changes;
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
      keyEstimatedTime,
      keyDescription,
      if (!_habit!.isArchived()) keyReminder,
      if (!_habit!.isArchived()) keyGoal,
    ].where((field) => _shouldShowAsChip(field)).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Daily Record Button
              _buildDailyRecordButton(),
              const SizedBox(width: 8),

              // Habit Name
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  maxLines: null,
                  onChanged: (value) {
                    _saveHabit();
                    widget.onNameUpdated?.call(value);
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: Tooltip(
                      message: _translationService.translate(HabitTranslationKeys.editNameTooltip),
                      child: Icon(Icons.edit, size: AppTheme.iconSizeSmall),
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.sizeSmall),

          // Tags, Estimated Time, and Reminder Table
          if (_isFieldVisible(keyTags) ||
              _isFieldVisible(keyEstimatedTime) ||
              _isFieldVisible(keyReminder) ||
              _isFieldVisible(keyGoal) ||
              _habit!.archivedDate != null)
            DetailTable(rowData: [
              if (_isFieldVisible(keyTags)) _buildTagsSection(),
              if (_isFieldVisible(keyEstimatedTime)) _buildEstimatedTimeSection(),
              if (_isFieldVisible(keyReminder)) _buildReminderSection(),
              if (_isFieldVisible(keyGoal)) _buildGoalSection(),
              if (_habit!.archivedDate != null) _buildArchivedDateSection(),
            ]),

          // Description Table
          if (_isFieldVisible(keyDescription))
            DetailTable(
              forceVertical: true,
              rowData: [
                DetailTableRowData(
                  label: _translationService.translate(HabitTranslationKeys.descriptionLabel),
                  icon: HabitUiConstants.descriptionIcon,
                  hintText: SharedUiConstants.markdownEditorHint,
                  widget: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MarkdownAutoPreview(
                      controller: _descriptionController,
                      onChanged: _onDescriptionChanged,
                      hintText: SharedUiConstants.addDescriptionHint,
                      toolbarBackground: AppTheme.surface1,
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Optional field chips moved to just above Records header
          if (availableChipFields.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableChipFields.map((fieldKey) => _buildOptionalFieldChip(fieldKey, false)).toList(),
            ),
            const SizedBox(height: AppTheme.sizeSmall),
          ],

          // Records and Statistics Section
          _buildRecordsHeader(),
          if (_habitRecords != null) ...[
            HabitCalendarView(
              currentMonth: currentMonth,
              records: _habitRecords!.items,
              onDeleteRecord: _deleteHabitRecord,
              onCreateRecord: _createHabitRecord,
              onPreviousMonth: _previousMonth,
              onNextMonth: _nextMonth,
              habitId: widget.habitId,
              archivedDate: _habit!.archivedDate != null ? DateTimeHelper.toLocalDateTime(_habit!.archivedDate!) : null,
              hasGoal: _habit!.hasGoal,
              targetFrequency: _habit!.targetFrequency,
              periodDays: _habit!.periodDays,
            ),
          ],

          // Statistics
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: HabitStatisticsView(
              statistics: _habit!.statistics,
              habitId: widget.habitId,
              archivedDate: _habit!.archivedDate != null ? DateTimeHelper.toLocalDateTime(_habit!.archivedDate!) : null,
              firstRecordDate: _habitRecords!.items.isNotEmpty
                  ? _habitRecords!.items.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b)
                  : _habit!.createdDate,
              hasGoal: _habit!.hasGoal,
              targetFrequency: _habit!.targetFrequency,
              periodDays: _habit!.periodDays,
            ),
          ),
        ],
      ),
    );
  }

  DetailTableRowData _buildTagsSection() => DetailTableRowData(
        label: _translationService.translate(HabitTranslationKeys.tagsLabel),
        icon: HabitUiConstants.tagsIcon,
        hintText: _translationService.translate(HabitTranslationKeys.tagsHint),
        widget: _habitTags != null
            ? TagSelectDropdown(
                key: ValueKey(_habitTags!.items.length),
                isMultiSelect: true,
                onTagsSelected: (List<DropdownOption<String>> tagOptions, bool _) => _onTagsSelected(tagOptions),
                showSelectedInDropdown: true,
                initialSelectedTags: _habitTags!.items
                    .map((tag) => DropdownOption<String>(value: tag.tagId, label: tag.tagName))
                    .toList(),
                icon: SharedUiConstants.addIcon,
              )
            : Container(),
      );

  DetailTableRowData _buildEstimatedTimeSection() => DetailTableRowData(
        label: _translationService.translate(HabitTranslationKeys.estimatedTimeLabel),
        icon: HabitUiConstants.estimatedTimeIcon,
        widget: Row(
          children: [
            IconButton(
              onPressed: () => _adjustEstimatedTime(-1),
              icon: const Icon(Icons.remove),
            ),
            Text(
              _habit!.estimatedTime == null
                  ? _translationService.translate(HabitTranslationKeys.estimatedTimeNotSet)
                  : SharedUiConstants.formatMinutes(_habit!.estimatedTime!),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => _adjustEstimatedTime(1),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      );

  DetailTableRowData _buildReminderSection() {
    // Get the current reminder days list
    final reminderDaysList = _habit!.getReminderDaysAsList();

    // Check if habit is archived and archived date is in the past
    final now = DateTime.now();
    final bool isArchived =
        _habit!.archivedDate != null && DateTimeHelper.toLocalDateTime(_habit!.archivedDate!).isBefore(now);

    return DetailTableRowData(
      label: _translationService.translate(HabitTranslationKeys.reminderSettings),
      icon: Icons.notifications,
      // Use a Container with padding to make the widget more compact
      widget: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: HabitReminderSelector(
          key: ValueKey('reminder_selector_${_habit!.id}'),
          hasReminder: _habit!.hasReminder,
          reminderTime: _habit!.getReminderTimeOfDay(),
          reminderDays: reminderDaysList,
          enabled: !isArchived,
          onHasReminderChanged: (value) {
            // Use addPostFrameCallback to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _habit!.hasReminder = value;

                  // If disabling reminders, clear the reminder time
                  if (!value) {
                    _habit!.reminderTime = null;
                    // We don't clear reminderDays when disabling reminders to preserve the selection
                    // This way, when reminders are re-enabled, the previously selected days will be restored
                  } else {
                    // When enabling reminders, select all days by default if no days are currently selected
                    final currentDays = _habit!.getReminderDaysAsList();
                    if (currentDays.isEmpty) {
                      final allDays = List.generate(7, (index) => index + 1);
                      _habit!.setReminderDaysFromList(allDays);
                    }

                    // Set default time if none is set
                    if (_habit!.reminderTime == null) {
                      _habit!.setReminderTimeOfDay(TimeOfDay.now());
                    }
                  }
                });

                // Save immediately without debounce
                _saveHabitImmediately();
              }
            });
          },
          onTimeChanged: (value) {
            // Use addPostFrameCallback to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _habit!.setReminderTimeOfDay(value);
                });

                // Save immediately without debounce
                _saveHabitImmediately();
              }
            });
          },
          onDaysChanged: (value) {
            // Ensure we're working with a new list to avoid reference issues
            final newDays = List<int>.from(value);

            // Use addPostFrameCallback to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Directly update the habit object
                _habit!.setReminderDaysFromList(newDays);

                // Force UI update
                setState(() {});

                // Save the changes immediately without debounce
                _saveHabitImmediately();
              }
            });
          },
          translationService: _translationService,
        ),
      ),
    );
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
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !isArchived,
          title: Text(
            _habit!.hasGoal
                ? _translationService.translate(HabitTranslationKeys.goalFormat,
                    namedArgs: {'count': _habit!.targetFrequency.toString(), 'dayCount': _habit!.periodDays.toString()})
                : _translationService.translate(HabitTranslationKeys.enableGoals),
            style: AppTheme.bodyMedium,
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isArchived ? Theme.of(context).disabledColor : null,
          ),
          onTap: isArchived
              ? null
              : () async {
                  final result = await showDialog<HabitGoalResult>(
                    context: context,
                    builder: (context) => HabitGoalDialog(
                      hasGoal: _habit!.hasGoal,
                      targetFrequency: _habit!.targetFrequency,
                      periodDays: _habit!.periodDays,
                      translationService: _translationService,
                    ),
                  );

                  if (result != null && mounted) {
                    setState(() {
                      _habit!.hasGoal = result.hasGoal;
                      if (result.hasGoal) {
                        _habit!.targetFrequency = result.targetFrequency;
                        _habit!.periodDays = result.periodDays;
                      }
                    });
                    await _saveHabitImmediately();
                  }
                },
        ),
      ),
    );
  }

  void _adjustEstimatedTime(int adjustment) {
    if (!mounted) return;
    setState(() {
      final currentIndex = HabitUiConstants.defaultEstimatedTimeOptions.indexOf(_habit!.estimatedTime ?? 0);
      if (currentIndex == -1) {
        _habit!.estimatedTime = HabitUiConstants.defaultEstimatedTimeOptions.first;
      } else {
        final newIndex = (currentIndex + adjustment).clamp(
          0,
          HabitUiConstants.defaultEstimatedTimeOptions.length - 1,
        );
        _habit!.estimatedTime = HabitUiConstants.defaultEstimatedTimeOptions[newIndex];
      }
      _saveHabit();
    });
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

  /// Checks if there's a habit record for today
  bool _hasRecordForToday() {
    if (_habitRecords == null) return false;
    return _habitRecords!.items.any((record) => DateTimeHelper.isSameDay(record.date, DateTime.now()));
  }

  /// Gets the habit record for today if it exists
  HabitRecordListItem? _getRecordForToday() {
    if (!_hasRecordForToday()) return null;
    return _habitRecords!.items.firstWhere(
      (record) => DateTimeHelper.isSameDay(record.date, DateTime.now()),
    );
  }

  /// Builds the daily record button with cross or chain icon based on completion status
  Widget _buildDailyRecordButton() {
    final bool hasRecordToday = _hasRecordForToday();
    final now = DateTime.now();
    final bool isArchived = _habit!.archivedDate != null &&
        DateTimeHelper.toLocalDateTime(_habit!.archivedDate!).isBefore(DateTime(now.year, now.month, now.day));
    final tooltipText = isArchived
        ? _translationService.translate(HabitTranslationKeys.archivedStatus)
        : hasRecordToday
            ? _translationService.translate(HabitTranslationKeys.removeRecordTooltip)
            : _translationService.translate(HabitTranslationKeys.createRecordTooltip);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: isArchived ? 0.05 : 0.1),
      ),
      child: IconButton(
        icon: Icon(
          hasRecordToday ? Icons.link : Icons.close,
          size: AppTheme.fontSizeLarge,
          color: isArchived
              ? Colors.grey
              : hasRecordToday
                  ? Colors.green
                  : Colors.red,
        ),
        onPressed: isArchived
            ? null
            : () async {
                if (hasRecordToday) {
                  final recordToday = _getRecordForToday();
                  if (recordToday != null) {
                    await _deleteHabitRecord(recordToday.id);
                  }
                } else {
                  await _createHabitRecord(widget.habitId, DateTimeHelper.toUtcDateTime(DateTime.now()));
                }
              },
        tooltip: tooltipText,
      ),
    );
  }
}
