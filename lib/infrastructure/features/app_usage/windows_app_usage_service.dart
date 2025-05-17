import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'base_desktop_app_usage_service.dart';

class WindowsAppUsageService extends BaseDesktopAppUsageService {
  WindowsAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.settingRepository,
  );

  String get _scriptPath {
    final exePath = Platform.resolvedExecutable;
    final exeDir = path.dirname(exePath);
    final scriptPath = path.join(exeDir, 'data', 'flutter_assets', 'windows', 'getActiveWindow.ps1');
    return scriptPath;
  }

  @override
  Future<String?> getActiveWindow() async {
    try {
      if (!File(_scriptPath).existsSync()) {
        if (kDebugMode) debugPrint('Script not found at: $_scriptPath');
        return null;
      }

      final result = await Process.run('powershell', ["-ExecutionPolicy", "Bypass", "-File", _scriptPath]);

      if (result.exitCode != 0) {
        if (kDebugMode) debugPrint('PowerShell error: ${result.stderr}');
        return null;
      }

      return result.stdout.trim();
    } catch (e) {
      if (kDebugMode) debugPrint('Error running PowerShell script: $e');
      return null;
    }
  }
}
