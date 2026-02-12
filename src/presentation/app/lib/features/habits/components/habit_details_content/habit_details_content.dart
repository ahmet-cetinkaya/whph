import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show DateTimeHelper, MarkdownEditor, ResponsiveDialogHelper, DialogSize;
import 'package:whph/main.dart';
import 'package:whph/features/habits/components/habit_calendar_view/habit_calendar_view.dart';
import 'package:whph/features/habits/components/habit_details_content/components/habit_archived_section.dart';
import 'package:whph/features/habits/components/habit_details_content/components/habit_goal_section.dart';
import 'package:whph/features/habits/components/habit_details_content/components/habit_optional_field_chip.dart';
import 'package:whph/features/habits/components/habit_details_content/components/habit_records_section.dart';
import 'package:whph/features/habits/components/habit_details_content/components/habit_reminder_section.dart';
import 'package:whph/features/habits/components/habit_details_content/components/habit_tags_section.dart';
import 'package:whph/features/habits/components/habit_details_content/components/habit_time_section.dart';
import 'package:whph/features/habits/components/habit_details_content/components/habit_timer_section.dart';
import 'package:whph/features/habits/components/habit_details_content/controllers/habit_details_controller.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/shared/components/detail_table.dart';
import 'package:whph/shared/components/time_logging_dialog.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/shared/utils/app_theme_helper.dart';

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
  final _themeService = container.resolve<IThemeService>();
  late final HabitDetailsController _controller;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = HabitDetailsController()
      ..onHabitUpdated = widget.onHabitUpdated
      ..onNameUpdated = widget.onNameUpdated;

    _controller.addListener(_onControllerUpdate);
    _nameFocusNode.addListener(_handleNameFocusChange);
    _descriptionFocusNode.addListener(_handleDescriptionFocusChange);
    _initializeController();
  }

  Future<void> _initializeController() async {
    await _controller.initialize(widget.habitId, context);
    if (mounted) {
      _lastSyncedName = _controller.habit?.name;
      _lastSyncedDescription = _controller.habit?.description;
      _updateTextControllers();
    }
  }

  // Track last synced values to detect dirty state
  String? _lastSyncedName;
  String? _lastSyncedDescription;

  void _updateTextControllers() {
    if (_controller.habit == null) return;

    final name = _controller.habit!.name;
    if (_nameController.text == name) {
      _lastSyncedName = name;
    } else {
      final bool isNameDirty = _nameController.text != (_lastSyncedName ?? '');
      if (!isNameDirty && _nameController.text != name) {
        _nameController.text = name;
        _lastSyncedName = name;
        widget.onNameUpdated?.call(name);

        if (name.isEmpty) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _nameFocusNode.requestFocus();
          });
        }
      }
    }

    final description = _controller.habit!.description;
    if (_descriptionController.text == description) {
      _lastSyncedDescription = description;
    } else {
      final bool isDescriptionDirty = _descriptionController.text != (_lastSyncedDescription ?? '');
      if (!isDescriptionDirty && _descriptionController.text != description) {
        _descriptionController.text = description;
        _lastSyncedDescription = description;
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
      _updateTextControllers();
    }
  }

  void _handleNameFocusChange() {
    _controller.setNameFieldActive(_nameFocusNode.hasFocus);
  }

  void _handleDescriptionFocusChange() {
    _controller.setDescriptionFieldActive(_descriptionFocusNode.hasFocus);
  }

  @override
  void dispose() {
    _controller.habitsService.onHabitUpdated.removeListener(() {});
    _controller.habitsService.onHabitRecordAdded.removeListener(() {});
    _controller.habitsService.onHabitRecordRemoved.removeListener(() {});
    _nameFocusNode.removeListener(_handleNameFocusChange);
    _descriptionFocusNode.removeListener(_handleDescriptionFocusChange);

    if (widget.onNameUpdated != null && _nameController.text.isNotEmpty) {
      widget.onNameUpdated!(_nameController.text);
    }

    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _controller.updateName(value, widget.habitId, context);
  }

  void _onDescriptionChanged(String value) {
    _controller.setDescriptionFieldActive(true);
    if (value.trim().isEmpty) {
      _descriptionController.clear();
      if (mounted) {
        _descriptionController.selection = const TextSelection.collapsed(offset: 0);
      }
    }
    _controller.updateDescription(value, widget.habitId, context);
  }

  Future<void> _showHabitTimeLoggingDialog() async {
    final result = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.large,
      child: TimeLoggingDialog(
        entityId: widget.habitId,
        onCancel: () {},
        onTimeLoggingSubmitted: (event) async {
          await _controller.logTime(
            context: context,
            habitId: event.entityId,
            isSetTotalMode: event.isSetTotalMode,
            durationInSeconds: event.durationInSeconds,
            date: event.date,
          );
        },
      ),
    );

    if (result == true && mounted) {
      await _controller.loadHabitStatisticsOnly(widget.habitId, context);
      await _controller.refreshTotalDuration(widget.habitId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.habit == null) {
      return const SizedBox.shrink();
    }

    final habit = _controller.habit!;
    final translationService = _controller.translationService;

    final List<String> availableChipFields = [
      HabitDetailsController.keyTags,
      HabitDetailsController.keyTimer,
      HabitDetailsController.keyElapsedTime,
      HabitDetailsController.keyEstimatedTime,
      if (!habit.isArchived) HabitDetailsController.keyReminder,
      if (!habit.isArchived) HabitDetailsController.keyGoal,
      HabitDetailsController.keyDescription,
    ].where((field) => _controller.shouldShowAsChip(field)).toList();

    final now = DateTime.now();
    final bool isArchived = habit.archivedDate != null &&
        DateTimeHelper.toLocalDateTime(habit.archivedDate!).isBefore(DateTime(now.year, now.month, now.day));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Habit Name Row
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: HabitRecordsSection.buildDailyRecordButton(
                  context: context,
                  dailyCompletionCount: _controller.getTodayCompletionCount(),
                  todayStatus: _controller.getTodayStatus(),
                  hasCustomGoals: habit.hasGoal,
                  dailyTarget: habit.hasGoal ? (habit.dailyTarget ?? 1) : 1,
                  isArchived: isArchived,
                  translationService: translationService,
                  themeService: _themeService,
                  onToggle: () => _controller.toggleHabitRecordForDay(DateTime.now(), widget.habitId, context),
                  isThreeStateEnabled: _controller.isThreeStateEnabled,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  maxLines: null,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: translationService.translate(HabitTranslationKeys.namePlaceholder),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.size2XSmall),

          // Detail Table
          if (_controller.isFieldVisible(HabitDetailsController.keyTags) ||
              _controller.isFieldVisible(HabitDetailsController.keyEstimatedTime) ||
              _controller.isFieldVisible(HabitDetailsController.keyElapsedTime) ||
              _controller.isFieldVisible(HabitDetailsController.keyTimer) ||
              _controller.isFieldVisible(HabitDetailsController.keyReminder) ||
              _controller.isFieldVisible(HabitDetailsController.keyGoal) ||
              habit.archivedDate != null) ...[
            DetailTable(
              rowData: [
                if (_controller.isFieldVisible(HabitDetailsController.keyTags))
                  HabitTagsSection.build(
                    habitId: widget.habitId,
                    habitTags: _controller.habitTags,
                    translationService: translationService,
                    onTagsSelected: (tags) => _controller.processTagChanges(tags, widget.habitId, context),
                  ),
                if (_controller.isFieldVisible(HabitDetailsController.keyTimer))
                  HabitTimerSection.build(
                    context: context,
                    translationService: translationService,
                    onTimerStop: (duration) => _controller.onTimerStop(duration, widget.habitId),
                  ),
                if (_controller.isFieldVisible(HabitDetailsController.keyElapsedTime))
                  HabitTimeSection.buildElapsedTime(
                    totalDuration: _controller.totalDuration,
                    translationService: translationService,
                    onTap: _showHabitTimeLoggingDialog,
                  ),
                if (_controller.isFieldVisible(HabitDetailsController.keyEstimatedTime))
                  HabitTimeSection.buildEstimatedTime(
                    estimatedTime: habit.estimatedTime,
                    translationService: translationService,
                    onValueChanged: (value) {
                      _controller.updateEstimatedTime(value, widget.habitId, context);
                    },
                    translations: HabitTimeSection.getNumericInputTranslations(translationService),
                  ),
                if (_controller.isFieldVisible(HabitDetailsController.keyReminder))
                  HabitReminderSection.build(
                    context: context,
                    hasReminder: habit.hasReminder,
                    reminderSummaryText: _controller.getReminderSummaryText(),
                    translationService: translationService,
                    onTap: () => _controller.openReminderDialog(context, widget.habitId),
                  ),
                if (_controller.isFieldVisible(HabitDetailsController.keyGoal))
                  HabitGoalSection.build(
                    context: context,
                    hasGoal: habit.hasGoal,
                    targetFrequency: habit.targetFrequency,
                    periodDays: habit.periodDays,
                    dailyTarget: habit.dailyTarget ?? 1,
                    isArchived: isArchived,
                    translationService: translationService,
                    onTap: () => _controller.openGoalDialog(context, widget.habitId),
                  ),
                if (habit.archivedDate != null)
                  HabitArchivedSection.build(
                    context: context,
                    archivedDate: habit.archivedDate!,
                    translationService: translationService,
                  ),
              ],
              isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
            ),
          ],

          // Description Table
          if (_controller.isFieldVisible(HabitDetailsController.keyDescription)) ...[
            DetailTable(
              forceVertical: true,
              rowData: [
                DetailTableRowData(
                  label: translationService.translate(HabitTranslationKeys.descriptionLabel),
                  icon: HabitUiConstants.descriptionIcon,
                  widget: MarkdownEditor.simple(
                    controller: _descriptionController,
                    focusNode: _descriptionFocusNode,
                    onChanged: _onDescriptionChanged,
                    height: 250,
                    style: Theme.of(context).textTheme.bodyMedium,
                    hintText: translationService.translate(SharedTranslationKeys.markdownEditorHint),
                    translations: SharedTranslationKeys.mapMarkdownTranslations(translationService),
                  ),
                  removePadding: true,
                ),
              ],
              isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
            ),
            const SizedBox(height: AppTheme.size2XSmall),
          ],

          // Optional Field Chips
          if (availableChipFields.isNotEmpty) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: availableChipFields
                  .map((fieldKey) => HabitOptionalFieldChip.build(
                        context: context,
                        fieldKey: fieldKey,
                        isSelected: _controller.isFieldVisible(fieldKey),
                        hasContent: false,
                        translationService: translationService,
                        onSelected: () => _controller.toggleOptionalField(fieldKey),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppTheme.sizeMedium),
          ],

          // Records Section
          if (_controller.habitRecords != null) ...[
            HabitCalendarView(
              currentMonth: _controller.currentMonth,
              records: _controller.habitRecords!.items,
              onToggle: (date) => _controller.toggleHabitRecordForDay(date, widget.habitId, context),
              onPreviousMonth: () => _controller.previousMonth(widget.habitId, context),
              onNextMonth: () => _controller.nextMonth(widget.habitId, context),
              onRecordChanged: () => _controller.loadHabitRecordsForMonth(
                _controller.currentMonth,
                widget.habitId,
                context,
              ),
              habitId: widget.habitId,
              archivedDate: habit.archivedDate != null ? DateTimeHelper.toLocalDateTime(habit.archivedDate!) : null,
              hasGoal: habit.hasGoal,
              targetFrequency: habit.targetFrequency,
              periodDays: habit.periodDays,
              dailyTarget: habit.dailyTarget ?? 1,
              isThreeStateEnabled: _controller.isThreeStateEnabled,
            ),
          ],
        ],
      ),
    );
  }
}
