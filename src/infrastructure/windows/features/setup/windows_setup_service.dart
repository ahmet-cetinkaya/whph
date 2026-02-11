import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/shared/features/setup/services/abstraction/base_setup_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_firewall_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_shortcut_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_update_service.dart';

/// Windows-specific setup service
///
/// Coordinates Windows platform setup through specialized services:
/// - Firewall rule management
/// - Start Menu shortcut creation
/// - Application updates
class WindowsSetupService extends BaseSetupService {
  final IWindowsFirewallService _firewallService;
  final IWindowsShortcutService _shortcutService;
  final IWindowsUpdateService _updateService;

  static const String _componentName = 'WindowsSetupService';

  WindowsSetupService({
    required IWindowsFirewallService firewallService,
    required IWindowsShortcutService shortcutService,
    required IWindowsUpdateService updateService,
  })  : _firewallService = firewallService,
        _shortcutService = shortcutService,
        _updateService = updateService;

  @override
  Future<void> setupEnvironment() async {
    if (!Platform.isWindows) return;

    try {
      final appDir = getApplicationDirectory();

      // Try different possible icon locations
      final possibleIconPaths = [
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

      DomainLogger.debug('Using icon path: $iconPath', component: _componentName);

      await _shortcutService.createStartMenuShortcut(
        appName: AppInfo.shortName,
        target: getExecutablePath(),
        iconPath: iconPath,
        description: '${AppInfo.name} - Time Tracking App',
      );

      DomainLogger.info('Windows environment setup completed successfully', component: _componentName);
    } catch (e) {
      DomainLogger.error('Error setting up Windows environment: $e', component: _componentName);
    }
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    await _updateService.downloadAndInstallUpdate(downloadUrl);
  }

  @override
  Future<void> addFirewallRules({
    required String ruleNamePrefix,
    required String appPath,
    required String port,
    String protocol = 'TCP',
  }) async {
    await _firewallService.addFirewallRules(
      ruleNamePrefix: ruleNamePrefix,
      appPath: appPath,
      port: port,
      protocol: protocol,
    );
  }

  @override
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'}) async {
    return await _firewallService.checkFirewallRule(
      ruleName: ruleName,
      protocol: protocol,
    );
  }

  @override
  Future<void> addFirewallRule({
    required String ruleName,
    required String appPath,
    required String port,
    String protocol = 'TCP',
    String direction = 'in',
  }) async {
    await _firewallService.addFirewallRule(
      ruleName: ruleName,
      appPath: appPath,
      port: port,
      protocol: protocol,
      direction: direction,
    );
  }

  @override
  Future<void> removeFirewallRule({required String ruleName}) async {
    await _firewallService.removeFirewallRule(ruleName: ruleName);
  }
}
