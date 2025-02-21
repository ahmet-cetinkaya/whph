import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

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

  // Date Formats
  static const String defaultDateFormat = 'dd.MM.yy';
  static const String defaultDateTimeFormat = 'yyyy-MM-dd HH:mm';

  // Dialog & Modal
  static const String confirmLabel = 'Confirm';
  static const String cancelLabel = 'Cancel';
  static const String deleteLabel = 'Delete';
  static const String saveLabel = 'Save';

  // Messages
  static const String confirmDeleteTitle = 'Confirm Delete';
  static const String confirmDeleteMessage = 'Are you sure you want to delete this item?';
  static const String successMessage = 'Operation completed successfully';
  static const String errorMessage = 'An error occurred';
  static const String addDescriptionHint = 'Add a description...';
  static const String markdownEditorHint = 'Tap to edit markdown text';

  // Error Messages
  static const String errorLoadingData = 'Failed to load data';
  static const String errorSavingData = 'Failed to save data';
  static const String errorDeletingData = 'Failed to delete data';
  static const String errorUnexpected = 'An unexpected error occurred';

  // Time formatting
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatMinutes(int? minutes) {
    if (minutes == null) return 'Not set';
    return '${minutes}m';
  }

  /// Converts [minutes] to a human-readable format.
  /// Uses the translation service to get localized strings.
  static String formatDurationHuman(int? minutes, ITranslationService translationService) {
    if (minutes == null) return translationService.translate(SharedTranslationKeys.notSetTime);
    if (minutes < 60) {
      return '$minutes${translationService.translate(SharedTranslationKeys.minutes)}';
    }
    final hoursCount = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hoursCount${translationService.translate(SharedTranslationKeys.hours)}';
    }
    return '$hoursCount${translationService.translate(SharedTranslationKeys.hours)} $remainingMinutes${translationService.translate(SharedTranslationKeys.minutes)}';
  }
}
