import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class ReminderHelper {
  static String getReminderText(
    ReminderTime? reminderTime,
    ITranslationService translationService, [
    int? customOffset,
  ]) {
    return switch (reminderTime) {
      null || ReminderTime.none => translationService.translate(TaskTranslationKeys.reminderNone),
      ReminderTime.atTime => translationService.translate(TaskTranslationKeys.reminderAtTime),
      ReminderTime.fiveMinutesBefore => translationService.translate(TaskTranslationKeys.reminderFiveMinutesBefore),
      ReminderTime.fifteenMinutesBefore =>
        translationService.translate(TaskTranslationKeys.reminderFifteenMinutesBefore),
      ReminderTime.oneHourBefore => translationService.translate(TaskTranslationKeys.reminderOneHourBefore),
      ReminderTime.oneDayBefore => translationService.translate(TaskTranslationKeys.reminderOneDayBefore),
      ReminderTime.custom => customOffset != null
          ? formatCustomOffset(customOffset, translationService)
          : translationService.translate(TaskTranslationKeys.reminderCustom),
    };
  }

  static String formatCustomOffset(int offset, ITranslationService translationService) {
    String valueStr;
    String unitKey;

    if (offset % (60 * 24 * 7) == 0) {
      final value = offset ~/ (60 * 24 * 7);
      valueStr = value.toString();
      unitKey = value == 1 ? TaskTranslationKeys.reminderWeek : TaskTranslationKeys.weeks;
    } else if (offset % (60 * 24) == 0) {
      final value = offset ~/ (60 * 24);
      valueStr = value.toString();
      unitKey = value == 1 ? TaskTranslationKeys.reminderDay : TaskTranslationKeys.days;
    } else if (offset % 60 == 0) {
      final value = offset ~/ 60;
      valueStr = value.toString();
      unitKey = value == 1 ? TaskTranslationKeys.reminderHour : TaskTranslationKeys.hours;
    } else {
      valueStr = offset.toString();
      unitKey = offset == 1 ? TaskTranslationKeys.reminderMinute : TaskTranslationKeys.minutes;
    }

    return '$valueStr ${translationService.translate(unitKey)} ${translationService.translate(TaskTranslationKeys.reminderBeforeSuffix)}';
  }
}
