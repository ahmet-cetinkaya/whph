import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:application/features/habits/commands/save_habit_command.dart';
import 'package:application/features/habits/queries/get_habit_query.dart';
import 'package:whph/main.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/features/habits/services/habits_service.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/shared/utils/async_error_handler.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';

class HabitArchiveButton extends StatefulWidget {
  final String habitId;
  final VoidCallback? onArchiveSuccess;
  final Color? buttonColor;
  final Color? buttonBackgroundColor;
  final String? tooltip;

  const HabitArchiveButton({
    super.key,
    required this.habitId,
    this.onArchiveSuccess,
    this.buttonColor,
    this.buttonBackgroundColor = Colors.transparent,
    this.tooltip,
  });

  @override
  State<HabitArchiveButton> createState() => _HabitArchiveButtonState();
}

class _HabitArchiveButtonState extends State<HabitArchiveButton> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  final _habitsService = container.resolve<HabitsService>();
  bool? _isArchived;

  @override
  void initState() {
    super.initState();
    _loadArchiveStatus();
  }

  Future<void> _loadArchiveStatus() async {
    await AsyncErrorHandler.execute<GetHabitQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.errorLoadingArchiveStatus),
      operation: () async {
        return await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
          GetHabitQuery(id: widget.habitId),
        );
      },
      onSuccess: (habit) {
        setState(() {
          _isArchived = habit.isArchived;
        });
      },
    );
  }

  Future<void> _toggleArchiveStatus() async {
    final newStatus = !(_isArchived ?? false);

    final confirmed = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.min,
      child: AlertDialog(
        title: Text(_translationService.translate(
          _isArchived! ? HabitTranslationKeys.unarchiveHabit : HabitTranslationKeys.archiveHabit,
        )),
        content: Text(_translationService.translate(
          _isArchived! ? HabitTranslationKeys.unarchiveHabitConfirm : HabitTranslationKeys.archiveHabitConfirm,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate(
              _isArchived! ? HabitTranslationKeys.unarchiveHabit : HabitTranslationKeys.archiveHabit,
            )),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        await AsyncErrorHandler.executeVoid(
          context: context,
          errorMessage: _translationService.translate(HabitTranslationKeys.errorTogglingArchive),
          operation: () async {
            final habit = await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(
              GetHabitQuery(id: widget.habitId),
            );

            if (newStatus) {
              habit.setArchived();
            } else {
              habit.setUnarchived();
            }

            await _mediator.send(SaveHabitCommand(
              id: habit.id,
              name: habit.name,
              description: habit.description,
              estimatedTime: habit.estimatedTime,
              archivedDate: habit.archivedDate,
              hasReminder: habit.hasReminder,
              reminderTime: habit.reminderTime,
              reminderDays: habit.getReminderDaysAsList(),
            ));
          },
          onSuccess: () {
            setState(() {
              _isArchived = newStatus;
            });

            // Notify that the habit has been updated
            _habitsService.notifyHabitUpdated(widget.habitId);

            widget.onArchiveSuccess?.call();

            if (kDebugMode) {
              DomainLogger.debug(
                ' HabitArchiveButton: Habit ${newStatus ? "archived" : "unarchived"} successfully: ${widget.habitId}',
              );
            }
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isArchived == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: Icon(_isArchived! ? Icons.unarchive : Icons.archive),
      tooltip: widget.tooltip ??
          _translationService.translate(
            _isArchived! ? HabitTranslationKeys.unarchiveHabitTooltip : HabitTranslationKeys.archiveHabitTooltip,
          ),
      onPressed: _toggleArchiveStatus,
      color: widget.buttonColor ?? _themeService.primaryColor,
      style: IconButton.styleFrom(
        backgroundColor: widget.buttonBackgroundColor,
      ),
    );
  }
}
