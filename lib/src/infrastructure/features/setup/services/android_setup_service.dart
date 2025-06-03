import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/infrastructure/android/constants/android_app_constants.dart';
import 'abstraction/base_setup_service.dart';

class AndroidSetupService extends BaseSetupService {
  static final platform = MethodChannel(AndroidAppConstants.channels.appInstaller);

  @override
  Future<void> setupEnvironment() async {
    if (!Platform.isAndroid) return;
    // No setup required for Android
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      if (kDebugMode) debugPrint('Starting APK download from: $downloadUrl');

      final tempDir = await getTemporaryDirectory();
      final downloadPath = path.join(tempDir.path, '${AppInfo.shortName.toLowerCase()}_update.apk');

      if (kDebugMode) debugPrint('Downloading APK to: $downloadPath');

      // Download APK with timeout
      await downloadFile(downloadUrl, downloadPath);

      // Verify the file was downloaded
      final file = File(downloadPath);
      if (!await file.exists()) {
        throw Exception('Downloaded APK file not found');
      }

      final fileSize = await file.length();
      if (kDebugMode) debugPrint('APK downloaded successfully, size: $fileSize bytes');

      await makeFileExecutable(downloadPath);

      if (kDebugMode) debugPrint('Installing APK using platform channel');

      // Install APK using system package installer
      await platform.invokeMethod('installApk', {'filePath': downloadPath});

      // Android system will handle the installation process
      exit(0);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to download and install update: $e');
      rethrow;
    }
  }
}
