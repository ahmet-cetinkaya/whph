/// Windows PowerShell and batch script templates for system operations
class WindowsScriptTemplates {
  /// Batch script template for applying Windows updates
  ///
  /// Handles:
  /// - Creating backups of current version
  /// - Extracting update ZIP file
  /// - Restoring from backup on failure
  /// - Launching updated application
  ///
  /// Template variables:
  /// - {appDir}: Application directory path
  /// - {exePath}: Executable file path
  /// - {updateFileName}: Update ZIP filename
  static const String updateScript = '''
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

  /// PowerShell script template for creating Windows shortcuts (.lnk files)
  ///
  /// Template variables:
  /// - {shortcutPath}: Full path where shortcut should be created
  /// - {target}: Target executable path
  /// - {iconPath}: Icon file path
  /// - {description}: Optional description (can be empty)
  static const String shortcutScript = '''
\$WshShell = New-Object -comObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut("{shortcutPath}")
\$Shortcut.TargetPath = "{target}"
\$Shortcut.IconLocation = "{iconPath}"
{description}
\$Shortcut.Save()
''';
}
