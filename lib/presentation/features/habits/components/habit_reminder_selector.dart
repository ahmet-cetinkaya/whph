import 'package:flutter/material.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

/// A widget for selecting reminder options for a habit
class HabitReminderSelector extends StatefulWidget {
  final bool hasReminder;
  final TimeOfDay? reminderTime;
  final List<int> reminderDays;
  final Function(bool) onHasReminderChanged;
  final Function(TimeOfDay) onTimeChanged;
  final Function(List<int>) onDaysChanged;
  final ITranslationService translationService;

  const HabitReminderSelector({
    super.key,
    required this.hasReminder,
    this.reminderTime,
    required this.reminderDays,
    required this.onHasReminderChanged,
    required this.onTimeChanged,
    required this.onDaysChanged,
    required this.translationService,
  });

  @override
  State<HabitReminderSelector> createState() => _HabitReminderSelectorState();
}

class _HabitReminderSelectorState extends State<HabitReminderSelector> {
  late bool _hasReminder;
  late TimeOfDay _reminderTime;
  late List<int> _selectedDays;

  @override
  void initState() {
    super.initState();

    _hasReminder = widget.hasReminder;
    _reminderTime = widget.reminderTime ?? TimeOfDay.now();

    // Initialize selected days from widget
    if (widget.reminderDays.isNotEmpty) {
      _selectedDays = List.from(widget.reminderDays);
    } else {
      // If reminder is enabled but no days are selected, select all days by default
      // This should only happen when creating a new habit or enabling reminders for the first time
      if (widget.hasReminder) {
        _selectedDays = List.generate(7, (index) => index + 1); // 1-7 (Monday-Sunday)

        // Notify parent about the change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onDaysChanged(_selectedDays);
        });
      } else {
        _selectedDays = [];
      }
    }
  }

  @override
  void didUpdateWidget(HabitReminderSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update hasReminder
    if (oldWidget.hasReminder != widget.hasReminder) {
      setState(() {
        _hasReminder = widget.hasReminder;
      });

      // When enabling reminders, select all days by default if no days are currently selected
      if (_selectedDays.isEmpty) {
        setState(() {
          _selectedDays = List.generate(7, (index) => index + 1);
        });

        // Notify parent about the change
        widget.onDaysChanged(_selectedDays);
      }
    }

    // Update reminderTime
    if (oldWidget.reminderTime != widget.reminderTime && widget.reminderTime != null) {
      setState(() {
        _reminderTime = widget.reminderTime!;
      });
    }

    // Update reminderDays only if they've actually changed
    final oldDaysStr = oldWidget.reminderDays.toString();
    final newDaysStr = widget.reminderDays.toString();

    if (oldDaysStr != newDaysStr) {
      if (widget.reminderDays.isNotEmpty) {
        setState(() {
          _selectedDays = List.from(widget.reminderDays);
        });
      } else if (!_hasReminder) {
        // Only clear days if reminders are disabled
        setState(() {
          _selectedDays = [];
        });
      }
    }
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return widget.translationService.translate(SharedTranslationKeys.monday);
      case 2:
        return widget.translationService.translate(SharedTranslationKeys.tuesday);
      case 3:
        return widget.translationService.translate(SharedTranslationKeys.wednesday);
      case 4:
        return widget.translationService.translate(SharedTranslationKeys.thursday);
      case 5:
        return widget.translationService.translate(SharedTranslationKeys.friday);
      case 6:
        return widget.translationService.translate(SharedTranslationKeys.saturday);
      case 7:
        return widget.translationService.translate(SharedTranslationKeys.sunday);
      default:
        return '';
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
      widget.onTimeChanged(picked);
    }
  }

  void _toggleDay(int day) {
    // Create a new list to avoid modifying the existing one directly
    final newSelectedDays = List<int>.from(_selectedDays);

    if (newSelectedDays.contains(day)) {
      newSelectedDays.remove(day);
    } else {
      newSelectedDays.add(day);
    }
    newSelectedDays.sort();

    // Update state with the new list
    setState(() {
      _selectedDays = newSelectedDays;
    });

    // Notify parent about the change after state is updated
    // Use Future.microtask to ensure this happens after the current frame
    Future.microtask(() {
      if (mounted) {
        final daysToSend = List<int>.from(_selectedDays);
        widget.onDaysChanged(daysToSend);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if screen is wide enough for horizontal layout
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    // Build the switch without label but with tooltip
    Widget reminderSwitch = Tooltip(
      message: widget.translationService.translate(HabitTranslationKeys.enableReminders),
      child: Switch(
        value: _hasReminder,
        onChanged: (value) {
          // Update local state
          setState(() {
            _hasReminder = value;

            // When enabling reminders, select all days by default if no days are currently selected
            if (_hasReminder && _selectedDays.isEmpty) {
              _selectedDays = List.generate(7, (index) => index + 1);
            }
          });

          // Notify parent about both changes
          widget.onHasReminderChanged(_hasReminder);

          // If enabling reminders, also notify about selected days
          if (_hasReminder) {
            widget.onDaysChanged(_selectedDays);
          }
        },
      ),
    );

    // Build the time selector with improved styling
    Widget timeSelector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time,
          color: Theme.of(context).colorScheme.primary,
          size: AppTheme.iconSizeSmall,
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => _selectTime(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withAlpha(50),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: AppTheme.iconSizeSmall,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // Build the day selector - more compact for horizontal layout
    Widget daySelector = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(7, (index) {
        final day = index + 1; // 1-7 (Monday-Sunday)
        final isSelected = _selectedDays.contains(day);

        // Determine size based on layout
        final size = isWideScreen ? 28.0 : 32.0;
        final fontSize = isWideScreen ? 10.0 : 12.0;

        return InkWell(
          onTap: () => _toggleDay(day),
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
              // Add subtle shadow for better visual hierarchy
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.3).toInt()),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                _getDayName(day).substring(0, 1),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        );
      }),
    );

    // Warning message for no days selected
    Widget warningMessage = AnimatedOpacity(
      opacity: _selectedDays.isEmpty ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: _selectedDays.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                widget.translationService.translate(HabitTranslationKeys.selectDaysWarning),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );

    // For wide screens, use a horizontal layout
    if (isWideScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row with switch, time selector, and day selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              reminderSwitch,
              if (_hasReminder) ...[
                const SizedBox(width: 16),
                timeSelector,
                const SizedBox(width: 16),
                // Wrap day selector in a container with fixed width to prevent layout shifts
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: daySelector,
                  ),
                ),
              ],
            ],
          ),
          // Warning message below
          if (_hasReminder) warningMessage,
        ],
      );
    }

    // For narrow screens, use a vertical layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enable reminders switch
        reminderSwitch,

        // Only show time selector and days when reminders are enabled
        if (_hasReminder) ...[
          // Time selector
          const SizedBox(height: 8),
          timeSelector,

          // Day selector
          const SizedBox(height: 12),
          daySelector,

          // Warning message
          warningMessage,
        ],
      ],
    );
  }
}
