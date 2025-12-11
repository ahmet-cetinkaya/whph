import 'dart:io';
import 'package:whph/core/application/shared/services/abstraction/i_setup_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/api/api.dart';
import 'package:acore/acore.dart';

/// Service responsible for setting up firewall rules for the sync feature
class FirewallSetupService {
  /// Sets up firewall rules for the sync feature
  static Future<void> setupSyncFirewallRules(IContainer container) async {
    // Only run on desktop platforms
    if (!PlatformUtils.isDesktop) {
      Logger.debug('FirewallSetupService: Not a desktop platform, skipping firewall setup');
      return;
    }

    try {
      Logger.info('FirewallSetupService: Setting up firewall rules for sync feature...');

      // Resolve the setup service from the container
      final setupService = container.resolve<ISetupService>();

      // Define rule parameters using the WebSocket port
      final port = webSocketPort.toString();
      const protocol = 'TCP';
      // IMPORTANT: This naming format is tightly coupled with LinuxSetupService._extractPortFromRuleName()
      // The Linux implementation relies on parsing this specific string format to extract the port number
      // If this format changes, update the Linux parsing logic accordingly
      final ruleName = 'WHPH Sync Port $port';
      final appPath = Platform.resolvedExecutable;

      Logger.debug('FirewallSetupService: Using port=$port, protocol=$protocol, ruleName=$ruleName, appPath=$appPath');

      // Check if the rule already exists
      final ruleExists = await setupService.checkFirewallRule(ruleName: ruleName, protocol: protocol);

      if (!ruleExists) {
        Logger.debug('FirewallSetupService: Firewall rule does not exist, creating it...');

        // Add the firewall rule
        await setupService.addFirewallRule(
          ruleName: ruleName,
          appPath: appPath,
          port: port,
          protocol: protocol,
        );

        Logger.info('FirewallSetupService: Successfully added firewall rule for sync feature on port $port');
      } else {
        Logger.debug('FirewallSetupService: Firewall rule already exists for sync feature');
      }
    } catch (e, stackTrace) {
      Logger.error('FirewallSetupService: Failed to set up firewall rules: $e');
      Logger.error('FirewallSetupService: Stack trace: $stackTrace');

      // We don't rethrow the error as firewall setup failure shouldn't prevent app startup
      // but we do log it for debugging purposes
    }
  }

  /// Removes firewall rules for the sync feature (for cleanup)
  static Future<void> removeSyncFirewallRules(IContainer container) async {
    // Only run on desktop platforms
    if (!PlatformUtils.isDesktop) {
      Logger.debug('FirewallSetupService: Not a desktop platform, skipping firewall cleanup');
      return;
    }

    try {
      Logger.info('FirewallSetupService: Removing firewall rules for sync feature...');

      // Resolve the setup service from the container
      final setupService = container.resolve<ISetupService>();

      // Define rule parameters using the WebSocket port
      final port = webSocketPort.toString();
      // IMPORTANT: Must match the format used in setupSyncFirewallRules() for consistency
      final ruleName = 'WHPH Sync Port $port';

      Logger.debug('FirewallSetupService: Removing rule with port=$port, ruleName=$ruleName');

      // Remove the firewall rule
      await setupService.removeFirewallRule(ruleName: ruleName);

      Logger.info('FirewallSetupService: Successfully removed firewall rule for sync feature');
    } catch (e, stackTrace) {
      Logger.error('FirewallSetupService: Failed to remove firewall rules: $e');
      Logger.error('FirewallSetupService: Stack trace: $stackTrace');

      // We don't rethrow the error as firewall cleanup failure shouldn't prevent app shutdown
    }
  }
}
