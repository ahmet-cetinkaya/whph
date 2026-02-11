import 'dart:io';

import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/windows/features/setup/exceptions/windows_firewall_rule_exception.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_elevation_service.dart';
import 'package:whph/infrastructure/windows/features/setup/services/abstraction/i_windows_firewall_service.dart';

/// Implementation of Windows Firewall management service
class WindowsFirewallService implements IWindowsFirewallService {
  final IWindowsElevationService _elevationService;

  static const String _componentName = 'WindowsFirewallService';

  WindowsFirewallService({
    required IWindowsElevationService elevationService,
  }) : _elevationService = elevationService;

  @override
  Future<void> addFirewallRules({
    required String ruleNamePrefix,
    required String appPath,
    required String port,
    String protocol = 'TCP',
  }) async {
    try {
      DomainLogger.info('Starting Windows firewall rule addition for port $port/$protocol', component: _componentName);

      // Check if rules already exist
      final inboundRuleName = '$ruleNamePrefix (Inbound)';
      final outboundRuleName = '$ruleNamePrefix (Outbound)';

      final inboundExists = await checkFirewallRule(ruleName: inboundRuleName);
      final outboundExists = await checkFirewallRule(ruleName: outboundRuleName);

      if (inboundExists && outboundExists) {
        DomainLogger.info('Both inbound and outbound firewall rules already exist - skipping addition',
            component: _componentName);
        return;
      }

      // Check if running as admin
      final isAdmin = await _elevationService.isRunningAsAdmin();
      DomainLogger.info('Running as administrator: $isAdmin', component: _componentName);

      // Build netsh commands for both rules
      final commands = <String>[];

      if (!inboundExists) {
        final inboundCmd =
            'netsh advfirewall firewall add rule name="$inboundRuleName" dir=in action=allow program="$appPath" protocol=$protocol localport=$port';
        commands.add(inboundCmd);
      }

      if (!outboundExists) {
        final outboundCmd =
            'netsh advfirewall firewall add rule name="$outboundRuleName" dir=out action=allow program="$appPath" protocol=$protocol localport=$port';
        commands.add(outboundCmd);
      }

      if (commands.isEmpty) {
        DomainLogger.info('No new firewall rules needed', component: _componentName);
        return;
      }

      DomainLogger.info('Adding ${commands.length} firewall rules', component: _componentName);

      ProcessResult result;

      if (isAdmin) {
        // Running as admin - execute commands directly
        DomainLogger.info('Executing netsh commands directly with admin privileges', component: _componentName);
        for (final cmd in commands) {
          result = await Process.run('cmd', ['/c', cmd], runInShell: true);
          if (result.exitCode != 0) {
            throw WindowsFirewallRuleException(
              'Failed to add firewall rule: ${result.stderr}',
              netshExitCode: result.exitCode,
              netshStderr: result.stderr,
              netshStdout: result.stdout,
            );
          }
        }
        DomainLogger.info('Firewall rules added successfully', component: _componentName);
        result = ProcessResult(0, 0, '', ''); // Success
      } else {
        // Request elevation using a single PowerShell session for all commands
        DomainLogger.info('Requesting single elevation to run ${commands.length} netsh commands',
            component: _componentName);
        result = await _elevationService.runMultipleCommandsWithElevatedPrivileges(commands);
      }

      DomainLogger.debug('Batch netsh commands result - exitCode: ${result.exitCode}', component: _componentName);
      if (result.exitCode != 0) {
        final stdout = result.stdout.toString().trim();
        final stderr = result.stderr.toString().trim();

        if (stdout.isNotEmpty) {
          DomainLogger.error('Netsh stdout: $stdout', component: _componentName);
        }
        if (stderr.isNotEmpty) {
          DomainLogger.error('Netsh stderr: $stderr', component: _componentName);
        }

        throw WindowsFirewallRuleException(
          'Windows firewall rules creation failed: ${result.exitCode}',
          netshExitCode: result.exitCode,
          netshStderr: stderr,
          netshStdout: stdout,
        );
      } else {
        DomainLogger.info('Windows firewall rules created successfully', component: _componentName);
      }
    } catch (e) {
      if (e is WindowsFirewallRuleException) {
        DomainLogger.error('Windows firewall rules creation failed: ${e.message}', component: _componentName);
        rethrow;
      } else {
        final error = 'WindowsFirewallRuleError: Unexpected error while adding firewall rules: $e';
        DomainLogger.error('Unexpected error while adding firewall rules: $e', component: _componentName);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }
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
      DomainLogger.debug('Attempting to add Windows firewall rule: $ruleName for port $port/$protocol',
          component: _componentName);

      // Enhanced input validation
      if (port.isEmpty) {
        final error = 'WindowsFirewallRuleError: Port cannot be empty';
        DomainLogger.error(error, component: _componentName);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }

      final portNum = int.tryParse(port.trim());
      if (portNum == null) {
        final error = 'WindowsFirewallRuleError: Port must be a valid integer, received: "$port"';
        DomainLogger.error(error, component: _componentName);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }

      if (portNum <= 0 || portNum > 65535) {
        final error = 'WindowsFirewallRuleError: Port must be between 1-65535, received: $portNum';
        DomainLogger.error(error, component: _componentName);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }

      // Validate protocol
      final upperProtocol = protocol.trim().toUpperCase();
      if (upperProtocol != 'TCP' && upperProtocol != 'UDP') {
        final error = 'WindowsFirewallRuleError: Protocol must be TCP or UDP, received: "$protocol"';
        DomainLogger.error(error, component: _componentName);
        throw WindowsFirewallRuleException(error, invalidValue: protocol);
      }

      // First check if the rule already exists
      final ruleExists = await checkFirewallRule(ruleName: ruleName);
      if (ruleExists) {
        DomainLogger.debug('Windows firewall rule "$ruleName" already exists', component: _componentName);
        return;
      }

      // Check if running as admin
      final isAdmin = await _elevationService.isRunningAsAdmin();
      DomainLogger.debug('Running as administrator: $isAdmin', component: _componentName);

      final netshArgs = [
        'advfirewall',
        'firewall',
        'add',
        'rule',
        'name="$ruleName"',
        'dir=$direction',
        'action=allow',
        'program="$appPath"',
        'protocol=$upperProtocol',
        'localport=$portNum',
      ];

      ProcessResult result;

      if (isAdmin) {
        // If already running as admin, execute directly
        DomainLogger.debug('Executing netsh command directly with admin privileges', component: _componentName);
        result = await Process.run('netsh', netshArgs, runInShell: true);
      } else {
        // Request elevation using PowerShell
        DomainLogger.debug('Requesting elevation to run netsh command', component: _componentName);
        result = await _elevationService.runWithElevatedPrivileges('netsh', netshArgs);
      }

      DomainLogger.debug(
          'Netsh command result - exitCode: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}',
          component: _componentName);

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        final stdout = result.stdout.toString().trim();

        // Provide specific error context
        String errorContext = '';
        bool isPermissionIssue = false;

        if (stderr.toLowerCase().contains('access is denied') ||
            stderr.toLowerCase().contains('operation requires elevation') ||
            stderr.toLowerCase().contains('administrator')) {
          errorContext = ' (Administrator privileges required)';
          isPermissionIssue = true;
        } else if (stderr.toLowerCase().contains('already exists') || stderr.toLowerCase().contains('duplicate')) {
          errorContext = ' (Rule may already exist with different parameters)';
        }

        final error = isPermissionIssue
            ? 'Administrator privileges required to add Windows Firewall rule for port $portNum/$upperProtocol. Please run the application as administrator or manually add the firewall rule in Windows Defender Firewall settings.'
            : 'WindowsFirewallRuleError: Failed to add Windows Firewall rule for port $portNum/$upperProtocol$errorContext. Netsh error: $stderr';

        DomainLogger.error(error, component: _componentName);
        DomainLogger.error('Netsh stdout: $stdout', component: _componentName);

        throw WindowsFirewallRuleException(
          error,
          invalidValue: '$portNum/$upperProtocol',
          netshExitCode: result.exitCode,
          netshStderr: stderr,
          netshStdout: stdout,
        );
      }

      DomainLogger.info('Successfully added Windows firewall rule: $ruleName for port $portNum/$upperProtocol',
          component: _componentName);
    } catch (e) {
      if (e is WindowsFirewallRuleException) {
        DomainLogger.error('Windows firewall rule creation failed: ${e.message}', component: _componentName);
        rethrow;
      } else {
        final error = 'WindowsFirewallRuleError: Unexpected error while adding firewall rule: $e';
        DomainLogger.error(error, component: _componentName);
        throw WindowsFirewallRuleException(error, invalidValue: port);
      }
    }
  }

  @override
  Future<bool> checkFirewallRule({required String ruleName, String protocol = 'TCP'}) async {
    try {
      DomainLogger.debug('Checking Windows firewall rule: $ruleName (protocol: $protocol)', component: _componentName);

      // First, try using netsh as primary method (more reliable for exact name matching)
      final result = await Process.run(
        'netsh',
        ['advfirewall', 'firewall', 'show', 'rule', 'name=$ruleName'],
        runInShell: true,
      );

      final output = result.stdout.toString();
      final exitCode = result.exitCode;

      // For netsh, if the rule exists, the output should contain the rule name and exit code is 0
      final ruleExists = output.contains(ruleName) && exitCode == 0;

      DomainLogger.info('Firewall rule "$ruleName" exists: $ruleExists', component: _componentName);

      if (ruleExists) {
        return true;
      }

      // If netsh didn't find it, try PowerShell as fallback
      DomainLogger.debug('Netsh did not find rule, attempting PowerShell fallback', component: _componentName);

      try {
        DomainLogger.debug('Executing PowerShell: Get-NetFirewallRule -Name "$ruleName"', component: _componentName);
        final psResult = await Process.run(
          'powershell',
          ['-Command', 'Get-NetFirewallRule -Name "$ruleName"'],
          runInShell: true,
        );

        final psRuleExists = psResult.exitCode == 0;

        if (psRuleExists) {
          DomainLogger.info('Firewall rule "$ruleName" exists (PowerShell fallback)', component: _componentName);
        }

        return psRuleExists;
      } catch (psError) {
        DomainLogger.warning('PowerShell fallback also failed: $psError', component: _componentName);
        return false;
      }
    } catch (e) {
      DomainLogger.error('Failed to check firewall rule: $e', component: _componentName);
      return false;
    }
  }

  @override
  Future<void> removeFirewallRule({required String ruleName}) async {
    try {
      final ruleExists = await checkFirewallRule(ruleName: ruleName);
      if (!ruleExists) {
        DomainLogger.debug('Firewall rule "$ruleName" does not exist, skipping removal.', component: _componentName);
        return;
      }

      final result = await Process.run(
        'netsh',
        ['advfirewall', 'firewall', 'delete', 'rule', 'name="$ruleName"'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString();
        DomainLogger.error('Failed to remove firewall rule: $stderr', component: _componentName);
        throw WindowsFirewallRuleException('Failed to remove firewall rule: $stderr');
      }

      DomainLogger.debug('Successfully removed firewall rule: $ruleName', component: _componentName);
    } catch (e) {
      DomainLogger.error('Error removing firewall rule: $e', component: _componentName);
      rethrow;
    }
  }
}
