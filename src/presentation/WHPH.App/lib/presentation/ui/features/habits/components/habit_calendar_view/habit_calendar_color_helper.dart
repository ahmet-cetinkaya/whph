import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';

/// Helper class for calculating colors and badge properties in habit calendar view.
/// Extracts complex color logic based on goal types and completion status.
class HabitCalendarColorHelper {
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;
  final int dailyTarget;

  const HabitCalendarColorHelper({
    required this.hasGoal,
    required this.targetFrequency,
    required this.periodDays,
    required this.dailyTarget,
  });

  /// Determine if badge should be shown
  bool shouldShowBadge() {
    return dailyTarget > 1 || (periodDays > 1 && targetFrequency > 1);
  }

  /// Determine if badge should be shown for this specific day
  bool shouldShowBadgeForThisDay({
    required bool hasRecords,
    required bool isPeriodGoalMet,
    required int dailyCompletionCount,
  }) {
    if (dailyCompletionCount == 0) return false;

    if (periodDays > 1) {
      if (dailyTarget > 1) {
        return hasRecords;
      } else {
        return true;
      }
    } else {
      return true;
    }
  }

  /// Get appropriate badge color based on goal type and completion status
  Color getBadgeColor({
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required bool hasRecords,
    required int periodCompletionCount,
  }) {
    if (periodDays > 1) {
      if (dailyTarget > 1) {
        return isDailyGoalMet
            ? Colors.green
            : hasRecords
                ? Colors.orange
                : Colors.red.withValues(alpha: 0.7);
      } else {
        return isPeriodGoalMet
            ? Colors.green
            : periodCompletionCount > 0
                ? Colors.orange
                : Colors.red.withValues(alpha: 0.7);
      }
    } else if (dailyTarget > 1) {
      return isDailyGoalMet
          ? Colors.green
          : hasRecords
              ? Colors.orange
              : Colors.red.withValues(alpha: 0.7);
    }
    return Colors.grey;
  }

  /// Get appropriate badge text based on goal type
  String getBadgeText({
    required int dailyCompletionCount,
    required int periodCompletionCount,
  }) {
    if (periodDays > 1) {
      if (dailyTarget > 1) {
        return '$dailyCompletionCount';
      } else {
        return '$periodCompletionCount';
      }
    } else if (dailyTarget > 1) {
      return '$dailyCompletionCount';
    }
    return '0';
  }

  /// Get background color for calendar day based on goal type and achievement
  Color getBackgroundColorForDay({
    required bool isCurrentMonth,
    required bool isFutureDate,
    required bool hasRecords,
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required int dailyCompletionCount,
    required int periodCompletionCount,
    HabitRecordStatus? status,
  }) {
    if (isFutureDate) return AppTheme.surface1;
    if (!isCurrentMonth) return AppTheme.surface1.withValues(alpha: 0.5);

    if (hasGoal) {
      return _getGoalBasedBackgroundColor(
        hasRecords: hasRecords,
        isDailyGoalMet: isDailyGoalMet,
        isPeriodGoalMet: isPeriodGoalMet,
        dailyCompletionCount: dailyCompletionCount,
        periodCompletionCount: periodCompletionCount,
      );
    } else {
      return _getSimpleHabitBackgroundColor(status);
    }
  }

  Color _getGoalBasedBackgroundColor({
    required bool hasRecords,
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required int dailyCompletionCount,
    required int periodCompletionCount,
  }) {
    if (periodDays > 1) {
      return _getPeriodGoalBackgroundColor(
        hasRecords: hasRecords,
        isDailyGoalMet: isDailyGoalMet,
        isPeriodGoalMet: isPeriodGoalMet,
        dailyCompletionCount: dailyCompletionCount,
        periodCompletionCount: periodCompletionCount,
      );
    } else if (dailyTarget > 1) {
      return _getDailyTargetBackgroundColor(
        hasRecords: hasRecords,
        isDailyGoalMet: isDailyGoalMet,
        dailyCompletionCount: dailyCompletionCount,
      );
    } else {
      return _getSimpleDailyGoalBackgroundColor(hasRecords);
    }
  }

