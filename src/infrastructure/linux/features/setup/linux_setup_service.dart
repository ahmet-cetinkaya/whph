import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:whph/infrastructure/shared/features/setup/services/abstraction/base_setup_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'services/abstraction/i_linux_firewall_service.dart';
import 'services/abstraction/i_linux_desktop_service.dart';
import 'services/abstraction/i_linux_kde_service.dart';
import 'services/abstraction/i_linux_update_service.dart';

// Re-export exception for backwards compatibility
export 'exceptions/linux_firewall_rule_exception.dart';

/// Linux-specific setup service.
///
/// Coordinates Linux platform setup through specialized services:
/// - Firewall rule management (UFW)
/// - Desktop file and icon installation
/// - KDE Plasma integration
/// - Application updates
class LinuxSetupService extends BaseSetupService {
  final ILinuxFirewallService _firewallService;
  final ILinuxDesktopService _desktopService;
  final ILinuxKdeService _kdeService;
  final ILinuxUpdateService _updateService;

  static const String _componentName = 'LinuxSetupService';

  LinuxSetupService({
    required ILinuxFirewallService firewallService,
    required ILinuxDesktopService desktopService,
    required ILinuxKdeService kdeService,
    required ILinuxUpdateService updateService,
  })  : _firewallService = firewallService,
        _desktopService = desktopService,
        _kdeService = kdeService,
        _updateService = updateService;

  @override
  Future<void> setupEnvironment() async {
    if (!Platform.isLinux) return;

    try {
      final homeDir = Platform.environment['HOME'];
      final localShare = path.join(homeDir!, '.local', 'share');

      final directories = [
        path.join(localShare, 'applications'),
        path.join(localShare, 'icons', 'hicolor', '512x512', 'apps'),
      ];

      await createDirectories(directories);

      final appDir = getApplicationDirectory();
      final iconLocations = [
        path.join(localShare, 'icons', 'hicolor', '512x512', 'apps', 'whph.png'),
        path.join(localShare, 'icons', 'whph.png'),
      ];

      final sourceIcon = path.join(appDir, 'share', 'icons', 'whph.png');
      for (final iconPath in iconLocations) {
        await copyFile(sourceIcon, iconPath);
      }

      final desktopFile = path.join(localShare, 'applications', 'whph.desktop');
      await copyFile(path.join(appDir, 'share', 'applications', 'whph.desktop'), desktopFile);
      await _desktopService.updateDesktopFile(desktopFile, iconLocations.first, appDir);
      await _desktopService.updateIconCache(localShare);
      await _desktopService.installSystemIcon(sourceIcon);

      // KDE Plasma specific setup
      await _kdeService.setupKDEIntegration(appDir);

      DomainLogger.info('Linux environment setup completed successfully', component: _componentName);
    } catch (e) {
      DomainLogger.error('Error setting up Linux environment: $e', component: _componentName);
    }
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    await _updateService.downloadAndInstallUpdate(downloadUrl);
  }

  @override
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'}) async {
    return await _firewallService.checkFirewallRule(ruleName: ruleName, protocol: protocol);
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
