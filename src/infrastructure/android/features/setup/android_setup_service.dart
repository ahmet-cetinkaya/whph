import 'dart:io';
import 'package:domain/shared/utils/logger.dart';
import 'package:infrastructure_shared/features/setup/services/abstraction/base_setup_service.dart';

class AndroidSetupService extends BaseSetupService {
  @override
  Future<void> setupEnvironment() async {
    if (!Platform.isAndroid) return;
    // No setup required for Android
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    // APK installation is disabled for store distribution
    DomainLogger.info('APK installation is disabled for store distribution. Please update through the app store.');
  }
}
