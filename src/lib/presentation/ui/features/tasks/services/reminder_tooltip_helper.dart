import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

/// Helper utility for generating context-aware reminder tooltip text
class ReminderTooltipHelper {
  /// Generates tooltip text for reminder icon buttons based on current state
  ///
  /// [translationService] - The translation service for localized text
  /// [currentReminder] - The current reminder time setting
  /// [date] - The date associated with the reminder (can be null)
  ///
  /// Returns appropriate tooltip text based on the current reminder state:
  /// - If no date is set: Shows "date required" message
  /// - If no reminder is set: Shows "Set reminder" message
  /// - If reminder is configured: Shows only the reminder type like "At Moment" or "1 Hour Before"
  static String getReminderTooltip({
    required ITranslationService translationService,
    required ReminderTime currentReminder,
    required DateTime? date,
  }) {
    // Handle no date case
    if (date == null) {
      return translationService.translate(TaskTranslationKeys.reminderDateRequiredTooltip);
    }

    // Handle no reminder case
    if (currentReminder == ReminderTime.none) {
      return translationService.translate(TaskTranslationKeys.setReminderTooltip);
    }

    // Show only the reminder type (no date prefix)
    final reminderTypeKey = TaskTranslationKeys.getReminderTypeKey(currentReminder);
    final reminderType = translationService.translate(reminderTypeKey);

    return reminderType;
  }
}
