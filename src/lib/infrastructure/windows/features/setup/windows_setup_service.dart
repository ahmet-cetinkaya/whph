import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/infrastructure/shared/features/setup/services/abstraction/base_setup_service.dart';

class WindowsSetupService extends BaseSetupService {
  static const _updateScriptTemplate = '''
@echo off
powershell -ExecutionPolicy Bypass -Command ^
"Write-Host 'Starting update process...'; ^
try { ^
    \$updateZip = '{appDir}\\{updateFileName}'; ^
    \$extractPath = '{appDir}'; ^
    Write-Host 'Update file path: ' \$updateZip; ^
    Write-Host 'Extract path: ' \$extractPath; ^
    if (-not (Test-Path \$updateZip)) { ^
        throw 'Update file not found: ' + \$updateZip; ^
    } ^
    Write-Host 'Creating backup of current version...'; ^
    \$backupDir = '{appDir}\\backup'; ^
    if (Test-Path \$backupDir) { ^
        Remove-Item -Recurse -Force \$backupDir; ^
    } ^
    New-Item -ItemType Directory -Path \$backupDir; ^
    Get-ChildItem -Path '{appDir}' -Exclude 'backup', '{updateFileName}', 'update.bat' | Move-Item -Destination \$backupDir; ^
    Write-Host 'Extracting update...'; ^
    Expand-Archive -Force -Path \$updateZip -DestinationPath \$extractPath; ^
    Write-Host 'Cleaning up...'; ^
    Remove-Item -Force \$updateZip; ^
    Remove-Item -Recurse -Force \$backupDir; ^
    Remove-Item -Force '{appDir}\\update.bat'; ^
    Write-Host 'Starting application...'; ^
    Start-Process -FilePath '{exePath}' -WorkingDirectory '{appDir}' -NoNewWindow; ^
    Write-Host 'Application updated and started successfully'; ^
} catch { ^
    Write-Host 'Update failed: ' \$_.Exception.Message -ForegroundColor Red; ^
    Write-Host 'Restoring backup...'; ^
    \$backupDir = '{appDir}\\backup'; ^
    if (Test-Path \$backupDir) { ^
        Get-ChildItem -Path \$backupDir | Move-Item -Destination '{appDir}'; ^
        Remove-Item -Recurse -Force \$backupDir; ^
        Write-Host 'Backup restored successfully' -ForegroundColor Yellow; ^
    } ^
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

      // Try different possible icon locations
      List<String> possibleIconPaths = [
        path.join(appDir, 'data', 'flutter_assets', 'lib', 'src', 'core', 'domain', 'shared', 'assets', 'images',
            'whph_logo_adaptive_fg.ico'),
        path.join(appDir, 'data', 'flutter_assets', 'lib', 'domain', 'shared', 'assets', 'whph_logo_adaptive_fg.ico'),
        path.join(appDir, 'data', 'flutter_assets', 'assets', 'images', 'whph_logo_adaptive_fg.ico'),
        getExecutablePath(), // Fallback to exe icon
      ];

      String iconPath = getExecutablePath(); // Default fallback
      for (final possiblePath in possibleIconPaths) {
        if (await File(possiblePath).exists()) {
          iconPath = possiblePath;
          break;
        }
      }

      Logger.debug('Using icon path: $iconPath');

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

      // Extract filename from URL (handles both portable.zip and setup.exe)
      final uri = Uri.parse(downloadUrl);
      final downloadFileName = path.basename(uri.path);
      final downloadPath = path.join(appDir, downloadFileName);

      Logger.debug('Downloading update from: $downloadUrl');
      Logger.debug('Saving to: $downloadPath');

      // Check if it's a portable version (ZIP) or installer (EXE)
      final isPortableUpdate =
          downloadFileName.toLowerCase().contains('portable') && downloadFileName.toLowerCase().endsWith('.zip');
      final isInstallerUpdate =
          downloadFileName.toLowerCase().contains('setup') && downloadFileName.toLowerCase().endsWith('.exe');

      await downloadFile(downloadUrl, downloadPath);

      if (isInstallerUpdate) {
        // For installer updates, just run the installer
        Logger.debug('Running installer update: $downloadPath');
        await runDetachedProcess(downloadPath, ['/SILENT']);
        // The installer will handle the update process
        exit(0);
      } else if (isPortableUpdate) {
        // For portable updates, use the extraction script
        Logger.debug('Preparing portable update script');
        final scriptContent = _updateScriptTemplate
            .replaceAll('{appDir}', appDir)
            .replaceAll('{exePath}', exePath)
            .replaceAll('{updateFileName}', downloadFileName);

        await writeFile(updateScript, scriptContent);
        await runDetachedProcess('cmd', ['/c', updateScript]);
        exit(0);
      } else {
        // Fallback: assume it's a zip file
        Logger.debug('Unknown update file type, treating as portable zip');
        final scriptContent = _updateScriptTemplate
            .replaceAll('{appDir}', appDir)
            .replaceAll('{exePath}', exePath)
            .replaceAll('{updateFileName}', downloadFileName);

        await writeFile(updateScript, scriptContent);
        await runDetachedProcess('cmd', ['/c', updateScript]);
        exit(0);
      }
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

  // Firewall rule management for Windows
  @override
  Future<bool> checkFirewallRule({required String ruleName}) async {
    try {
      final result = await Process.run(
        'netsh',
        ['advfirewall', 'firewall', 'show', 'rule', 'name=$ruleName'],
        runInShell: true,
      );

      // If the rule exists, netsh will return information about it
      // If it doesn't exist, it will return "No rules match the specified criteria."
      return !result.stdout.toString().contains('No rules match the specified criteria.');
    } catch (e) {
      Logger.error('Error checking firewall rule: $e');
      return false;
    }
  }

  @override
  Future<void> addFirewallRule({
    required String ruleName,
    required String appPath,
    required String port,
    String protocol = 'TCP',
    String direction = 'in',
  }) async {
    try {
      // First check if the rule already exists
      final ruleExists = await checkFirewallRule(ruleName: ruleName);
      if (ruleExists) {
        Logger.debug('Firewall rule "$ruleName" already exists');
        return;
      }

      final result = await Process.run(
        'netsh',
        [
          'advfirewall',
          'firewall',
          'add',
          'rule',
          'name=$ruleName',
          'dir=$direction',
          'action=allow',
          'program=$appPath',
          'protocol=$protocol',
          'localport=$port',
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        Logger.error('Failed to add firewall rule: ${result.stderr}');
        throw Exception('Failed to add firewall rule: ${result.stderr}');
      }

      Logger.debug('Successfully added firewall rule: $ruleName');
    } catch (e) {
      Logger.error('Error adding firewall rule: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFirewallRule({required String ruleName}) async {
    try {
      final result = await Process.run(
        'netsh',
        ['advfirewall', 'firewall', 'delete', 'rule', 'name=$ruleName'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        Logger.error('Failed to remove firewall rule: ${result.stderr}');
        throw Exception('Failed to remove firewall rule: ${result.stderr}');
      }

      Logger.debug('Successfully removed firewall rule: $ruleName');
    } catch (e) {
      Logger.error('Error removing firewall rule: $e');
      rethrow;
    }
  }
}
