import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'abstraction/base_setup_service.dart';

class AndroidSetupService extends BaseSetupService {
  static const platform = MethodChannel('me.ahmetcetinkaya.whph/app_installer');

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

      // Install APK using system package installer
      await platform.invokeMethod('installApk', {'filePath': downloadPath});

      // Android system will handle the installation process
      exit(0);
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to download and install update: $e');
      rethrow;
    }
  }
}
