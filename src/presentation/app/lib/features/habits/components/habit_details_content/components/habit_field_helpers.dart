import 'package:flutter/material.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';

/// Helper class for habit field labels and icons.
class HabitFieldHelpers {
  static const String keyTags = 'tags';
  static const String keyEstimatedTime = 'estimatedTime';
  static const String keyElapsedTime = 'elapsedTime';
  static const String keyTimer = 'timer';
  static const String keyDescription = 'description';
  static const String keyReminder = 'reminder';
  static const String keyGoal = 'goal';

  static String getFieldLabel(String fieldKey, ITranslationService translationService) {
    switch (fieldKey) {
      case keyTags:
        return translationService.translate(HabitTranslationKeys.tagsLabel);
      case keyEstimatedTime:
        return translationService.translate(SharedTranslationKeys.timeDisplayEstimated);
      case keyDescription:
        return translationService.translate(HabitTranslationKeys.descriptionLabel);
      case keyReminder:
        return translationService.translate(HabitTranslationKeys.enableReminders);
      case keyGoal:
        return translationService.translate(HabitTranslationKeys.goalSettings);
      case keyElapsedTime:
        return translationService.translate(SharedTranslationKeys.timeDisplayElapsed);
      case keyTimer:
        return translationService.translate(SharedTranslationKeys.timerLabel);
      default:
        return '';
    }
  }

  static IconData getFieldIcon(String fieldKey) {
    switch (fieldKey) {
      case keyTags:
        return TagUiConstants.tagIcon;
      case keyEstimatedTime:
        return HabitUiConstants.estimatedTimeIcon;
      case keyDescription:
        return HabitUiConstants.descriptionIcon;
      case keyReminder:
        return Icons.notifications;
      case keyGoal:
        return Icons.track_changes;
      case keyElapsedTime:
        return HabitUiConstants.estimatedTimeIcon;
      case keyTimer:
        return Icons.timer;
      default:
        return Icons.add;
    }
  }
}
