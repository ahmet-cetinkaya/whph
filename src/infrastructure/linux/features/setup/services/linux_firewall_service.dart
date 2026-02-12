import 'dart:io';
import 'package:domain/shared/utils/logger.dart';
import '../exceptions/linux_firewall_rule_exception.dart';
import 'abstraction/i_linux_firewall_service.dart';

/// Implementation of Linux firewall operations using UFW.
class LinuxFirewallService implements ILinuxFirewallService {
  static const String _componentName = 'LinuxFirewallService';

  @override
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'}) async {
    try {
      final ufwCheck = await Process.run('which', ['ufw'], runInShell: true);
      if (ufwCheck.exitCode != 0) {
        DomainLogger.debug('ufw not found, cannot check firewall rules', component: _componentName);
        return false;
      }

      final port = _extractPortFromRuleName(ruleName);
      if (port == null) {
        DomainLogger.error('Could not extract port from rule name: $ruleName', component: _componentName);
        return false;
      }

      final portNum = int.tryParse(port);
      if (portNum == null || portNum <= 0 || portNum > 65535) {
        DomainLogger.error('Invalid port number extracted: $port', component: _componentName);
        return false;
      }

      final result = await Process.run('ufw', ['status'], runInShell: true);
      final lowerProtocol = protocol.toLowerCase();
      return result.stdout
          .toString()
          .split('\n')
          .any((line) => line.contains('$port/$lowerProtocol') && line.contains('ALLOW'));
    } catch (e) {
      DomainLogger.error('Error checking firewall rule: $e', component: _componentName);
      return false;
    }
  }

  @override
  Future<void> addFirewallRule({
    required String ruleName,
    required String appPath,
    required String port,
    String protocol = 'TCP',
    String direction = 'in',
  }) async {
    try {
      DomainLogger.debug('Attempting to add firewall rule with port: $port, protocol: $protocol',
          component: _componentName);

      _validatePort(port);
      final upperProtocol = _validateProtocol(protocol);
      final portNum = int.parse(port.trim());

      final ufwCheck = await Process.run('which', ['ufw'], runInShell: true);
      if (ufwCheck.exitCode != 0) {
        DomainLogger.debug('ufw not found, cannot add firewall rules', component: _componentName);
        return;
      }

      await _ensureUfwEnabled();

      DomainLogger.debug('Executing ufw allow $portNum/$upperProtocol', component: _componentName);

      final result = await Process.run(
        'ufw',
        ['allow', '$portNum/$upperProtocol'],
        runInShell: true,
      );

      DomainLogger.debug(
          'ufw command result - exitCode: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}',
          component: _componentName);

      if (result.exitCode != 0) {
        _handleAddRuleError(result, portNum, upperProtocol);
      }

      DomainLogger.info('Successfully added firewall rule for port $portNum/$upperProtocol', component: _componentName);
    } catch (e) {
      if (e is LinuxFirewallRuleException) {
        DomainLogger.error('Firewall rule creation failed: ${e.message}', component: _componentName);
        rethrow;
      }
      final error = 'Unexpected error while adding firewall rule: $e';
      DomainLogger.error(error, component: _componentName);
      throw LinuxFirewallRuleException(error, invalidValue: port);
    }
  }

  @override
  Future<void> removeFirewallRule({required String ruleName}) async {
    try {
      final ufwCheck = await Process.run('which', ['ufw'], runInShell: true);
      if (ufwCheck.exitCode != 0) {
        DomainLogger.debug('ufw not found, cannot remove firewall rules', component: _componentName);
        return;
      }

      final port = _extractPortFromRuleName(ruleName);
      if (port == null) {
        DomainLogger.error('Could not extract port from rule name for removal: $ruleName', component: _componentName);
        return;
      }

      for (final protocol in ['tcp', 'udp']) {
        final result = await Process.run(
          'ufw',
          ['delete', 'allow', '$port/$protocol'],
          runInShell: true,
        );

        final stderr = result.stderr.toString();
        if (result.exitCode != 0 && !stderr.contains('Skipping')) {
          final error = 'Failed to remove firewall rule for $port/$protocol: $stderr';
          DomainLogger.error(error, component: _componentName);
          throw LinuxFirewallRuleException(error, ufwExitCode: result.exitCode, ufwStderr: stderr);
        }
      }

      DomainLogger.info('Successfully removed firewall rules for port: $port', component: _componentName);
    } catch (e) {
      if (e is LinuxFirewallRuleException) rethrow;

      final error = 'Unexpected error while removing firewall rule: $e';
      DomainLogger.error(error, component: _componentName);
      throw LinuxFirewallRuleException(error);
    }
  }

  void _validatePort(String port) {
    if (port.isEmpty) {
      throw LinuxFirewallRuleException('Port cannot be empty', invalidValue: port);
    }

    final portNum = int.tryParse(port.trim());
    if (portNum == null) {
      throw LinuxFirewallRuleException('Port must be a valid integer, received: "$port"', invalidValue: port);
    }

    if (portNum <= 0 || portNum > 65535) {
      throw LinuxFirewallRuleException('Port must be between 1-65535, received: $portNum', invalidValue: port);
    }
  }

  String _validateProtocol(String protocol) {
    if (protocol.isEmpty) {
      throw LinuxFirewallRuleException('Protocol cannot be empty', invalidValue: protocol);
    }

    final upperProtocol = protocol.trim().toUpperCase();
    if (upperProtocol != 'TCP' && upperProtocol != 'UDP') {
      throw LinuxFirewallRuleException('Protocol must be TCP or UDP, received: "$protocol"', invalidValue: protocol);
    }
    return upperProtocol;
  }

  Future<void> _ensureUfwEnabled() async {
    final statusResult = await Process.run('ufw', ['status'], runInShell: true);
    if (statusResult.exitCode != 0) {
      throw LinuxFirewallRuleException('Unable to check UFW status: ${statusResult.stderr}',
          invalidValue: 'ufw status command failed');
    }

    final statusOutput = statusResult.stdout.toString().toLowerCase();
    if (statusOutput.contains('status: inactive')) {
      DomainLogger.warning('UFW is inactive. Attempting to enable UFW before adding rule...');

      final enableResult = await Process.run('ufw', ['--force', 'enable'], runInShell: true);
      if (enableResult.exitCode != 0) {
        final stderr = enableResult.stderr.toString().toLowerCase();
        if (stderr.contains('permission') ||
            stderr.contains('operation not permitted') ||
            stderr.contains('must be run as root')) {
          throw LinuxFirewallRuleException(
            'Administrator privileges required to enable UFW and add firewall rules.',
            invalidValue: 'insufficient privileges',
            ufwExitCode: enableResult.exitCode,
            ufwStderr: enableResult.stderr.toString(),
          );
        }
        throw LinuxFirewallRuleException('Unable to enable UFW: ${enableResult.stderr}',
            invalidValue: 'ufw enable failed');
      }
      DomainLogger.info('UFW has been enabled successfully');
    }
  }

  void _handleAddRuleError(ProcessResult result, int portNum, String protocol) {
    final stderr = result.stderr.toString().trim();
    final stdout = result.stdout.toString().trim();

    String errorContext = '';
    bool isPermissionIssue = false;

    if (stderr.toLowerCase().contains('bad port')) {
      errorContext = ' (Possible: UFW corruption, invalid port format, or system conflicts)';
    } else if (stderr.toLowerCase().contains('permission') ||
        stderr.toLowerCase().contains('operation not permitted') ||
        stderr.toLowerCase().contains('must be run as root')) {
      errorContext = ' (Administrator privileges required)';
      isPermissionIssue = true;
    } else if (stderr.toLowerCase().contains('duplicate')) {
      errorContext = ' (Rule may already exist)';
    }

    final error = isPermissionIssue
        ? 'Administrator privileges required for port $portNum/$protocol. Use: sudo ufw allow $portNum/$protocol'
        : 'Failed to add UFW rule for $portNum/$protocol$errorContext. Error: $stderr';

    DomainLogger.error(error, component: _componentName);
    DomainLogger.error('UFW stdout: $stdout', component: _componentName);

    throw LinuxFirewallRuleException(
      error,
      invalidValue: '$portNum/$protocol',
      ufwExitCode: result.exitCode,
      ufwStderr: stderr,
      ufwStdout: stdout,
    );
  }

  String? _extractPortFromRuleName(String ruleName) {
    final regex = RegExp(r'(?:Port\s+|Port-|#)(\d{1,5})|(\d{1,5})(?:\s*$)');
    final match = regex.firstMatch(ruleName);

    if (match != null) {
      for (int i = 1; i <= match.groupCount; i++) {
        final group = match.group(i);
        if (group != null && group.isNotEmpty) {
          final portNum = int.tryParse(group);
          if (portNum != null && portNum > 0 && portNum <= 65535) {
            return group;
          }
        }
      }
    }
    return null;
  }
}
