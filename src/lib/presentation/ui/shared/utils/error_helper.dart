import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

class ErrorHelper {
  static late ITranslationService _translationService;

  static void initialize(ITranslationService translationService) {
    _translationService = translationService;
  }

  static void showError(BuildContext context, Exception error, {NotificationPosition position = NotificationPosition.bottom}) {
    final message = error is BusinessException
        ? _translationService.translate(error.errorCode, namedArgs: error.args)
        : error.toString();

    OverlayNotificationHelper.showError(
      context: context,
      message: message,
      position: position,
    );
  }

  static void showUnexpectedError(BuildContext context, Object error, StackTrace stackTrace,
      {String? message, NotificationPosition position = NotificationPosition.bottom}) {
    final errorMessage = message ?? _translationService.translate(SharedTranslationKeys.unexpectedError);
    final reportText = _translationService.translate(
      SharedTranslationKeys.reportError,
      namedArgs: {'appName': AppInfo.name},
    );

    OverlayNotificationHelper.showError(
      context: context,
      message: errorMessage,
      duration: const Duration(seconds: 8),
      actionWidget: FilledButton.icon(
        onPressed: () => sendErrorReport(error, stackTrace),
        icon: Icon(Icons.send, size: AppTheme.iconSizeSmall),
        label: Text(reportText),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      ),
      position: position,
    );
  }

  /// Sends an error report via email
  static void sendErrorReport(Object error, StackTrace stackTrace) {
    final errorBody = _translationService.translate(
      SharedTranslationKeys.errorReportTemplate,
      namedArgs: {
        'appName': AppInfo.name,
        'version': AppInfo.version,
        'device': Platform.localHostname,
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    );

    final subject = Uri.encodeFull(_translationService.translate(
      SharedTranslationKeys.errorReportSubject,
      namedArgs: {'appName': AppInfo.name},
    ));
    final body = Uri.encodeFull(errorBody).replaceAll('+', '%20');

    final emailUrl = 'mailto:${AppInfo.supportEmail}?subject=$subject&body=$body';

    launchUrl(
      Uri.parse(emailUrl),
      mode: LaunchMode.platformDefault,
    );
  }
}
