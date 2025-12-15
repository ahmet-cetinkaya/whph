import 'package:whph/infrastructure/windows/features/setup/exceptions/windows_firewall_rule_exception.dart';

/// Service for managing Windows Firewall rules through netsh commands
abstract class IWindowsFirewallService {
  /// Add both inbound and outbound firewall rules for the specified port
  ///
  /// Batch executes both rules with a single UAC prompt if elevation is needed
  Future<void> addFirewallRules({
    required String ruleNamePrefix,
    required String appPath,
    required String port,
    String protocol = 'TCP',
  });

  /// Add a single firewall rule
  ///
  /// Throws [WindowsFirewallRuleException] if the rule creation fails
  Future<void> addFirewallRule({
    required String ruleName,
    required String appPath,
    required String port,
    String protocol = 'TCP',
    String direction = 'in',
  });

  /// Check if a firewall rule exists
  Future<bool> checkFirewallRule({
    required String ruleName,
    String protocol = 'TCP',
  });

  /// Remove a firewall rule by name
  Future<void> removeFirewallRule({required String ruleName});
}
