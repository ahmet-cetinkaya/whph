import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:whph/infrastructure/features/setup/services/abstraction/base_setup_service.dart';

class LinuxSetupService extends BaseSetupService {
  static const _updateScriptTemplate = '''
#!/bin/bash
set -e
sleep 2
cd "{appDir}"
tar xzf whph_update.tar.gz --strip-components=1
rm whph_update.tar.gz
rm update.sh
chmod +x "{exePath}"
"{exePath}" &
exit 0
''';

  @override
  Future<void> setupEnvironment() async {
    if (!Platform.isLinux) return;

    final homeDir = Platform.environment['HOME'];
    final localShare = path.join(homeDir!, '.local', 'share');

    try {
      final directories = [
        path.join(localShare, 'applications'),
        path.join(localShare, 'icons', 'hicolor', '512x512', 'apps'),
      ];

      await createDirectories(directories);

      final appDir = getApplicationDirectory();
      final iconLocations = [
        path.join(localShare, 'icons', 'hicolor', '512x512', 'apps', 'whph.png'),
        path.join(localShare, 'icons', 'whph.png'),
      ];

      final sourceIcon = path.join(appDir, 'share', 'icons', 'whph.png');
      for (final iconPath in iconLocations) {
        await copyFile(sourceIcon, iconPath);
      }

      final desktopFile = path.join(localShare, 'applications', 'whph.desktop');
      await copyFile(path.join(appDir, 'share', 'applications', 'whph.desktop'), desktopFile);
      await _updateDesktopFile(desktopFile, iconLocations.first);
      await _updateIconCache(localShare);

      await _installSystemIcon(sourceIcon);
    } catch (e) {
      if (kDebugMode) print('ERROR: Error setting up Linux environment: $e');
    }
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      final appDir = getApplicationDirectory();
      final updateScript = path.join(appDir, 'update.sh');
      final downloadPath = path.join(appDir, 'whph_update.tar.gz');

      await downloadFile(downloadUrl, downloadPath);
      await writeFile(updateScript, _getUpdateScript(appDir));
      await makeFileExecutable(updateScript);
      await runDetachedProcess('bash', [updateScript]);
      exit(0);
    } catch (e) {
      if (kDebugMode) print('ERROR: Failed to download and install update: $e');
      rethrow;
    }
  }

  String _getUpdateScript(String appDir) =>
      _updateScriptTemplate.replaceAll('{appDir}', appDir).replaceAll('{exePath}', getExecutablePath());

  Future<void> _updateDesktopFile(String filePath, String iconPath) async {
    if (await File(filePath).exists()) {
      var content = await File(filePath).readAsString();
      content = content.replaceAll('Icon=whph', 'Icon=$iconPath');
      await File(filePath).writeAsString(content);
    }
  }

  Future<void> _updateIconCache(String sharePath) async {
    try {
      await Process.run('gtk-update-icon-cache', ['-f', '-t', path.join(sharePath, 'icons', 'hicolor')]);
      await Process.run('update-desktop-database', [path.join(sharePath, 'applications')]);
    } catch (e) {
      if (kDebugMode) print('ERROR: Error updating icon cache: $e');
    }
  }

  Future<void> _installSystemIcon(String sourceIcon) async {
    try {
      final systemIconDir = '/usr/share/icons/hicolor/512x512/apps';
      if (await Directory(systemIconDir).exists()) {
        final result = await Process.run('sudo', ['cp', sourceIcon, path.join(systemIconDir, 'whph.png')]);
        if (result.exitCode == 0) {
          await Process.run('sudo', ['gtk-update-icon-cache', '-f', '-t', '/usr/share/icons/hicolor']);
        }
      }
    } catch (e) {
      if (kDebugMode) print('ERROR: Could not install system-wide icon: $e');
    }
  }
}
