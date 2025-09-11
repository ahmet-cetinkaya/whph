import 'package:flutter/material.dart';

abstract class ISetupService {
  Future<void> setupEnvironment();
  Future<void> checkForUpdates(BuildContext context);

  /// Checks whether a firewall rule with the specified name already exists.
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'});

  /// Adds a firewall rule for the specified application path with the given port,
  /// protocol, and direction.
  Future<void> addFirewallRule({
    required String ruleName,
    required String appPath,
    required String port,
    String protocol = 'TCP',
    String direction = 'in',
  });

  /// Removes the firewall rule with the specified name.
  Future<void> removeFirewallRule({required String ruleName});
}
