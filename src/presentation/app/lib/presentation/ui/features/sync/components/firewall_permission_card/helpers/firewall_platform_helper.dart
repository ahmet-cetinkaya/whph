import 'dart:io';

import '../../../../../../../../../../../api/api.dart';
import 'package:whph/presentation/ui/features/settings/components/permission_dialog.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';

/// Helper class for platform-specific firewall operations and display logic.
///
/// Provides platform-aware:
/// - Command generation for firewall rules
/// - Instruction sections for manual setup
/// - Platform name resolution
class FirewallPlatformHelper {
  final ITranslationService _translationService;

  FirewallPlatformHelper({required ITranslationService translationService}) : _translationService = translationService;

  /// Returns true if the platform supports manual confirmation (Linux only)
  bool get supportsManualConfirmation => Platform.isLinux;

  /// Returns true if the platform supports automatic firewall rule addition
  bool get supportsAutomaticRuleAddition => Platform.isWindows;

  /// Get platform name for display
  String getPlatformName() {
    if (Platform.isLinux) return 'Linux';
    if (Platform.isWindows) return 'Windows';
    return 'Desktop';
  }

  /// Get the main command(s) for the platform
  String getMainCommand() {
    if (Platform.isLinux) {
      return 'sudo ufw allow $webSocketPort/tcp';
    } else if (Platform.isWindows) {
      final inboundCmd =
          'netsh advfirewall firewall add rule name="WHPH Sync Port $webSocketPort (Inbound)" dir=in action=allow program="${Platform.resolvedExecutable}" protocol=TCP localport=$webSocketPort';
      final outboundCmd =
          'netsh advfirewall firewall add rule name="WHPH Sync Port $webSocketPort (Outbound)" dir=out action=allow program="${Platform.resolvedExecutable}" protocol=TCP localport=$webSocketPort';
      return '$inboundCmd\n$outboundCmd';
    }
    return '';
  }

  /// Get firewall rule names for verification
  String getInboundRuleName() => 'WHPH Sync Port $webSocketPort (Inbound)';
  String getOutboundRuleName() => 'WHPH Sync Port $webSocketPort (Outbound)';

  /// Get Windows instruction sections
  List<PermissionInstructionSection> getWindowsInstructionSections() {
    return [
      // Simplified GUI instructions
      PermissionInstructionSection(
        title: '', // No title for the main section
        steps: [
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepOpenDefender),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepCreateInboundRule),
          _translationService.translate(SettingsTranslationKeys.firewallInstructionWindowsStepCreateOutboundRule),
        ],
        copyableCommands: List.filled(3, ''), // No copyable commands for GUI steps
      ),
      // Command prompt alternative
      PermissionInstructionSection(
        title: 'Command Prompt (Alternative)',
        steps: [
          'Open Command Prompt as Administrator and run:',
        ],
        copyableCommands: [
          '', // No command for opening CMD
          getMainCommand(), // The actual commands
        ],
      ),
    ];
  }
}
