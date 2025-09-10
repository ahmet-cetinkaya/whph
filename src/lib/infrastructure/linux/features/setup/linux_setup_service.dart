import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:whph/infrastructure/shared/features/setup/services/abstraction/base_setup_service.dart';
import 'package:whph/core/shared/utils/logger.dart';

/// Custom exception for firewall rule operations with detailed context
class FirewallRuleException implements Exception {
  final String message;
  final String? invalidValue;
  final int? ufwExitCode;
  final String? ufwStderr;
  final String? ufwStdout;
  
  const FirewallRuleException(
    this.message, {
    this.invalidValue,
    this.ufwExitCode,
    this.ufwStderr,
    this.ufwStdout,
  });
  
  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (invalidValue != null) buffer.write(' [InvalidValue: $invalidValue]');
    if (ufwExitCode != null) buffer.write(' [UFW ExitCode: $ufwExitCode]');
    if (ufwStderr != null) buffer.write(' [UFW Error: $ufwStderr]');
    return buffer.toString();
  }
}

class LinuxSetupService extends BaseSetupService {
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
  Future<void> setupEnvironment() async {
    if (!Platform.isLinux) return;

    final homeDir = Platform.environment['HOME'];
    final localShare = path.join(homeDir!, '.local', 'share');

    try {
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
      await _updateDesktopFile(desktopFile, iconLocations.first);
      await _updateIconCache(localShare);

      await _installSystemIcon(sourceIcon);
    } catch (e) {
      Logger.error('Error setting up Linux environment: $e');
    }
  }

  @override
  Future<void> downloadAndInstallUpdate(String downloadUrl) async {
    try {
      final appDir = getApplicationDirectory();
      final updateScript = path.join(appDir, 'update.sh');
      final downloadPath = path.join(appDir, 'whph_update.tar.gz');

      await downloadFile(downloadUrl, downloadPath);
      await writeFile(updateScript, _getUpdateScript(appDir));
      await makeFileExecutable(updateScript);
      await runDetachedProcess('bash', [updateScript]);
      exit(0);
    } catch (e) {
      Logger.error('Failed to download and install update: $e');
      rethrow;
    }
  }

  String _getUpdateScript(String appDir) =>
      _updateScriptTemplate.replaceAll('{appDir}', appDir).replaceAll('{exePath}', getExecutablePath());

  Future<void> _updateDesktopFile(String filePath, String iconPath) async {
    if (await File(filePath).exists()) {
      var content = await File(filePath).readAsString();
      content = content.replaceAll('Icon=whph', 'Icon=$iconPath');
      await File(filePath).writeAsString(content);
    }
  }

  Future<void> _updateIconCache(String sharePath) async {
    try {
      await Process.run('gtk-update-icon-cache', ['-f', '-t', path.join(sharePath, 'icons', 'hicolor')]);
      await Process.run('update-desktop-database', [path.join(sharePath, 'applications')]);
    } catch (e) {
      Logger.error('Error updating icon cache: $e');
    }
  }

  Future<void> _installSystemIcon(String sourceIcon) async {
    try {
      final userIconDir = path.join(
        Platform.environment['HOME']!,
        '.local',
        'share',
        'icons',
        'hicolor',
        '512x512',
        'apps',
      );

      if (await Directory(userIconDir).exists()) {
        await File(sourceIcon).copy(path.join(userIconDir, 'whph.png'));
        await Process.run('gtk-update-icon-cache', ['-f', '-t', path.join(userIconDir, '..')]);
      }
    } catch (e) {
      Logger.error('Could not install icon: $e');
    }
  }

