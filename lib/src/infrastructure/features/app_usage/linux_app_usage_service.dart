import 'dart:io';
import 'package:path/path.dart' as path;
import 'base_desktop_app_usage_service.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

class LinuxAppUsageService extends BaseDesktopAppUsageService {
  LinuxAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.settingRepository,
  );

  String get _scriptPath {
    final exePath = Platform.resolvedExecutable;
    final exeDir = path.dirname(exePath);
    final scriptPath = path.join(exeDir, 'data', 'flutter_assets', 'linux', 'getActiveWindow.bash');
    return scriptPath;
  }

  @override
  Future<String?> getActiveWindow() async {
    try {
      if (!File(_scriptPath).existsSync()) {
        Logger.warning('Script not found at: $_scriptPath');
        return null;
      }

      await Process.run('chmod', ['+x', _scriptPath]);

      final result = await Process.run('bash', [_scriptPath]);

      if (result.exitCode != 0) {
        Logger.error('Bash script error: ${result.stderr}');
        return null;
      }

      return result.stdout.trim();
    } catch (e) {
      Logger.error('Error running Bash script: $e');
      return null;
    }
  }
}
