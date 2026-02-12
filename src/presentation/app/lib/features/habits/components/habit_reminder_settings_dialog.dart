import 'package:flutter/material.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/shared/components/styled_icon.dart';

class HabitReminderSettingsResult {
  final bool hasReminder;
  final TimeOfDay? reminderTime;
  final List<int> reminderDays;

  const HabitReminderSettingsResult({
    required this.hasReminder,
    this.reminderTime,
    required this.reminderDays,
  });
}

class HabitReminderSettingsDialog extends StatefulWidget {
  final bool hasReminder;
  final TimeOfDay? reminderTime;
  final List<int> reminderDays;
  final ITranslationService translationService;

  const HabitReminderSettingsDialog({
    required this.hasReminder,
    this.reminderTime,
    required this.reminderDays,
    required this.translationService,
    super.key,
  });

  @override
  State<HabitReminderSettingsDialog> createState() => _HabitReminderSettingsDialogState();
}

class _HabitReminderSettingsDialogState extends State<HabitReminderSettingsDialog> {
  late bool _hasReminder;
  TimeOfDay? _reminderTime;
  late List<int> _reminderDays;

  @override
  void initState() {
    super.initState();
    _hasReminder = widget.hasReminder;
    _reminderTime = widget.reminderTime;
    _reminderDays = List.from(widget.reminderDays);
  }

  void _toggleReminder(bool value) {
    setState(() {
      _hasReminder = value;
      if (!value) {
        _reminderTime = null;
      } else {
        // Set default time if not set
        _reminderTime ??= TimeOfDay.now();
        // Set all days if no days selected
        if (_reminderDays.isEmpty) {
          _reminderDays = List.generate(7, (index) => index + 1);
        }
      }
    });
  }

  void _onTimeChanged(TimeOfDay? time) {
    setState(() {
      _reminderTime = time;
    });
  }

  void _onDaysChanged(List<int> days) {
    setState(() {
      _reminderDays = days;
    });
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      _onTimeChanged(picked);
    }
  }

  void _toggleDay(int day) {
    final newSelectedDays = List<int>.from(_reminderDays);
    if (newSelectedDays.contains(day)) {
      newSelectedDays.remove(day);
    } else {
      newSelectedDays.add(day);
    }
    newSelectedDays.sort();
    _onDaysChanged(newSelectedDays);
  }

  String _getDayName(int day) {
    return widget.translationService.translate(SharedTranslationKeys.getWeekDayTranslationKey(day, short: true));
  }

  String _getReminderDescription() {
    if (!_hasReminder) {
      return widget.translationService.translate(HabitTranslationKeys.noReminder);
    }

    String description = "";

    // Add time if set
    if (_reminderTime != null) {
      description +=
          '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
    }

    // Add days information
    if (_reminderDays.isNotEmpty && _reminderDays.length < 7) {
      final dayNames = _reminderDays.map((dayNum) {
        return widget.translationService.translate(SharedTranslationKeys.getWeekDayTranslationKey(dayNum, short: true));
      }).join(', ');
      description += description.isNotEmpty ? ', $dayNames' : dayNames;
    } else if (_reminderDays.length == 7) {
      final everyDay = widget.translationService.translate(HabitTranslationKeys.everyDay);
      description += description.isNotEmpty ? ', $everyDay' : everyDay;
    }

    return description.isNotEmpty ? description : widget.translationService.translate(HabitTranslationKeys.noReminder);
  }

  void _cancelDialog() {
    Navigator.of(context).pop();
  }

  void _confirmDialog() {
    Navigator.of(context).pop(HabitReminderSettingsResult(
      hasReminder: _hasReminder,
      reminderTime: _reminderTime,
      reminderDays: _reminderDays,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.translationService.translate(HabitTranslationKeys.reminderSettings),
          style: AppTheme.headlineSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _cancelDialog,
          tooltip: widget.translationService.translate(SharedTranslationKeys.cancelButton),
        ),
        actions: [
          TextButton(
            onPressed: _confirmDialog,
            child: Text(
              widget.translationService.translate(SharedTranslationKeys.doneButton),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Toggle Card
              Card(
                elevation: 0,
                color: AppTheme.surface1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
                child: SwitchListTile.adaptive(
                  value: _hasReminder,
                  onChanged: _toggleReminder,
                  title: Text(
                    widget.translationService.translate(HabitTranslationKeys.reminderSettings),
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _getReminderDescription(),
                    style: AppTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: StyledIcon(
                    _hasReminder ? Icons.notifications_active : Icons.notifications_off,
                    isActive: _hasReminder,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.sizeLarge),

              // Animated Settings Section
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Selection
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                      child: Text(
                        widget.translationService.translate(HabitTranslationKeys.reminderTime),
                        style: AppTheme.labelLarge,
                      ),
                    ),

                    InkWell(
                      onTap: () => _selectTime(context),
                      borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge, vertical: AppTheme.sizeLarge),
                        decoration: BoxDecoration(
                          color: AppTheme.surface1,
                          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                        ),
                        child: Row(
                          children: [
                            StyledIcon(Icons.access_time_filled, isActive: true),
                            const SizedBox(width: AppTheme.sizeLarge),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _reminderTime != null
                                        ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                                        : widget.translationService.translate(SharedTranslationKeys.notSetTime),
                                    style: AppTheme.headlineLarge.copyWith(fontSize: 32),
                                  ),
                                  Text(
                                    widget.translationService
                                        .translate(SharedTranslationKeys.dateTimePickerSelectTimeTitle),
                                    style: AppTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit, color: AppTheme.textColor.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.sizeXLarge),

                    // Days Selection
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
                      child: Text(
                        widget.translationService.translate(HabitTranslationKeys.reminderDays),
                        style: AppTheme.labelLarge,
                      ),
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.sizeMedium),
                      decoration: BoxDecoration(
                        color: AppTheme.surface1,
                        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StyledIcon(Icons.calendar_month, isActive: true),
                          const SizedBox(width: AppTheme.sizeLarge),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: AppTheme.sizeSmall,
                                  runSpacing: AppTheme.sizeSmall,
                                  alignment: WrapAlignment.start,
                                  children: List.generate(7, (index) {
                                    final day = index + 1;
                                    final isSelected = _reminderDays.contains(day);
                                    return _buildDaySelector(context, day, isSelected);
                                  }),
                                ),
                                if (_reminderDays.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppTheme.sizeMedium),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.error),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.translationService.translate(HabitTranslationKeys.selectDaysWarning),
                                          style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.error),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                crossFadeState: _hasReminder ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector(BuildContext context, int day, bool isSelected) {
    final theme = Theme.of(context);
    final dayName = _getDayName(day);

    return Semantics(
      label: widget.translationService.translate(SharedTranslationKeys.getWeekDayTranslationKey(day)),
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: () => _toggleDay(day),
        borderRadius: BorderRadius.circular(25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? theme.colorScheme.primary : AppTheme.surface2,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              dayName.substring(0, 1),
              style: TextStyle(
                color: isSelected
                    ? ColorContrastHelper.getContrastingTextColor(theme.colorScheme.primary)
                    : AppTheme.textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