  // Firewall rule management for Linux
  @override
  Future<bool> checkFirewallRule({required String ruleName}) async {
    try {
      // Check if ufw is available
      final ufwCheck = await Process.run('which', ['ufw'], runInShell: true);
      if (ufwCheck.exitCode != 0) {
        Logger.debug('ufw not found, cannot check firewall rules');
        return false;
      }

      // Get the port from the rule name
      final port = _extractPortFromRuleName(ruleName);
      if (port == null) {
        Logger.error('Could not extract port from rule name: $ruleName');
        return false;
      }
      
      // Validate port
      final portNum = int.tryParse(port);
      if (portNum == null || portNum <= 0 || portNum > 65535) {
        Logger.error('Invalid port number extracted: $port');
        return false;
      }

      final result = await Process.run('ufw', ['status'], runInShell: true);
      return result.stdout.toString().contains('$port/tcp') || result.stdout.toString().contains('$port/udp');
    } catch (e) {
      Logger.error('Error checking firewall rule: $e');
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
      Logger.debug('Attempting to add firewall rule with port: $port, protocol: $protocol');
      
      // Enhanced input validation with detailed error messages
      if (port.isEmpty) {
        final error = 'FirewallRuleError: Port cannot be empty';
        Logger.error(error);
        throw FirewallRuleException(error, invalidValue: port);
      }
      
      final portNum = int.tryParse(port.trim());
      if (portNum == null) {
        final error = 'FirewallRuleError: Port must be a valid integer, received: "$port"';
        Logger.error(error);
        throw FirewallRuleException(error, invalidValue: port);
      }
      
      if (portNum <= 0 || portNum > 65535) {
        final error = 'FirewallRuleError: Port must be between 1-65535, received: $portNum';
        Logger.error(error);
        throw FirewallRuleException(error, invalidValue: port);
      }
      
      // Validate protocol
      if (protocol.isEmpty) {
        final error = 'FirewallRuleError: Protocol cannot be empty';
        Logger.error(error);
        throw FirewallRuleException(error, invalidValue: protocol);
      }
      
      final upperProtocol = protocol.trim().toUpperCase();
      if (upperProtocol != 'TCP' && upperProtocol != 'UDP') {
        final error = 'FirewallRuleError: Protocol must be TCP or UDP, received: "$protocol"';
        Logger.error(error);
        throw FirewallRuleException(error, invalidValue: protocol);
      }

      // Check if ufw is available
      final ufwCheck = await Process.run('which', ['ufw'], runInShell: true);
      if (ufwCheck.exitCode != 0) {
        Logger.debug('ufw not found, cannot add firewall rules');
        return;
      }

      // Check if UFW is enabled/active - this is crucial for avoiding "Bad port" errors
      final statusResult = await Process.run('ufw', ['status'], runInShell: true);
      if (statusResult.exitCode != 0) {
        final error = 'FirewallRuleError: Unable to check UFW status: ${statusResult.stderr}';
        Logger.error(error);
        throw FirewallRuleException(error, invalidValue: 'ufw status command failed');
      }
      
      final statusOutput = statusResult.stdout.toString().toLowerCase();
      if (statusOutput.contains('status: inactive')) {
        Logger.warning('UFW is inactive. Attempting to enable UFW before adding rule...');
        
        // Try to enable UFW non-interactively
        final enableResult = await Process.run('ufw', ['--force', 'enable'], runInShell: true);
        if (enableResult.exitCode != 0) {
          final stderr = enableResult.stderr.toString().toLowerCase();
          if (stderr.contains('permission') ||
              stderr.contains('operation not permitted') ||
              stderr.contains('must be run as root')) {
            Logger.warning(
                'UFW requires administrator privileges to enable. Firewall rule cannot be added automatically.');
            throw FirewallRuleException(
              'Administrator privileges required to enable UFW and add firewall rules. Please run the application as administrator or manually configure UFW.',
              invalidValue: 'insufficient privileges',
              ufwExitCode: enableResult.exitCode,
              ufwStderr: enableResult.stderr.toString(),
            );
          } else {
            final error =
                'FirewallRuleError: Unable to enable UFW: ${enableResult.stderr}. UFW must be enabled to add firewall rules.';
            Logger.error(error);
            throw FirewallRuleException(error, invalidValue: 'ufw enable failed');
          }
        }
        Logger.info('UFW has been enabled successfully');
      }

      // First check if the rule already exists
      final ruleExists = await checkFirewallRule(ruleName: ruleName);
      if (ruleExists) {
        Logger.debug('Firewall rule for port $port already exists');
        return;
      }

      Logger.debug('Executing ufw allow $portNum/$upperProtocol');
      
      // Add the firewall rule with validated parameters
      final result = await Process.run(
        'ufw',
        ['allow', '$portNum/$upperProtocol'],
        runInShell: true,
      );

      Logger.debug('ufw command result - exitCode: ${result.exitCode}, stdout: ${result.stdout}, stderr: ${result.stderr}');
      
      if (result.exitCode != 0) {
        final stderr = result.stderr.toString().trim();
        final stdout = result.stdout.toString().trim();

        // Provide more specific error context and check for permission issues
        String errorContext = '';
        bool isPermissionIssue = false;

        if (stderr.toLowerCase().contains('bad port')) {
          errorContext =
              ' (Possible causes: UFW configuration corruption, invalid port format, or system firewall conflicts)';
        } else if (stderr.toLowerCase().contains('permission') ||
            stderr.toLowerCase().contains('operation not permitted') ||
            stderr.toLowerCase().contains('must be run as root')) {
          errorContext = ' (Administrator privileges required - please run as administrator or use sudo)';
          isPermissionIssue = true;
        } else if (stderr.toLowerCase().contains('duplicate')) {
          errorContext = ' (Rule may already exist in a different format)';
        }

        final error = isPermissionIssue
            ? 'Administrator privileges required to add UFW firewall rule for port $portNum/$upperProtocol. Please run the application as administrator or manually configure UFW with: sudo ufw allow $portNum/$upperProtocol'
            : 'FirewallRuleError: Failed to add UFW rule for port $portNum/$upperProtocol$errorContext. UFW error: $stderr';

        Logger.error(error);
        Logger.error('UFW stdout: $stdout');

        throw FirewallRuleException(
          error,
          invalidValue: '$portNum/$upperProtocol',
          ufwExitCode: result.exitCode,
          ufwStderr: stderr,
          ufwStdout: stdout,
        );
      }

      Logger.info('Successfully added firewall rule for port $portNum/$upperProtocol');
    } catch (e) {
      if (e is FirewallRuleException) {
        Logger.error('Firewall rule creation failed: ${e.message}');
        rethrow;
      } else {
        final error = 'FirewallRuleError: Unexpected error while adding firewall rule: $e';
        Logger.error(error);
        throw FirewallRuleException(error, invalidValue: port);
      }
    }
  }

