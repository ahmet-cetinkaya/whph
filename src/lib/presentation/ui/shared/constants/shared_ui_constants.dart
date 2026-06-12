import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class SharedUiConstants {
  // Common Icons
  static const IconData addIcon = Icons.add;
  static const IconData deleteIcon = Icons.delete;
  static const IconData sendIcon = Icons.send;
  static const IconData loadingIcon = Icons.hourglass_empty;
  static const IconData settingsIcon = Icons.settings;
  static const IconData searchIcon = Icons.search;
  static const IconData filterIcon = Icons.filter_list;
  static const IconData clearIcon = Icons.clear;
  static const IconData moreIcon = Icons.more_vert;
  static const IconData closeIcon = Icons.close;
  static const IconData checkIcon = Icons.check;
  static const IconData saveIcon = Icons.save;
  static const IconData editIcon = Icons.edit;
  static const IconData calendarIcon = Icons.calendar_today;
  static const IconData helpIcon = Icons.lightbulb_outline;

  // Time formatting
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatMinutes(int? minutes) {
    if (minutes == null) return '';
    return '${minutes}m';
  }

  /// Converts [minutes] to a human-readable format with days, hours, minutes.
  /// Uses the translation service to get localized strings.
  static String formatDurationHuman(int? minutes, ITranslationService translationService) {
    if (minutes == null || minutes <= 0) return translationService.translate(SharedTranslationKeys.notSetTime);
    if (minutes < 60) return '$minutes${translationService.translate(SharedTranslationKeys.minutesShort)}';
    final daysCount = minutes ~/ 1440;
    final remainingAfterDays = minutes % 1440;
    final hoursCount = remainingAfterDays ~/ 60;
    final remainingMinutes = remainingAfterDays % 60;

    final parts = <String>[];
    if (daysCount > 0) parts.add('$daysCount${translationService.translate(SharedTranslationKeys.daysShort)}');
    if (hoursCount > 0) parts.add('$hoursCount${translationService.translate(SharedTranslationKeys.hoursShort)}');
    if (remainingMinutes > 0)
      parts.add('$remainingMinutes${translationService.translate(SharedTranslationKeys.minutesShort)}');
    return parts.join(' ');
  }

  // Debounce durations
  static const Duration contentSaveDebounceTime = Duration(milliseconds: 300);
  static const Duration searchDebounceTime = Duration(milliseconds: 300);
}
