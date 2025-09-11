import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/infrastructure/shared/features/setup/services/abstraction/base_setup_service.dart';

/// Custom exception for Windows firewall rule operations with detailed context
class WindowsFirewallRuleException implements Exception {
  final String message;
  final String? invalidValue;
  final int? netshExitCode;
  final String? netshStderr;
  final String? netshStdout;

  const WindowsFirewallRuleException(
    this.message, {
    this.invalidValue,
    this.netshExitCode,
    this.netshStderr,
    this.netshStdout,
  });

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (invalidValue != null) buffer.write(' [InvalidValue: $invalidValue]');
    if (netshExitCode != null) buffer.write(' [Netsh ExitCode: $netshExitCode]');
    if (netshStderr != null) buffer.write(' [Netsh Error: $netshStderr]');
    return buffer.toString();
  }
}

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

  /// Run a PowerShell command with elevated privileges (admin request)
  Future<ProcessResult> _runWithElevatedPrivileges(String command, List<String> arguments) async {
    // Create a PowerShell script that requests elevation
    final elevatedScript = '''
Start-Process -FilePath "$command" -ArgumentList "${arguments.join('", "')}" -Verb RunAs -WindowStyle Hidden -Wait
''';

    try {
      Logger.debug('Running elevated command: $command ${arguments.join(' ')}');
      return await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-Command', elevatedScript],
        runInShell: true,
      );
    } catch (e) {
      Logger.error('Failed to run elevated command: $e');
      rethrow;
    }
  }

  /// Check if the current process is running with administrator privileges
  Future<bool> _isRunningAsAdmin() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          '([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")'
        ],
        runInShell: true,
      );

      return result.stdout.toString().trim().toLowerCase() == 'true';
    } catch (e) {
      Logger.error('Failed to check admin status: $e');
      return false;
    }
  }

  // Firewall rule management for Windows
  @override
  Future<bool> checkFirewallRule({required String ruleName}) async {
    try {
      Logger.debug('Checking Windows firewall rule: $ruleName');

      final result = await Process.run(
        'netsh',
        ['advfirewall', 'firewall', 'show', 'rule', 'name=$ruleName'],
        runInShell: true,
      );

      Logger.debug('Netsh check result - exitCode: ${result.exitCode}, stdout: ${result.stdout}');

      // If the rule exists, netsh will return information about it
      // If it doesn't exist, it will return "No rules match the specified criteria."
      final ruleExists = !result.stdout.toString().contains('No rules match the specified criteria.');
      Logger.debug('Firewall rule "$ruleName" exists: $ruleExists');

      return ruleExists;
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
      Logger.debug('Attempting to add Windows firewall rule: $ruleName for port $port/$protocol');

      // Enhanced input validation
      if (port.isEmpty) {
        final error = 'WindowsFirewallRuleError: Port cannot be empty';
        Logger.error(error);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }

      final portNum = int.tryParse(port.trim());
      if (portNum == null) {
        final error = 'WindowsFirewallRuleError: Port must be a valid integer, received: "$port"';
        Logger.error(error);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }

      if (portNum <= 0 || portNum > 65535) {
        final error = 'WindowsFirewallRuleError: Port must be between 1-65535, received: $portNum';
        Logger.error(error);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }

      // Validate protocol
      final upperProtocol = protocol.trim().toUpperCase();
      if (upperProtocol != 'TCP' && upperProtocol != 'UDP') {
        final error = 'WindowsFirewallRuleError: Protocol must be TCP or UDP, received: "$protocol"';
        Logger.error(error);
        throw WindowsFirewallRuleException(error, invalidValue: protocol);
      }

      // First check if the rule already exists
      final ruleExists = await checkFirewallRule(ruleName: ruleName);
      if (ruleExists) {
        Logger.debug('Windows firewall rule "$ruleName" already exists');
        return;
      }

      // Check if running as admin
      final isAdmin = await _isRunningAsAdmin();
      Logger.debug('Running as administrator: $isAdmin');

      final netshArgs = [
        'advfirewall',
        'firewall',
        'add',
        'rule',
        'name="$ruleName"',
        'dir=$direction',
        'action=allow',
        'program="$appPath"',
        'protocol=$upperProtocol',
        'localport=$portNum',
      ];

      ProcessResult result;

      if (isAdmin) {
        // If already running as admin, execute directly
        Logger.debug('Executing netsh command directly with admin privileges');
        result = await Process.run('netsh', netshArgs, runInShell: true);
      } else {
        // Request elevation using PowerShell
        Logger.debug('Requesting elevation to run netsh command');
        result = await _runWithElevatedPrivileges('netsh', netshArgs);
      }

      Logger.debug(
          'Netsh command result - exitCode: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}');

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        final stdout = result.stdout.toString().trim();

        // Provide specific error context
        String errorContext = '';
        bool isPermissionIssue = false;

        if (stderr.toLowerCase().contains('access is denied') ||
            stderr.toLowerCase().contains('operation requires elevation') ||
            stderr.toLowerCase().contains('administrator')) {
          errorContext = ' (Administrator privileges required)';
          isPermissionIssue = true;
        } else if (stderr.toLowerCase().contains('already exists') || stderr.toLowerCase().contains('duplicate')) {
          errorContext = ' (Rule may already exist with different parameters)';
        }

        final error = isPermissionIssue
            ? 'Administrator privileges required to add Windows Firewall rule for port $portNum/$upperProtocol. Please run the application as administrator or manually add the firewall rule in Windows Defender Firewall settings.'
            : 'WindowsFirewallRuleError: Failed to add Windows Firewall rule for port $portNum/$upperProtocol$errorContext. Netsh error: $stderr';

        Logger.error(error);
        Logger.error('Netsh stdout: $stdout');

        throw WindowsFirewallRuleException(
          error,
          invalidValue: '$portNum/$upperProtocol',
          netshExitCode: result.exitCode,
          netshStderr: stderr,
          netshStdout: stdout,
        );
      }

      Logger.info('Successfully added Windows firewall rule: $ruleName for port $portNum/$upperProtocol');
    } catch (e) {
      if (e is WindowsFirewallRuleException) {
        Logger.error('Windows firewall rule creation failed: ${e.message}');
        rethrow;
      } else {
        final error = 'WindowsFirewallRuleError: Unexpected error while adding firewall rule: $e';
        Logger.error(error);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }
    }
  }

  @override
  Future<void> removeFirewallRule({required String ruleName}) async {
    try {
      final result = await Process.run(
        'netsh',
        ['advfirewall', 'firewall', 'delete', 'rule', 'name="$ruleName"'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString();
        Logger.error('Failed to remove firewall rule: $stderr');
        throw WindowsFirewallRuleException('Failed to remove firewall rule: $stderr');
      }

      Logger.debug('Successfully removed firewall rule: $ruleName');
    } catch (e) {
      Logger.error('Error removing firewall rule: $e');
      rethrow;
    }
  }
}
