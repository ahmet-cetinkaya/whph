import 'dart:io';

/// Service for handling Windows UAC elevation and running processes with administrator privileges
abstract class IWindowsElevationService {
  /// Check if the current process is running with administrator privileges
  Future<bool> isRunningAsAdmin();

  /// Run a single PowerShell command with elevated privileges (triggers UAC prompt)
  Future<ProcessResult> runWithElevatedPrivileges(String command, List<String> arguments);

  /// Run multiple PowerShell commands with a single UAC prompt
  /// This is more efficient than multiple calls to [runWithElevatedPrivileges]
  Future<ProcessResult> runMultipleCommandsWithElevatedPrivileges(List<String> commands);
}
