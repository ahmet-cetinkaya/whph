import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class ErrorHelper {
  static bool _isShowingError = false;
  static late ITranslationService _translationService;

  static void initialize(ITranslationService translationService) {
    _translationService = translationService;
  }

  static void showError(BuildContext context, Exception error) {
    if (_isShowingError) return;
    _isShowingError = true;

    final message = error is BusinessException
        ? _translationService.translate(error.messageKey, namedArgs: error.args)
        : error.toString();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 5),
        onVisible: () => _isShowingError = false,
      ),
    );
  }

  static void showUnexpectedError(BuildContext context, Object error, StackTrace stackTrace,
      {String message = 'An unexpected error occurred.'}) {
    if (_isShowingError) return;
    _isShowingError = true;

    if (kDebugMode) {
      if (kDebugMode) debugPrint('ERROR: $error');
      if (kDebugMode) debugPrint('ERROR: Stack trace: $stackTrace');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('Report', style: TextStyle(color: Colors.white)),
              onPressed: () => _sendErrorReport(error, stackTrace),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  static void _sendErrorReport(Object error, StackTrace stackTrace) {
    final errorBody = "Hi, I encountered an unexpected error while using the WHPH app. \n\n"
        "Here's information that might help you diagnose the issue: \n"
        "App Version: ${AppInfo.version} \n"
        "Device Info: ${Platform.localHostname} \n"
        "OS: ${Platform.operatingSystem} \n"
        "OS Version: ${Platform.operatingSystemVersion} \n"
        "Error Message: \n"
        "```\n"
        "$error:  \n"
        "Stack Trace: \n"
        "$stackTrace \n"
        "```\n\n"
        "Please help me resolve this issue. \n\n"
        "Thanks!";

    final subject = Uri.encodeFull('WHPH App: Unexpected Error Report');
    final body = Uri.encodeFull(errorBody).replaceAll('+', '%20');

    final emailUrl = 'mailto:${AppInfo.supportEmail}?subject=$subject&body=$body';

    launchUrl(
      Uri.parse(emailUrl),
      mode: LaunchMode.platformDefault,
    );
  }
}