  Color _getPeriodGoalBackgroundColor({
    required bool hasRecords,
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required int dailyCompletionCount,
    required int periodCompletionCount,
  }) {
    if (dailyTarget > 1) {
      if (isDailyGoalMet && isPeriodGoalMet) {
        return Colors.green.withValues(alpha: 0.2);
      } else if (isDailyGoalMet) {
        return Colors.green.withValues(alpha: 0.15);
      } else if (isPeriodGoalMet) {
        return Colors.green.withValues(alpha: 0.1);
      } else if (hasRecords) {
        final double dailyProgress = dailyCompletionCount / dailyTarget;
        return Color.lerp(Colors.red.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.2), dailyProgress) ??
            Colors.red.withValues(alpha: 0.1);
      } else if (periodCompletionCount > 0) {
        final double periodProgress = periodCompletionCount / targetFrequency;
        return Color.lerp(Colors.red.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.15), periodProgress) ??
            Colors.red.withValues(alpha: 0.1);
      } else {
        return Colors.red.withValues(alpha: 0.05);
      }
    } else {
      if (isPeriodGoalMet) {
        return Colors.green.withValues(alpha: 0.2);
      } else if (periodCompletionCount > 0) {
        final double periodProgress = periodCompletionCount / targetFrequency;
        return Color.lerp(Colors.red.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.15), periodProgress) ??
            Colors.red.withValues(alpha: 0.1);
      } else {
        return Colors.red.withValues(alpha: 0.05);
      }
    }
  }

  Color _getDailyTargetBackgroundColor({
    required bool hasRecords,
    required bool isDailyGoalMet,
    required int dailyCompletionCount,
  }) {
    if (isDailyGoalMet) {
      return Colors.green.withValues(alpha: 0.2);
    } else if (hasRecords) {
      final double dailyProgress = dailyCompletionCount / dailyTarget;
      return Color.lerp(Colors.red.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.2), dailyProgress) ??
          Colors.red.withValues(alpha: 0.1);
    } else {
      return Colors.red.withValues(alpha: 0.05);
    }
  }

  Color _getSimpleDailyGoalBackgroundColor(bool hasRecords) {
    return hasRecords ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.05);
  }

  Color _getSimpleHabitBackgroundColor(HabitRecordStatus? status) {
    switch (status) {
      case HabitRecordStatus.complete:
        return Colors.green.withValues(alpha: 0.2);
      case HabitRecordStatus.notDone:
        return Colors.red.withValues(alpha: 0.2); // More visible than 0.05
      case HabitRecordStatus.skipped:
      default:
        return Colors.grey.withValues(alpha: 0.1); // Neutral
    }
  }

  /// Build appropriate icon based on goal type and completion status
  Widget buildGoalIcon({
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required int dailyCompletionCount,
    required int periodCompletionCount,
    required bool hasRecords,
    HabitRecordStatus? status,
    bool isThreeStateEnabled = false,
  }) {
    if (periodDays > 1) {
      return _buildPeriodGoalIcon(
        isDailyGoalMet: isDailyGoalMet,
        isPeriodGoalMet: isPeriodGoalMet,
        periodCompletionCount: periodCompletionCount,
        hasRecords: hasRecords,
        isThreeStateEnabled: isThreeStateEnabled,
        status: status,
      );
    } else if (dailyTarget > 1) {
      return _buildDailyTargetIcon(
        isDailyGoalMet: isDailyGoalMet,
        dailyCompletionCount: dailyCompletionCount,
        hasRecords: hasRecords,
        isThreeStateEnabled: isThreeStateEnabled,
        status: status,
      );
    } else {
      return _buildSimpleDailyIcon(status: status, isThreeStateEnabled: isThreeStateEnabled);
    }
  }

  Widget _buildPeriodGoalIcon({
    required bool isDailyGoalMet,
    required bool isPeriodGoalMet,
    required int periodCompletionCount,
    required bool hasRecords,
    required bool isThreeStateEnabled,
    HabitRecordStatus? status,
  }) {
    // Helper to get Skipped/NotDone icon
    Widget getSkippedOrNotDoneIcon() {
      if (hasRecords && status == HabitRecordStatus.notDone) {
        return const Icon(Icons.close, color: Colors.red, size: 16);
      }
      return isThreeStateEnabled
          ? const Icon(Icons.question_mark, color: Colors.grey, size: 16)
          : const Icon(Icons.close, color: Colors.red, size: 16);
    }

    if (dailyTarget > 1) {
      if (hasRecords && status != HabitRecordStatus.notDone) {
        if (isDailyGoalMet) {
          return const Icon(Icons.link, color: Colors.green, size: 20);
        } else {
          return const Icon(Icons.add, color: Colors.blue, size: 18);
        }
      } else if (isPeriodGoalMet) {
        return Icon(Icons.link, color: Colors.grey.withValues(alpha: 0.6), size: 18);
      } else if (periodCompletionCount > 0) {
        return const Icon(Icons.link, color: Colors.orange, size: 18);
      } else {
        return getSkippedOrNotDoneIcon();
      }
    } else {
      if (hasRecords && status != HabitRecordStatus.notDone) {
        return const Icon(Icons.link, color: Colors.green, size: 20);
      } else if (isPeriodGoalMet) {
        return Icon(Icons.link, color: Colors.grey.withValues(alpha: 0.6), size: 18);
      } else if (periodCompletionCount > 0) {
        return const Icon(Icons.link, color: Colors.orange, size: 18);
      } else {
        return getSkippedOrNotDoneIcon();
      }
    }
  }

  Widget _buildDailyTargetIcon({
    required bool isDailyGoalMet,
    required int dailyCompletionCount,
    required bool hasRecords,
    required bool isThreeStateEnabled,
    HabitRecordStatus? status,
  }) {
    if (isDailyGoalMet) {
      return const Icon(Icons.link, color: Colors.green, size: 20);
    } else if (dailyCompletionCount > 0) {
      // Must verify it's not a NotDone record (though dailyCompletionCount comes from 'complete' records)
      return const Icon(Icons.add, color: Colors.blue, size: 18);
    } else {
      if (hasRecords && status == HabitRecordStatus.notDone) {
        return const Icon(Icons.close, color: Colors.red, size: 16);
      }
      // Skipped (no records)
      return isThreeStateEnabled
          ? const Icon(Icons.question_mark, color: Colors.grey, size: 16)
          : const Icon(Icons.close, color: Colors.red, size: 16);
    }
  }

  Widget _buildSimpleDailyIcon({HabitRecordStatus? status, required bool isThreeStateEnabled}) {
    switch (status) {
      case HabitRecordStatus.complete:
        return const Icon(Icons.link, color: Colors.green, size: 20);
      case HabitRecordStatus.notDone:
        return const Icon(Icons.close, color: Colors.red, size: 16);
      case HabitRecordStatus.skipped:
      default:
        // Use consistent ? if enabled
        return isThreeStateEnabled
            ? const Icon(Icons.question_mark, color: Colors.grey, size: 16)
            : const Icon(Icons.close, color: Colors.red, size: 16);
    }
  }
}
