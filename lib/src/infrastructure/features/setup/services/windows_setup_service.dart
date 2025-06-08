import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:whph/src/core/domain/shared/constants/app_info.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'abstraction/base_setup_service.dart';

class WindowsSetupService extends BaseSetupService {
  static const _updateScriptTemplate = '''
@echo off
powershell -ExecutionPolicy Bypass -Command ^
"Write-Host 'Starting update process...'; ^
try { ^
    \$updateZip = '{appDir}\\{updateFileName}.zip'; ^
    \$extractPath = '{appDir}'; ^
    Write-Host 'Update file path: ' \$updateZip; ^
    Write-Host 'Extract path: ' \$extractPath; ^
    if (-not (Test-Path \$updateZip)) { ^
        throw 'Update file not found: ' + \$updateZip; ^
    } ^
    Write-Host 'Extracting update...'; ^
    Expand-Archive -Force -Path \$updateZip -DestinationPath \$extractPath; ^
    Remove-Item -Force \$updateZip; ^
    Remove-Item -Force '{appDir}\\update.bat'; ^
    Write-Host 'Starting application...'; ^
    Start-Process -FilePath '{exePath}' -WorkingDirectory '{appDir}' -NoNewWindow; ^
    Write-Host 'Application started successfully'; ^
} catch { ^
    Write-Host ' ' \$_.Exception.Message -ForegroundColor Red; ^
    Write-Host 'Stack: ' \$_.ScriptStackTrace -ForegroundColor Red; ^
    pause; ^
    exit 1; ^
}"
exit
''';

  static const _shortcutScriptTemplate = '''
\$WshShell = New-Object -comObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut("{shortcutPath}")
\$Shortcut.TargetPath = "{target}"
\$Shortcut.IconLocation = "{iconPath}"
{description}
\$Shortcut.Save()
''';

  @override
  Future<void> setupEnvironment() async {
    if (!Platform.isWindows) return;

    try {
      final appDir = getApplicationDirectory();
      final startMenuPath = path.join(
          Platform.environment['APPDATA']!, 'Microsoft', 'Windows', 'Start Menu', 'Programs', AppInfo.shortName);

      await createDirectories([startMenuPath]);

      final shortcutPath = path.join(startMenuPath, '${AppInfo.shortName}.lnk');
      final iconPath =
          path.join(appDir, 'data', 'flutter_assets', 'lib', 'domain', 'shared', 'assets', 'whph_logo_adaptive_fg.ico');

      await _createShortcut(
        target: getExecutablePath(),
        shortcutPath: shortcutPath,
        iconPath: iconPath,
        description: '${AppInfo.name} - Time Tracking App',
      );
    } catch (e) {
      Logger.error('Error setting up Windows environment: $e');
    }
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      final appDir = getApplicationDirectory();
      final exePath = getExecutablePath();
      final updateScript = path.join(appDir, 'update.bat');
      final updateFileName = '${AppInfo.shortName.toLowerCase()}_update';
      final downloadPath = path.join(appDir, '$updateFileName.zip');

      await downloadFile(downloadUrl, downloadPath);
      final scriptContent = _updateScriptTemplate
          .replaceAll('{appDir}', appDir)
          .replaceAll('{exePath}', exePath)
          .replaceAll('{updateFileName}', updateFileName);
      await writeFile(updateScript, scriptContent);
      await runDetachedProcess('cmd', ['/c', updateScript]);
      exit(0);
    } catch (e) {
      Logger.error('Failed to download and install update: $e');
      rethrow;
    }
  }

  Future<void> _createShortcut({
    required String target,
    required String shortcutPath,
    required String iconPath,
    String? description,
  }) async {
    try {
      final psScript = _shortcutScriptTemplate
          .replaceAll('{shortcutPath}', shortcutPath)
          .replaceAll('{target}', target)
          .replaceAll('{iconPath}', iconPath)
          .replaceAll(
            '{description}',
            description != null ? '\$Shortcut.Description = "$description"' : '',
          );

      final result = await Process.run('powershell', ['-Command', psScript]);

      if (result.exitCode != 0) {
        throw Exception('Failed to create shortcut: ${result.stderr}');
      }
    } catch (e) {
      Logger.error('Failed to create shortcut: $e');
      rethrow;
    }
  }
}
