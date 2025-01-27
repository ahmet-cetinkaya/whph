import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'abstraction/base_setup_service.dart';

class WindowsSetupService extends BaseSetupService {
  static const _updateScriptContent = '''
@echo off
timeout /t 2 /nobreak > nul
cd /d "%~dp0"
powershell -command "Expand-Archive -Force whph_update.zip ."
del whph_update.zip
del update.bat
start "" "%~dp0whph.exe"
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
      final startMenuPath =
          path.join(Platform.environment['APPDATA']!, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'WHPH');

      await createDirectories([startMenuPath]);

      final shortcutPath = path.join(startMenuPath, 'WHPH.lnk');
      final iconPath =
          path.join(appDir, 'data', 'flutter_assets', 'lib', 'domain', 'shared', 'assets', 'whph_logo_adaptive_fg.ico');

      await _createShortcut(
        target: getExecutablePath(),
        shortcutPath: shortcutPath,
        iconPath: iconPath,
        description: 'Work Hard Play Hard - Time Tracking App',
      );
    } catch (e) {
      if (kDebugMode) print('ERROR: Error setting up Windows environment: $e');
    }
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      final appDir = getApplicationDirectory();
      final updateScript = path.join(appDir, 'update.bat');
      final downloadPath = path.join(appDir, 'whph_update.zip');

      await downloadFile(downloadUrl, downloadPath);
      await writeFile(updateScript, _updateScriptContent);
      await runDetachedProcess('cmd', ['/c', updateScript]);
      exit(0);
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to download and install update: $e');
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
      if (kDebugMode) print('ERROR: Failed to create shortcut: $e');
      rethrow;
    }
  }
}
