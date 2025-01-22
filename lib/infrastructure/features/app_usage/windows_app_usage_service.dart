import 'dart:io';
import 'base_desktop_app_usage_service.dart';

class WindowsAppUsageService extends BaseDesktopAppUsageService {
  WindowsAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
  );

  @override
  Future<String?> getActiveWindow() async {
    const scriptPath = 'windows/getActiveWindow.ps1';
    final result = await Process.run('powershell', ["-File", "${Directory.current.path}/$scriptPath"]);
    return result.stdout.trim();
  }
}
