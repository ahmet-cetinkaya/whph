import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/core/application/features/habits/services/habit_day_state_resolver.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';

/// How a single bad-habit day should look and be announced.
class HabitDayVisual {
  final IconData icon;
  final Color color;
  final String statusKey;
  final String actionKey;
  final bool isInteractive;

  const HabitDayVisual({
    required this.icon,
    required this.color,
    required this.statusKey,
    required this.actionKey,
    required this.isInteractive,
  });
}

/// Presentation adapter over the shared [HabitDayStateResolver] policy.
///
/// Widgets receive list DTOs rather than domain entities, so this builds the
/// throwaway domain shapes the resolver needs and maps the resulting state to
/// icons, colors, and translation keys. Bad habits are binary by construction,
/// so the global three-state visual cycle never reaches them.
class HabitDayPresenter {
  static const _resolver = HabitDayStateResolver();

  final HabitDayStateSource _source;
  final HabitType _habitType;

  HabitDayPresenter._(this._source, this._habitType);

  factory HabitDayPresenter({
    required String habitId,
    required HabitType habitType,
    required DateTime? createdDate,
    required DateTime? archivedDate,
    required List<HabitRecordListItem>? records,
    DateTime? now,
  }) {
    final habit = Habit(
      id: habitId,
      createdDate: createdDate ?? DateTime(1970),
      type: habitType,
      name: '',
      description: '',
      archivedDate: archivedDate,
    );

    return HabitDayPresenter._(
      _resolver.createSource(
        habit: habit,
        records: (records ?? const <HabitRecordListItem>[]).map(
          (record) => HabitRecord(
            id: record.id,
            createdDate: record.occurredAt,
            habitId: habitId,
            occurredAt: record.occurredAt,
            status: record.status,
          ),
        ),
        now: now ?? DateTime.now(),
      ),
      habitType,
    );
  }

  HabitDayState resolve(DateTime date) => _source.resolve(date);

  /// True when a completed toggle on [date] left the habit in a state worth
  /// celebrating. Avoiding a bad habit is the absence of a failure, not an
  /// achievement, so only good habits ever qualify.
  bool isCelebratedSuccess(DateTime date) => _habitType == HabitType.good && resolve(date) == HabitDayState.successful;

  HabitDayVisual visualFor(DateTime date) {
    return switch (resolve(date)) {
      HabitDayState.successful => const HabitDayVisual(
          icon: HabitUiConstants.badSuccessIcon,
          color: HabitUiConstants.completedColor,
          statusKey: HabitTranslationKeys.statusAvoided,
          actionKey: HabitTranslationKeys.actionMarkPerformed,
          isInteractive: true,
        ),
      HabitDayState.failed => const HabitDayVisual(
          icon: HabitUiConstants.noRecordIcon,
          color: HabitUiConstants.inCompletedColor,
          statusKey: HabitTranslationKeys.statusPerformed,
          actionKey: HabitTranslationKeys.actionUndo,
          isInteractive: true,
        ),
      HabitDayState.notApplicable || HabitDayState.incomplete || HabitDayState.partial => HabitDayVisual(
          icon: HabitUiConstants.notApplicableIcon,
          color: HabitUiConstants.notApplicableColor,
          statusKey: HabitTranslationKeys.statusSkipped,
          actionKey: HabitTranslationKeys.actionMarkAvoided,
          isInteractive: false,
        ),
    };
  }
}
