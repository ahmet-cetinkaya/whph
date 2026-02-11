import 'dart:io';

import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_elevation_service.dart';

/// Implementation of Windows UAC elevation service
///
/// Handles elevation through PowerShell's Start-Process with -Verb RunAs
/// Uses temporary batch/PowerShell scripts to capture output from elevated processes
class WindowsElevationService implements IWindowsElevationService {
  static const String _componentName = 'WindowsElevationService';

  @override
  Future<bool> isRunningAsAdmin() async {
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
      DomainLogger.error('Failed to check admin status: $e', component: _componentName);
      return false;
    }
  }

  @override
  Future<ProcessResult> runWithElevatedPrivileges(String command, List<String> arguments) async {
    final tempBatchFile =
        File('${Directory.systemTemp.path}\\whph_firewall_${DateTime.now().millisecondsSinceEpoch}.bat');

    File? tempPsFile;

    // Build the command
    final fullCommand = '$command ${arguments.join(' ')}';

    final batchContent = '''
@echo off
$fullCommand
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
      tempPsFile = File('${Directory.systemTemp.path}\\whph_elevate_${DateTime.now().millisecondsSinceEpoch}.ps1');
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

      DomainLogger.debug('Running elevated command: $fullCommand', component: _componentName);
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
      final resultFile = File('${tempBatchFile.path}.result');
      int maxAttempts = 100; // 100 attempts * 100ms = 10 seconds
      int attempts = 0;
      while (!await resultFile.exists() && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      //Read the result and error files if they exist
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
      await _cleanupTempFiles(tempBatchFile, resultFile, errorFile);

      return ProcessResult(0, exitCode, stdout, stderr);
    } catch (e) {
      DomainLogger.error('Failed to run elevated command: $e', component: _componentName);

      // Clean up temporary files in case of error
      final resultFile = File('${tempBatchFile.path}.result');
      final errorFile = File('${tempBatchFile.path}.error');
      await _cleanupTempFiles(tempBatchFile, resultFile, errorFile, tempPsFile);

      rethrow;
    }
  }

  @override
  Future<ProcessResult> runMultipleCommandsWithElevatedPrivileges(List<String> commands) async {
    final tempBatchFile =
        File('${Directory.systemTemp.path}\\whph_firewall_${DateTime.now().millisecondsSinceEpoch}.bat');

    File? tempPsFile;

    // Build the batch content with multiple commands
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
      tempPsFile = File('${Directory.systemTemp.path}\\whph_elevate_${DateTime.now().millisecondsSinceEpoch}.ps1');
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

      DomainLogger.debug('Running elevated commands: $batchCommands', component: _componentName);
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
      await _cleanupTempFiles(tempBatchFile, resultFile, errorFile);

      return ProcessResult(0, exitCode, stdout, stderr);
    } catch (e) {
      DomainLogger.error('Failed to run elevated commands: $e', component: _componentName);

      // Clean up temporary files in case of error
      final resultFile = File('${tempBatchFile.path}.result');
      final errorFile = File('${tempBatchFile.path}.error');
      await _cleanupTempFiles(tempBatchFile, resultFile, errorFile, tempPsFile);

      rethrow;
    }
  }

  /// Helper method to clean up temporary files
  Future<void> _cleanupTempFiles(
    File batchFile,
    File resultFile,
    File errorFile, [
    File? psFile,
  ]) async {
    if (await batchFile.exists()) {
      await batchFile.delete();
    }
    if (await resultFile.exists()) {
      await resultFile.delete();
    }
    if (await errorFile.exists()) {
      await errorFile.delete();
    }
    if (psFile != null && await psFile.exists()) {
      await psFile.delete();
    }
  }
}
