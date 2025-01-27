import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/domain/shared/constants/app_info.dart';
import 'package:whph/infrastructure/features/setup/models/update_info.dart';
import 'package:path/path.dart' as path;

abstract class BaseSetupService implements ISetupService {
  @override
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(AppInfo.updateCheckerUrl));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final updateInfo = UpdateInfo.fromGitHubRelease(data, AppInfo.version);

      if (updateInfo.hasUpdate && context.mounted) {
        _showUpdateDialog(context, updateInfo);
      }
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to check for updates: $e');
    }
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version (${updateInfo.version}) is available.'),
            const SizedBox(height: 8),
            const Text('Would you like to update now?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () async {
              final url = Uri.parse(updateInfo.releaseUrl);
              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                throw Exception('Could not launch $url');
              }
            },
            child: const Text('Download Page'),
          ),
          if (updateInfo.platformSpecificDownloadUrl != null)
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.of(context).pop();
                  await downloadAndInstallUpdate(updateInfo.platformSpecificDownloadUrl!);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e')),
                    );
                  }
                }
              },
              child: const Text('Update Now'),
            ),
        ],
      ),
    );
  }

  Future<void> downloadAndInstallUpdate(String downloadUrl);

  // Common file and directory operations
  Future<void> createDirectories(List<String> dirs) async {
    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }
  }

  Future<void> copyFile(String source, String target) async {
    if (await File(source).exists()) {
      await File(source).copy(target);
    }
  }

  Future<void> writeFile(String filePath, String content) async {
    await File(filePath).writeAsString(content);
  }

  // Common paths
  String getExecutablePath() => Platform.resolvedExecutable;
  String getApplicationDirectory() => path.dirname(getExecutablePath());

  // Common update related operations
  Future<void> downloadFile(String url, String savePath) async {
    final response = await http.get(Uri.parse(url));
    await File(savePath).writeAsBytes(response.bodyBytes);
  }

  Future<void> runDetachedProcess(String executable, List<String> arguments) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }

  Future<void> makeFileExecutable(String filePath) async {
    if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['+x', filePath]);
    }
  }
}
