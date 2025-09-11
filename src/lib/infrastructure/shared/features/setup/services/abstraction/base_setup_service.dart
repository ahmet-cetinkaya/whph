import 'dart:io';
import 'dart:convert';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:path/path.dart' as path;
import 'package:whph/main.dart';
import 'package:whph/infrastructure/shared/features/setup/models/update_info.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';

abstract class BaseSetupService implements ISetupService {
  @override
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      Logger.debug('Checking for updates...');

      final response = await http.get(
        Uri.parse(AppInfo.updateCheckerUrl),
        headers: {'User-Agent': 'WHPH/${AppInfo.version}'},
      ).timeout(const Duration(seconds: 10));

      Logger.debug('Update check response: ${response.statusCode}');

      if (response.statusCode != 200) {
        Logger.error('Update check failed with status: ${response.statusCode}');
        return;
      }

      final data = json.decode(response.body);
      final updateInfo = UpdateInfo.fromGitHubRelease(data, AppInfo.version);

      Logger.debug('Current version: ${AppInfo.version}');
      Logger.debug('Latest version: ${updateInfo.version}');
      Logger.debug('Has update: ${updateInfo.hasUpdate}');

      if (updateInfo.hasUpdate && context.mounted) {
        _showUpdateDialog(context, updateInfo);
      }
    } catch (e) {
      Logger.error('Failed to check for updates: $e');
      // In debug mode, also show a brief notification about the failure
      if (kDebugMode && context.mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: 'Update check failed: ${e.toString()}',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    // Ensure we have a valid context and the widget is still mounted
    if (!context.mounted) {
      Logger.debug('Context not mounted, skipping update dialog');
      return;
    }

    final translationService = container.resolve<ITranslationService>();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        title: Text(translationService.translate(SharedTranslationKeys.updateAvailableTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(translationService.translate(
              SharedTranslationKeys.updateAvailableMessage,
              namedArgs: {'version': updateInfo.version},
            )),
            const SizedBox(height: 8),
            Text(translationService.translate(SharedTranslationKeys.updateQuestionMessage)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _dismissUpdateDialog(context),
            child: Text(translationService.translate(SharedTranslationKeys.updateLaterButton)),
          ),
          TextButton(
            onPressed: () => _openReleaseUrl(updateInfo.releaseUrl),
            child: Text(translationService.translate(SharedTranslationKeys.updateDownloadPageButton)),
          ),
          if (updateInfo.platformSpecificDownloadUrl != null)
            TextButton(
              onPressed: () => _downloadAndInstallUpdate(context, updateInfo.platformSpecificDownloadUrl!),
              child: Text(translationService.translate(SharedTranslationKeys.updateNowButton)),
            ),
        ],
      ),
    );
  }

  Future<void> downloadAndInstallUpdate(String downloadUrl);

  void _dismissUpdateDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  Future<void> _openReleaseUrl(String releaseUrl) async {
    final url = Uri.parse(releaseUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _downloadAndInstallUpdate(BuildContext context, String downloadUrl) async {
    final translationService = container.resolve<ITranslationService>();

    // Close the update dialog
    Navigator.of(context).pop();

    // Show loading overlay
    if (context.mounted) {
      OverlayNotificationHelper.showLoading(
        context: context,
        message: translationService.translate(SharedTranslationKeys.updateDownloadingMessage),
        duration: const Duration(minutes: 10), // Long duration for download
      );
    }

    try {
      await downloadAndInstallUpdate(downloadUrl);

      // Hide loading overlay and show success (though this might not be seen if app exits)
      OverlayNotificationHelper.hideNotification();
      if (context.mounted) {
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: translationService.translate(SharedTranslationKeys.updateSuccessMessage),
        );
      }
    } catch (e) {
      // Hide loading overlay
      OverlayNotificationHelper.hideNotification();

      if (context.mounted) {
        OverlayNotificationHelper.showError(
          context: context,
          message: translationService.translate(SharedTranslationKeys.updateFailedMessage),
        );
      }
    }
  }

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
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'WHPH/${AppInfo.version}'},
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to download file: HTTP ${response.statusCode}');
    }

    await File(savePath).writeAsBytes(response.bodyBytes);
  }

  Future<void> runDetachedProcess(String executable, List<String> arguments) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }

  Future<void> makeFileExecutable(String filePath) async {
    if (Platform.isLinux) {
      await Process.run('chmod', ['+x', filePath]);
    }
  }

  // Firewall rule management methods with default implementations
  @override
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'}) async {
    // Default implementation - platforms should override this
    Logger.debug('checkFirewallRule not implemented for this platform');
    return false;
  }

  @override
  Future<void> addFirewallRule({
    required String ruleName,
    required String appPath,
    required String port,
    String protocol = 'TCP',
    String direction = 'in',
  }) async {
    // Default implementation - platforms should override this
    Logger.debug('addFirewallRule not implemented for this platform');
  }

  @override
  Future<void> removeFirewallRule({required String ruleName}) async {
    // Default implementation - platforms should override this
    Logger.debug('removeFirewallRule not implemented for this platform');
  }
}
