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

  /// Add both inbound and outbound firewall rules in a single elevated operation
  @override
  Future<void> addFirewallRules({
    required String ruleNamePrefix,
    required String appPath,
    required String port,
    String protocol = 'TCP',
  }) async {
    try {
      Logger.info('🔧 [FIREWALL] Starting batch Windows firewall rule addition for port $port/$protocol');
      Logger.debug('🔧 [FIREWALL] Rule prefix: $ruleNamePrefix');
      Logger.debug('🔧 [FIREWALL] App path: $appPath');

      // Check if rules already exist
      final inboundRuleName = '$ruleNamePrefix (Inbound)';
      final outboundRuleName = '$ruleNamePrefix (Outbound)';

      Logger.debug('🔍 [FIREWALL] Checking if inbound rule exists: $inboundRuleName');
      final inboundExists = await checkFirewallRule(ruleName: inboundRuleName);
      Logger.info('🔍 [FIREWALL] Inbound rule exists: $inboundExists');

      Logger.debug('🔍 [FIREWALL] Checking if outbound rule exists: $outboundRuleName');
      final outboundExists = await checkFirewallRule(ruleName: outboundRuleName);
      Logger.info('🔍 [FIREWALL] Outbound rule exists: $outboundExists');

      if (inboundExists && outboundExists) {
        Logger.info('✅ [FIREWALL] Both inbound and outbound firewall rules already exist - skipping addition');
        return;
      }

      // Check if running as admin
      Logger.debug('🔐 [FIREWALL] Checking if running as administrator...');
      final isAdmin = await _isRunningAsAdmin();
      Logger.info('🔐 [FIREWALL] Running as administrator: $isAdmin');

      // Build netsh commands for both rules
      final commands = <String>[];

      if (!inboundExists) {
        final inboundCmd =
            'netsh advfirewall firewall add rule name="$inboundRuleName" dir=in action=allow program="$appPath" protocol=$protocol localport=$port';
        commands.add(inboundCmd);
        Logger.debug('🔧 [FIREWALL] Will add inbound rule: $inboundRuleName');
      }

      if (!outboundExists) {
        final outboundCmd =
            'netsh advfirewall firewall add rule name="$outboundRuleName" dir=out action=allow program="$appPath" protocol=$protocol localport=$port';
        commands.add(outboundCmd);
        Logger.debug('🔧 [FIREWALL] Will add outbound rule: $outboundRuleName');
      }

      if (commands.isEmpty) {
        Logger.info('✅ [FIREWALL] No new firewall rules needed');
        return;
      }

      Logger.info('🔧 [FIREWALL] Total rules to add: ${commands.length}');
      commands.asMap().forEach((index, cmd) {
        Logger.debug('🔧 [FIREWALL] Command ${index + 1}: $cmd');
      });

      ProcessResult result;

      if (isAdmin) {
        // If already running as admin, execute commands directly
        Logger.info(
            '🔧 [FIREWALL] Executing netsh commands directly with admin privileges (${commands.length} commands)');
        for (final command in commands) {
          // Using `/c` with `cmd.exe` allows the shell to handle parsing the command string correctly.
          Logger.debug('🔧 [FIREWALL] Executing command with cmd /c');
          final cmdResult = await Process.run('cmd', ['/c', command], runInShell: true);
          Logger.debug('🔧 [FIREWALL] Command result exitCode: ${cmdResult.exitCode}');
          if (cmdResult.exitCode != 0) {
            Logger.error('❌ [FIREWALL] Command failed - stderr: ${cmdResult.stderr}');
            throw Exception('Failed to execute: $command, stderr: ${cmdResult.stderr}');
          }
          Logger.info('✅ [FIREWALL] Command executed successfully');
        }
        result = ProcessResult(0, 0, '', ''); // Success
      } else {
        // Request elevation using a single PowerShell session for all commands to avoid multiple UAC prompts
        Logger.info('🔧 [FIREWALL] Requesting single elevation to run ${commands.length} netsh commands');
        result = await _runMultipleCommandsWithElevatedPrivileges(commands);
      }

      Logger.debug('🔧 [FIREWALL] Batch netsh commands result - exitCode: ${result.exitCode}');
      Logger.debug('🔧 [FIREWALL] Netsh stdout: "${result.stdout}"');
      Logger.debug('🔧 [FIREWALL] Netsh stderr: "${result.stderr}"');

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        final stdout = result.stdout.toString().trim();

        final error =
            'WindowsFirewallRuleError: Failed to add Windows Firewall rules for port $port/$protocol. Netsh error: $stderr';

        Logger.error('❌ [FIREWALL] $error');
        Logger.error('❌ [FIREWALL] Netsh stdout: $stdout');

        throw WindowsFirewallRuleException(
          error,
          invalidValue: '$port/$protocol',
          netshExitCode: result.exitCode,
          netshStderr: stderr,
          netshStdout: stdout,
        );
      }

      Logger.info(
          '✅ [FIREWALL] Successfully added Windows firewall rules for port $port/$protocol (${commands.length} rules added)');
    } catch (e) {
      if (e is WindowsFirewallRuleException) {
        Logger.error('❌ [FIREWALL] Windows firewall rules creation failed: ${e.message}');
        rethrow;
      } else {
        final error = 'WindowsFirewallRuleError: Unexpected error while adding firewall rules: $e';
        Logger.error('❌ [FIREWALL] $error');
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }
    }
  }

  /// Run multiple PowerShell commands with elevated privileges (single UAC prompt)
  /// This method batches multiple netsh commands into a single elevated PowerShell session
  /// to avoid multiple UAC prompts when adding multiple firewall rules.
  Future<ProcessResult> _runMultipleCommandsWithElevatedPrivileges(List<String> commands) async {
    // Create a PowerShell script that requests elevation and runs multiple commands
    // Use a temporary batch file to execute the commands and capture output
    final tempBatchFile =
        File('${Directory.systemTemp.path}\\whph_firewall_${DateTime.now().millisecondsSinceEpoch}.bat');

    // Define tempPsFile outside try block to ensure it's accessible in catch for cleanup
    File? tempPsFile;

    // Build the batch content with multiple netsh commands
    final batchCommands = commands.join(' && ');
    final batchContent = '''
@echo off
$batchCommands
set exitCode=%ERRORLEVEL%
echo ExitCode:%exitCode% > "${tempBatchFile.path}.result"
if %exitCode% neq 0 (
  echo %ERROR% > "${tempBatchFile.path}.error"
)
exit /b %exitCode%
''';

    try {
      // Write the batch file
      await tempBatchFile.writeAsString(batchContent);

      // Write the PowerShell script to a temporary file to avoid parsing issues
      tempPsFile =
          File('${Directory.systemTemp.path}\\whph_elevate_${DateTime.now().millisecondsSinceEpoch}.ps1');
      final psScriptContent = '''
try {
  Start-Process -FilePath "cmd" -ArgumentList @("/c", "${tempBatchFile.path}") -Verb RunAs -Wait -WindowStyle Hidden
  # Wait briefly to ensure process completion
  Start-Sleep -Milliseconds 500
  Write-Output "Error: \$_.Exception.Message"
 exit 1
}
''';

      await tempPsFile.writeAsString(psScriptContent);

      Logger.debug('Running elevated commands: $batchCommands');
      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-File', tempPsFile.path],
        runInShell: true,
      );

      // Clean up the temporary PowerShell script file
      if (await tempPsFile.exists()) {
        await tempPsFile.delete();
      }

      // Wait for the result file to be written with a timeout of 10 seconds
      // This is more reliable than a fixed delay
      final resultFile = File('${tempBatchFile.path}.result');
      int maxAttempts = 100; // 100 attempts * 100ms = 10 seconds
      int attempts = 0;
      while (!await resultFile.exists() && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // Read the result and error files if they exist
      String stdout = result.stdout.toString();
      String stderr = result.stderr.toString();
      int exitCode = result.exitCode;

      if (await resultFile.exists()) {
        final resultContent = await resultFile.readAsString();
        // Extract exit code from the result file
        final exitCodeMatch = RegExp(r'ExitCode:(\\d+)').firstMatch(resultContent);
        if (exitCodeMatch != null) {
          exitCode = int.parse(exitCodeMatch.group(1)!);
        }
        stdout += resultContent;
      }

      final errorFile = File('${tempBatchFile.path}.error');
      if (await errorFile.exists()) {
        stderr = await errorFile.readAsString();
      }

      // Clean up temporary files
      if (await tempBatchFile.exists()) {
        await tempBatchFile.delete();
      }
      if (await resultFile.exists()) {
        await resultFile.delete();
      }
      if (await errorFile.exists()) {
        await errorFile.delete();
      }

      return ProcessResult(0, exitCode, stdout, stderr);
    } catch (e) {
      Logger.error('Failed to run elevated commands: $e');

      // Clean up temporary files in case of error
      if (await tempBatchFile.exists()) {
        await tempBatchFile.delete();
      }
      final resultFile = File('${tempBatchFile.path}.result');
      if (await resultFile.exists()) {
        await resultFile.delete();
      }
      final errorFile = File('${tempBatchFile.path}.error');
      if (await errorFile.exists()) {
        await errorFile.delete();
      }
      final tempPsFileToCleanup =
          File('${Directory.systemTemp.path}\\whph_elevate_${DateTime.now().millisecondsSinceEpoch}.ps1');
      if (await tempPsFileToCleanup.exists()) {
        await tempPsFileToCleanup.delete();
      }

      rethrow;
    }
  }

  /// Run a PowerShell command with elevated privileges (admin request) - for single commands
  Future<ProcessResult> _runWithElevatedPrivileges(String command, List<String> arguments) async {
    // Create a PowerShell script that requests elevation
    // Use a temporary batch file to execute the command and capture output
    final tempBatchFile =
        File('${Directory.systemTemp.path}\\whph_firewall_${DateTime.now().millisecondsSinceEpoch}.bat');

    // Define tempPsFile outside try block to ensure it's accessible in catch for cleanup
    File? tempPsFile;

    // Build the netsh command
    final netshCommand = '$command ${arguments.join(' ')}';

    final batchContent = '''
@echo off
$netshCommand
set exitCode=%ERRORLEVEL%
echo ExitCode:%exitCode% > "${tempBatchFile.path}.result"
if %exitCode% neq 0 (
  echo %ERROR% > "${tempBatchFile.path}.error"
)
exit /b %exitCode%
''';

    try {
      // Write the batch file
      await tempBatchFile.writeAsString(batchContent);

      // Write the PowerShell script to a temporary file to avoid parsing issues
      tempPsFile =
          File('${Directory.systemTemp.path}\\whph_elevate_${DateTime.now().millisecondsSinceEpoch}.ps1');
      final psScriptContent = '''
try {
  Start-Process -FilePath "cmd" -ArgumentList @("/c", "${tempBatchFile.path}") -Verb RunAs -Wait -WindowStyle Hidden
  Start-Sleep -Milliseconds 500
} catch {
  Write-Output "Error: \$_.Exception.Message"
 exit 1
}
''';

      await tempPsFile.writeAsString(psScriptContent);

      Logger.debug('Running elevated command: $netshCommand');
      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-File', tempPsFile.path],
        runInShell: true,
      );

      // Clean up the temporary PowerShell script file
      if (await tempPsFile.exists()) {
        await tempPsFile.delete();
      }

      // Wait for the result file to be written with a timeout of 10 seconds
      // This is more reliable than a fixed delay
      final resultFile = File('${tempBatchFile.path}.result');
      int maxAttempts = 100; // 100 attempts * 100ms = 10 seconds
      int attempts = 0;
      while (!await resultFile.exists() && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // Read the result and error files if they exist
      String stdout = result.stdout.toString();
      String stderr = result.stderr.toString();
      int exitCode = result.exitCode;

      if (await resultFile.exists()) {
        final resultContent = await resultFile.readAsString();
        // Extract exit code from the result file
        final exitCodeMatch = RegExp(r'ExitCode:(\\d+)').firstMatch(resultContent);
        if (exitCodeMatch != null) {
          exitCode = int.parse(exitCodeMatch.group(1)!);
        }
        stdout += resultContent;
      }

      final errorFile = File('${tempBatchFile.path}.error');
      if (await errorFile.exists()) {
        stderr = await errorFile.readAsString();
      }

      // Clean up temporary files
      if (await tempBatchFile.exists()) {
        await tempBatchFile.delete();
      }
      if (await resultFile.exists()) {
        await resultFile.delete();
      }
      if (await errorFile.exists()) {
        await errorFile.delete();
      }

      return ProcessResult(0, exitCode, stdout, stderr);
    } catch (e) {
      Logger.error('Failed to run elevated command: $e');

      // Clean up temporary files in case of error
      if (await tempBatchFile.exists()) {
        await tempBatchFile.delete();
      }
      final resultFile = File('${tempBatchFile.path}.result');
      if (await resultFile.exists()) {
        await resultFile.delete();
      }
      final errorFile = File('${tempBatchFile.path}.error');
      if (await errorFile.exists()) {
        await errorFile.delete();
      }
      final tempPsFileToCleanup =
          File('${Directory.systemTemp.path}\\whph_elevate_${DateTime.now().millisecondsSinceEpoch}.ps1');
      if (await tempPsFileToCleanup.exists()) {
        await tempPsFileToCleanup.delete();
      }

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
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'}) async {
    try {
      Logger.debug('🔍 [FIREWALL] Checking Windows firewall rule: $ruleName (protocol: $protocol)');

      // First, try using netsh as primary method (more reliable for exact name matching)
      Logger.debug('🔍 [FIREWALL] Attempting netsh check for rule: $ruleName');
      final result = await Process.run(
        'netsh',
        ['advfirewall', 'firewall', 'show', 'rule', 'name=$ruleName'],
        runInShell: true,
      );

      Logger.debug('🔍 [FIREWALL] Netsh result - exitCode: ${result.exitCode}');
      Logger.debug('🔍 [FIREWALL] Netsh stdout: "${result.stdout}"');
      Logger.debug('🔍 [FIREWALL] Netsh stderr: "${result.stderr}"');

      final output = result.stdout.toString();
      final errorOutput = result.stderr.toString().trim();
      final exitCode = result.exitCode;

      // For netsh, if the rule exists, the output should contain the rule name and exit code is 0
      // If it doesn't exist, it shows an error or no output
      final ruleExists = output.contains(ruleName) && exitCode == 0;

      Logger.info(
          '✅ [FIREWALL] Firewall rule "$ruleName" exists: $ruleExists (exitCode: $exitCode, contains ruleName: ${output.contains(ruleName)})');

      if (ruleExists) {
        return true;
      }

      // If netsh didn't find it, try PowerShell as fallback
      Logger.debug('🔍 [FIREWALL] Netsh did not find rule, attempting PowerShell fallback');
      try {
        final psCommand =
            'try { \$rule = Get-NetFirewallRule -Name "$ruleName" -ErrorAction Stop; Write-Output \$rule.Name } catch { Write-Output "" }';

        Logger.debug('🔍 [FIREWALL] Executing PowerShell: Get-NetFirewallRule -Name "$ruleName"');
        final psResult = await Process.run(
          'powershell',
          ['-Command', psCommand],
          runInShell: true,
        );

        Logger.debug('🔍 [FIREWALL] PowerShell result - exitCode: ${psResult.exitCode}');
        Logger.debug('🔍 [FIREWALL] PowerShell stdout: "${psResult.stdout}"');
        Logger.debug('🔍 [FIREWALL] PowerShell stderr: "${psResult.stderr}"');

        final psOutput = psResult.stdout.toString().trim();
        final psRuleExists = psOutput == ruleName;

        Logger.info(
            '✅ [FIREWALL] Firewall rule "$ruleName" exists (PowerShell fallback): $psRuleExists (output: "$psOutput")');

        return psRuleExists;
      } catch (psError) {
        Logger.warning('⚠️ [FIREWALL] PowerShell fallback also failed: $psError');
        return false;
      }
    } catch (e) {
      Logger.error('❌ [FIREWALL] Failed to check firewall rule: $e');
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
      final ruleExists = await checkFirewallRule(ruleName: ruleName);
      if (!ruleExists) {
        Logger.debug('Firewall rule "$ruleName" does not exist, skipping removal.');
        return;
      }

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
