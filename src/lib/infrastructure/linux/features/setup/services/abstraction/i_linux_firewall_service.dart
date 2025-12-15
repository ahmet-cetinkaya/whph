/// Interface for Linux firewall operations using UFW.
abstract class ILinuxFirewallService {
  /// Check if a firewall rule exists for the given rule name.
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'});

  /// Add a firewall rule for the given port and protocol.
  Future<void> addFirewallRule({
    required String ruleName,
    required String appPath,
    required String port,
    String protocol = 'TCP',
    String direction = 'in',
  });

  /// Remove a firewall rule by rule name.
  Future<void> removeFirewallRule({required String ruleName});
}
