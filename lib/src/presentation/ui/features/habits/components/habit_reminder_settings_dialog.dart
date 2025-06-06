import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';

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
      return widget.translationService.translate(HabitTranslationKeys.enableReminders);
    }

    String description = "";

    // Add time if set
    if (_reminderTime != null) {
      description +=
          '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
    }

    // Add days information
    if (_reminderDays.isNotEmpty && _reminderDays.length < 7) {
      final weekDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final dayNames = _reminderDays.map((dayNum) {
        return widget.translationService.translate('datetime.weekday.${weekDays[dayNum - 1]}.short');
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
    return AlertDialog(
      title: Text(widget.translationService.translate(HabitTranslationKeys.reminderSettings)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Switch(
                value: _hasReminder,
                onChanged: _toggleReminder,
              ),
              title: Text(widget.translationService.translate(HabitTranslationKeys.reminderSettings)),
              subtitle: Text(
                _getReminderDescription(),
                style: AppTheme.bodySmall,
              ),
            ),
            if (_hasReminder) ...[
              const SizedBox(height: 16),

              // Time Section
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text(widget.translationService.translate(HabitTranslationKeys.reminderTime)),
                subtitle: Text(
                  _reminderTime != null
                      ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                      : widget.translationService.translate(SharedTranslationKeys.addButton),
                  style: AppTheme.bodySmall,
                ),
                trailing: TextButton(
                  onPressed: () => _selectTime(context),
                  child: Text(widget.translationService.translate(SharedTranslationKeys.change)),
                ),
              ),

              const SizedBox(height: 16),

              // Days Section
              Text(
                widget.translationService.translate(HabitTranslationKeys.reminderDays),
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1; // 1-7 (Monday-Sunday)
                  final isSelected = _reminderDays.contains(day);

                  return InkWell(
                    onTap: () => _toggleDay(day),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
                      ),
                      child: Center(
                        child: Text(
                          _getDayName(day).substring(0, 1),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Warning message for no days selected
              if (_reminderDays.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    widget.translationService.translate(HabitTranslationKeys.selectDaysWarning),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancelDialog,
          child: Text(widget.translationService.translate(SharedTranslationKeys.cancelButton)),
        ),
        FilledButton(
          onPressed: _confirmDialog,
          child: Text(widget.translationService.translate(SharedTranslationKeys.doneButton)),
        ),
      ],
    );
  }
}
