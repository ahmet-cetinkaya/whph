import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/domain/features/shared/constants/app_info.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';

class ErrorHelper {
  static void showError(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: AppTheme.errorColor));
  }

  static void showUnexpectedError(BuildContext context, dynamic error,
      {String message = 'An unexpected error occurred.'}) {
    if (kDebugMode) {
      throw error;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(
              flex: 9,
              child: Text(message),
            ),
            Expanded(
              flex: 1,
              child: TextButton.icon(
                icon: Icon(Icons.send),
                label: Text('Report'),
                onPressed: () {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: AppInfo.supportEmail,
                    queryParameters: {
                      'subject': 'WHPH App: Unexpected Error Report',
                      'body': "Hi, I encountered an unexpected error while using the WHPH app. \n\n"
                          "Here's information that might help you diagnose the issue: \n"
                          "App Version: ${AppInfo.version} \n"
                          "Device Info: ${Platform.localHostname} \n"
                          "OS: ${Platform.operatingSystem} \n"
                          "OS Version: ${Platform.operatingSystemVersion} \n"
                          "Error Message: \n"
                          "```\n"
                          "${error.toString()} \n"
                          "```\n\n"
                          "Please help me resolve this issue. \n\n"
                          "Thanks!",
                    },
                  );
                  launchUrl(emailLaunchUri);
                },
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(AppTheme.surface1),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }
}
