import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:domain/shared/utils/logger.dart';
import 'package:infrastructure_shared/features/setup/services/abstraction/base_setup_service.dart';
import 'package:infrastructure_windows/features/setup/constants/windows_script_templates.dart';
import 'package:infrastructure_windows/features/setup/services/abstraction/i_windows_update_service.dart';

/// Implementation of Windows update service
class WindowsUpdateService extends BaseSetupService implements IWindowsUpdateService {
  static const String _componentName = 'WindowsUpdateService';

  @override
  Future<void> setupEnvironment() async {
    // Update service doesn't handle environment setup
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

      DomainLogger.debug('Downloading update from: $downloadUrl', component: _componentName);
      DomainLogger.debug('Saving to: $downloadPath', component: _componentName);

      // Check if it's a portable version (ZIP) or installer (EXE)
      final isPortableUpdate =
          downloadFileName.toLowerCase().contains('portable') && downloadFileName.toLowerCase().endsWith('.zip');
      final isInstallerUpdate =
          downloadFileName.toLowerCase().contains('setup') && downloadFileName.toLowerCase().endsWith('.exe');

      await downloadFile(downloadUrl, downloadPath);

      if (isInstallerUpdate) {
        // For installer updates, just run the installer
        DomainLogger.debug('Running installer update: $downloadPath', component: _componentName);
        await runDetachedProcess(downloadPath, ['/SILENT']);
        // The installer will handle the update process
        exit(0);
      } else if (isPortableUpdate) {
        // For portable updates, use the extraction script
        DomainLogger.debug('Preparing portable update script', component: _componentName);
        final scriptContent = WindowsScriptTemplates.updateScript
            .replaceAll('{appDir}', appDir)
            .replaceAll('{exePath}', exePath)
            .replaceAll('{updateFileName}', downloadFileName);

        await writeFile(updateScript, scriptContent);
        await runDetachedProcess('cmd', ['/c', updateScript]);
        exit(0);
      } else {
        // Fallback: assume it's a zip file
        DomainLogger.debug('Unknown update file type, treating as portable zip', component: _componentName);
        final scriptContent = WindowsScriptTemplates.updateScript
            .replaceAll('{appDir}', appDir)
            .replaceAll('{exePath}', exePath)
            .replaceAll('{updateFileName}', downloadFileName);

        await writeFile(updateScript, scriptContent);
        await runDetachedProcess('cmd', ['/c', updateScript]);
        exit(0);
      }
    } catch (e) {
      DomainLogger.error('Failed to download and install update: $e', component: _componentName);
      rethrow;
    }
  }
}
