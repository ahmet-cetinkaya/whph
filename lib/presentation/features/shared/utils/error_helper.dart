import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/domain/features/shared/constants/app_info.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';

class ErrorHelper {
  static void showError(BuildContext context, Exception error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: AppTheme.errorColor));
  }

  static void showUnexpectedError(BuildContext context, Exception error, StackTrace stackTrace,
      {String message = 'An unexpected error occurred.'}) {
    if (kDebugMode) {
      print('Error: $error');
      print('Stack trace: $stackTrace');
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

  static void _sendErrorReport(Exception error, StackTrace stackTrace) {
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
