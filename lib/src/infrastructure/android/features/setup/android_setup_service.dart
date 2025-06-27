import 'dart:io';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:whph/src/infrastructure/shared/features/setup/services/abstraction/base_setup_service.dart';

class AndroidSetupService extends BaseSetupService {
  @override
  Future<void> setupEnvironment() async {
    if (!Platform.isAndroid) return;
    // No setup required for Android
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    // APK installation is disabled for store distribution
    Logger.info('APK installation is disabled for store distribution. Please update through the app store.');
  }
}