  @override
  Future<void> removeFirewallRule({required String ruleName}) async {
    try {
      // Check if ufw is available
      final ufwCheck = await Process.run('which', ['ufw'], runInShell: true);
      if (ufwCheck.exitCode != 0) {
        Logger.debug('ufw not found, cannot remove firewall rules');
        return;
      }

      // Extract the port from the rule name
      final port = _extractPortFromRuleName(ruleName);
      if (port == null) {
        Logger.error('Could not extract port from rule name: $ruleName');
        // Try to get port from the addFirewallRule method's port parameter pattern
        // This is a fallback for cases where we can't extract from rule name
        final regex = RegExp(r'(\d{1,5})');
        final match = regex.firstMatch(ruleName);
        if (match != null) {
          final extractedPort = match.group(1);
          final portNum = int.tryParse(extractedPort!);
          if (portNum != null && portNum > 0 && portNum <= 65535) {
            final result = await Process.run(
              'ufw',
              ['delete', 'allow', '$portNum/tcp'],
              runInShell: true,
            );

            if (result.exitCode != 0) {
              Logger.error('Failed to remove firewall rule: ${result.stderr}');
              throw Exception('Failed to remove firewall rule: ${result.stderr}');
            }

            Logger.debug('Successfully removed firewall rule for port: $portNum');
            return;
          }
        }
        return;
      }

      final result = await Process.run(
        'ufw',
        ['delete', 'allow', '$port/tcp'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        Logger.error('Failed to remove firewall rule: ${result.stderr}');
        throw Exception('Failed to remove firewall rule: ${result.stderr}');
      }

      Logger.debug('Successfully removed firewall rule for port: $port');
    } catch (e) {
      Logger.error('Error removing firewall rule: $e');
      rethrow;
    }
  }

  // Helper method to extract port from rule name
  String? _extractPortFromRuleName(String ruleName) {
    // Enhanced regex to match various formats like "Port XXXX", "Port-XXXX", or just numbers
    final regex = RegExp(r'(?:Port\s+|Port-|#)(\d{1,5})|(\d{1,5})(?:\s*$)');
    final match = regex.firstMatch(ruleName);
    
    if (match != null) {
      // Check all groups for a valid port
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
    
    // Fallback: try to find any 1-5 digit number in the string
    final numberRegex = RegExp(r'\d{1,5}');
    final numberMatch = numberRegex.firstMatch(ruleName);
    if (numberMatch != null) {
      final portStr = numberMatch.group(0)!;
      final portNum = int.tryParse(portStr);
      if (portNum != null && portNum > 0 && portNum <= 65535) {
        return portStr;
      }
    }
    
    return null;
  }
}
