import 'dart:io';
import 'base_desktop_app_usage_service.dart';

class LinuxAppUsageService extends BaseDesktopAppUsageService {
  LinuxAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
  );

  @override
  Future<String?> getActiveWindow() async {
    const scriptPath = 'linux/getActiveWindow.bash';
    final result = await Process.run('bash', ["${Directory.current.path}/$scriptPath"]);
    return result.stdout.trim();
  }
}
