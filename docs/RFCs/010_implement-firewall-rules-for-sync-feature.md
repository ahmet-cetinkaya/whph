# Implement Firewall Rules for Sync Feature

> RFC: 010
> Status: Proposed

## Summary

This RFC proposes implementing platform-specific firewall rule management for WHPH's sync feature to prevent network connectivity issues caused by local firewall settings. The solution extends the existing `ISetupService` interface with methods to create, check, and remove firewall rules for the application on Windows and Linux platforms, handling privilege escalation when necessary.

## Motivation

The sync feature (RFC 006) experiences network connectivity issues due to users' local firewall settings blocking the application. To proactively address this, we need to automatically add platform-specific firewall rules during the application's initial setup or configuration. This enhancement improves the user experience by reducing manual configuration steps and ensuring reliable sync functionality across all supported desktop platforms.

## Detailed Design

The implementation follows the existing clean architecture pattern, extending the setup service infrastructure with platform-specific firewall management capabilities:

### Interface Extension

Extending `ISetupService` in `core/application/shared/services/abstraction/i_setup_service.dart` with three new methods:

```dart
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
```

### Platform Implementations

#### Windows (`windows_setup_service.dart`)

Uses `netsh advfirewall firewall` commands via `Process.run`:
- Check: `netsh advfirewall firewall show rule name="{ruleName}"`
- Add: `netsh advfirewall firewall add rule name="{ruleName}" dir={direction} action=allow program="{appPath}" protocol={protocol} localport={port}`
- Remove: `netsh advfirewall firewall delete rule name="{ruleName}"`

Handles UAC elevation using PowerShell `Start-Process -Verb RunAs` for flexible privilege escalation.

#### Linux (`linux_setup_service.dart`)

Targets the `ufw` (Uncomplicated Firewall) tool:
- Check: Parse `ufw status` output and verify both port/protocol match AND ALLOW action
- Add: `sudo ufw allow {port}/{protocol}`
- Remove: `sudo ufw delete allow {port}/{protocol}`

On permission failures, provides clear error messages instructing users to run commands with `sudo` manually. Automatic privilege escalation is not implemented to avoid security concerns.

### Error Handling and Idempotency

All implementations:
1. Use `checkFirewallRule` to verify rule existence before adding (idempotency)
2. Capture and throw meaningful exceptions for:
   - Permission denied errors
   - Command not found errors
   - Invalid parameters
3. Gracefully handle cases where firewall tools are not available

### Integration with Sync Module

The firewall rule management integrates with the existing sync setup process:
1. During initial setup, the application checks for existing firewall rules
2. If no rules exist, it attempts to add them with appropriate permissions
3. If permission is denied, it informs the user with clear instructions
4. Rules are cleaned up when the application is uninstalled (where possible)

## Implementation Plan

### Phase 1: Interface and Base Implementation

1. Extend `ISetupService` interface with the new methods ✅
2. Create abstract base implementations with default behaviors ✅
3. Add unit tests for the interface contract

### Phase 2: Platform Implementations

1. Implement Windows firewall management using `netsh` ✅
2. Implement Linux firewall management using `ufw` ✅
3. Add integration tests for each platform (where feasible in CI)

### Phase 3: Integration with Sync Module

1. Modify the sync setup process to include firewall rule management
2. Add user-facing UI elements to inform about firewall status
3. Implement error handling and user guidance for permission issues

### Phase 4: Documentation and Testing

1. Document the new functionality in user guides
2. Add end-to-end tests covering the complete setup flow
3. Test on all supported platforms with various firewall configurations

## Trade-offs and Considerations

1. **Privacy**: The implementation only manages firewall rules for the application itself, not collecting any user data
2. **User Experience**: Automatic rule management improves UX but requires explaining privilege escalation to users
3. **Platform Variability**: Different firewall tools across Linux distributions may require additional detection logic
4. **Fallback**: When automatic rule management fails, users can manually configure their firewalls using provided documentation

## Alternatives Considered

1. **Cloud-based relay**: Rejected for privacy concerns and infrastructure complexity
2. **User-only documentation**: Insufficient as it increases support burden and reduces adoption
3. **Single cross-platform tool**: Not feasible due to platform-specific firewall APIs
4. **Bundle firewall tools**: Rejected for increased application size and security concerns

## Success Criteria

1. All three platform implementations function correctly in test environments
2. Integration with the sync setup process is seamless
3. User-facing error messages are clear and actionable
4. Documentation is sufficient for users to manually configure firewalls if needed
5. Test coverage is above 85% for the new functionality

## References

- [PRD Section 4.4: Synchronization](https://github.com/ahmet-cetinkaya/whph/blob/main/docs/PRD.md#L165-L173)
- [MODULES.md: Sync Module](https://github.com/ahmet-cetinkaya/whph/blob/main/docs/MODULES.md#L188-L214)
- [RFC 006: Implement Peer-to-Peer Synchronization](https://github.com/ahmet-cetinkaya/whph/blob/main/docs/RFCs/006_implement-peer-to-peer-synchronization.md)
- Windows: [Netsh AdvFirewall Documentation](https://docs.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-contexts)
- macOS: [socketfilterfw Man Page](https://www.manpagez.com/man/8/socketfilterfw/)
- Linux: [UFW Documentation](https://help.ubuntu.com/community/UFW)