import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:whph/domain/shared/constants/app_info.dart';

class UpdateChecker {
  static Future<void> checkForUpdates(BuildContext context) async {
    final response = await http.get(Uri.parse(AppInfo.updateCheckerUrl));
    if (response.statusCode != 200) return;

    final data = json.decode(response.body);
    final latestVersion =
        (data['tag_name'] as String).substring(1); // With remove the 'v' prefix from the version number
    if (latestVersion != AppInfo.version && context.mounted) {
      _showUpdateModal(context, data['html_url']);
    }
  }

  static void _showUpdateModal(BuildContext context, String releaseUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update Available!'),
          content: Text('A new version of the app is available. Please update to the latest version.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Later'),
            ),
            TextButton(
              onPressed: () async {
                bool isOpened = await launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication);
                if (!isOpened) {
                  throw Exception("Could not open the url");
                }
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }
}
