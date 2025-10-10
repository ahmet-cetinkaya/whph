import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class SyncErrorHandler {
  static final _translationService = container.resolve<ITranslationService>();

  static void showSyncError({
    required BuildContext context,
    required String errorKey,
    Map<String, String>? errorParams,
    Duration duration = const Duration(seconds: 5),
  }) {
    final translatedMessage = _translationService.translate(errorKey, namedArgs: errorParams);

    OverlayNotificationHelper.showError(
      context: context,
      message: translatedMessage,
      duration: duration,
    );
  }

  static void showMultipleSyncErrors({
    required BuildContext context,
    required List<String> errorKeys,
    Duration duration = const Duration(seconds: 6),
  }) {
    if (errorKeys.isEmpty) return;

    final firstErrorMessage = _translationService.translate(errorKeys.first);

    OverlayNotificationHelper.showError(
      context: context,
      message: firstErrorMessage,
      duration: duration,
    );
  }

  static void showSyncSuccess({
    required BuildContext context,
    required String messageKey,
    Duration duration = const Duration(seconds: 3),
  }) {
    final translatedMessage = _translationService.translate(messageKey);

    OverlayNotificationHelper.showSuccess(
      context: context,
      message: translatedMessage,
      duration: duration,
    );
  }
}
