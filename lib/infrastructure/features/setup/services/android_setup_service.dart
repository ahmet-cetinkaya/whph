import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'abstraction/base_setup_service.dart';

class AndroidSetupService extends BaseSetupService {
  @override
  Future<void> setupEnvironment() async {
    if (!Platform.isAndroid) return;
    // No setup required for Android
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final downloadPath = path.join(tempDir.path, 'whph_update.apk');

      // Download APK
      await downloadFile(downloadUrl, downloadPath);
      await makeFileExecutable(downloadPath);

      // Install APK using package installer
      final uri = Uri.file(downloadPath);
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      )) {
        throw Exception('Could not launch package installer');
      }

      // Android system will handle the installation process
      exit(0);
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to download and install update: $e');
      rethrow;
    }
  }
}
