import 'dart:io';
import 'base_desktop_app_usage_service.dart';
import 'package:whph/src/core/shared/utils/logger.dart';

class WindowsAppUsageService extends BaseDesktopAppUsageService {
  WindowsAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.settingRepository,
  );

  @override
  Future<String?> getActiveWindow() async {
    try {
      // Inline PowerShell script for getting active window on Windows
      const powershellScript = r'''
# Add a class to access Windows API functions
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WindowHelper
{
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
}
"@

# Get the handle of the active window
$foregroundWindow = [WindowHelper]::GetForegroundWindow()

# Create a StringBuilder to hold the window title
$titleBuilder = New-Object System.Text.StringBuilder 256
[WindowHelper]::GetWindowText($foregroundWindow, $titleBuilder, $titleBuilder.Capacity) | Out-Null
$title = $titleBuilder.ToString()

# Get the process ID of the active window
$processId = 0
[WindowHelper]::GetWindowThreadProcessId($foregroundWindow, [ref] $processId)

# Get the process associated with the active window
$process = Get-Process -Id $processId -ErrorAction SilentlyContinue
$processName = if ($process) { $process.Name } else { "" }

# Output the results
Write-Output "$title,$processName"
''';

      final result = await Process.run('powershell', [
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        powershellScript,
      ]);

      if (result.exitCode != 0) {
        Logger.error('PowerShell error: ${result.stderr}');
        return null;
      }

      return result.stdout.trim();
    } catch (e) {
      Logger.error('Error running PowerShell script: $e');
      return null;
    }
  }
}
