import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/shared/features/setup/services/abstraction/base_setup_service.dart';
import 'abstraction/i_linux_update_service.dart';

/// Implementation of Linux application update operations.
class LinuxUpdateService extends BaseSetupService implements ILinuxUpdateService {
  static const String _componentName = 'LinuxUpdateService';

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
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      final appDir = getApplicationDirectory();
      final updateScript = path.join(appDir, 'update.sh');
      final downloadPath = path.join(appDir, 'whph_update.tar.gz');
      final exePath = getExecutablePath();

      await downloadFile(downloadUrl, downloadPath);
      await writeFile(updateScript, _getUpdateScript(appDir, exePath));
      await makeFileExecutable(updateScript);
      await runDetachedProcess('bash', [updateScript]);
      exit(0);
    } catch (e) {
      DomainLogger.error('Failed to download and install update: $e', component: _componentName);
      rethrow;
    }
  }

  @override
  Future<String> getAppVersion() async {
    try {
      // Try reading from pubspec.yaml first
      try {
        final pubspecFile = File('pubspec.yaml');
        if (await pubspecFile.exists()) {
          final content = await pubspecFile.readAsString();
          final versionMatch = RegExp(r'version:\s*([0-9]+\.[0-9]+\.[0-9]+)').firstMatch(content);
          if (versionMatch != null) {
            return versionMatch.group(1) ?? '0.18.0';
          }
        }
      } catch (e) {
        DomainLogger.debug('Failed to get version from package_info: $e', component: _componentName);
      }

      // Fallback to reading pubspec.yaml from app directory
      final appDir = path.dirname(Platform.resolvedExecutable);
      final pubspecPath = path.join(appDir, 'data', 'flutter_assets', 'pubspec.yaml');

      final pubspecFile = File(pubspecPath);
      if (await pubspecFile.exists()) {
        final content = await pubspecFile.readAsString();
        final versionMatch = RegExp(r'version:\s*([0-9]+\.[0-9]+\.[0-9]+)').firstMatch(content);
        if (versionMatch != null) {
          return versionMatch.group(1) ?? '0.18.0';
        }
      }

      DomainLogger.warning('Could not determine app version, using default', component: _componentName);
      return '0.18.0';
    } catch (e) {
      DomainLogger.debug('Error getting app version: $e', component: _componentName);
      return '0.18.0';
    }
  }

  String _getUpdateScript(String appDir, String exePath) =>
      _updateScriptTemplate.replaceAll('{appDir}', appDir).replaceAll('{exePath}', exePath);

  // BaseSetupService abstract methods - not used by this service but required
  @override
  Future<void> setupEnvironment() async {}

  @override
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'}) async => false;

  @override
  Future<void> addFirewallRule({
    required String ruleName,
    required String appPath,
    required String port,
    String protocol = 'TCP',
    String direction = 'in',
  }) async {}

  @override
  Future<void> removeFirewallRule({required String ruleName}) async {}
}
