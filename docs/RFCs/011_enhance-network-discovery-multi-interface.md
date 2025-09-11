# Enhance Network Discovery with Multi-Interface Support

> RFC: 011  
> Status: In Progress  
> Related Issues: #53

## Summary

This RFC proposes enhancing the sync feature's network discovery mechanism to utilize all available network interfaces for broadcasting and connection attempts, with a manual IP address input fallback. This addresses connectivity issues when devices have multiple network interfaces (Wi-Fi + Ethernet) and ensures robust peer discovery across different network segments.

## Motivation

Currently, the sync feature appears to select only one IP address for discovery and connection, causing failures when:
- Devices are connected to multiple networks simultaneously (Wi-Fi + Ethernet)
- Peer devices are on different subnets or can only reach non-selected IP addresses
- Network configurations require specific interface usage

This forces users into troubleshooting network configurations or disabling interfaces, breaking the seamless "it just works" experience. Applications like LocalSend demonstrate excellent UX by attempting connections across multiple interfaces concurrently.

## Detailed Design

### 1. Multi-Interface IP Discovery Service

**Location**: `src/lib/core/application/features/sync/services/network_interface_service.dart`

```dart
abstract class INetworkInterfaceService {
  Future<List<String>> getLocalIPAddresses();
  Future<List<NetworkInterface>> getActiveNetworkInterfaces();
  bool isValidLocalIPAddress(String ipAddress);
}

class NetworkInterfaceService implements INetworkInterfaceService {
  // Implementation to discover all local IP addresses
  // Exclude loopback, link-local, and invalid addresses
  // Support IPv4 primarily, with IPv6 consideration for future
}
```

### 2. Enhanced Connection Models

**Location**: `src/lib/core/domain/features/sync/models/`

Update existing sync models to support multiple IP addresses:

```dart
class SyncDevice {
  final String deviceId;
  final String deviceName;
  final List<String> ipAddresses; // Multiple IPs instead of single IP
  final int port;
  final DateTime lastSeen;
}

class SyncConnectionInfo {
  final List<String> availableIPs;
  final int port;
  final String deviceId;
  final String deviceName;
}
```

### 3. Concurrent Connection Service

**Location**: `src/lib/core/application/features/sync/services/concurrent_connection_service.dart`

```dart
abstract class IConcurrentConnectionService {
  Future<WebSocketChannel?> connectToAnyAddress(
    List<String> ipAddresses,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  });
}

class ConcurrentConnectionService implements IConcurrentConnectionService {
  // Attempt connections to all IP addresses simultaneously
  // Return first successful connection
  // Cancel remaining attempts
  // Handle connection failures gracefully
}
```

### 4. Enhanced Broadcasting Logic

Update existing sync services to broadcast on all available interfaces:

**Desktop Implementation** (`src/lib/infrastructure/desktop/features/sync/desktop_sync_service.dart`):
- Bind UDP broadcast sockets to all active interfaces
- Include all local IP addresses in discovery messages

**Mobile Implementation** (`src/lib/infrastructure/android/features/sync/android_sync_service.dart`):
- Use all available network interfaces for peer discovery
- Update nearby connections to work with multiple interfaces

### 5. Manual IP Address Entry UI

**Location**: `src/lib/presentation/ui/features/sync/components/manual_ip_input_dialog.dart`

```dart
class ManualIPInputDialog extends StatefulWidget {
  // Dialog for manual IP address entry
  // Input validation for IP address format
  // Port number input (with default)
  // Connection attempt with progress indication
}
```

### 6. Updated QR Code Protocol

Modify QR code generation to include multiple IP addresses:

```dart
class SyncQRCodeMessage {
  final String deviceId;
  final String deviceName;
  final List<String> ipAddresses; // Multiple IPs
  final int port;
  final String? token; // For security
}
```

### 7. Enhanced Sync Device Discovery

**Location**: Update existing `sync_service.dart` implementations:

```dart
class EnhancedSyncDiscovery {
  // Discover peers across all network interfaces
  // Maintain device availability across multiple IPs
  // Handle IP address changes and interface updates
  // Prioritize faster/more reliable connections
}
```

## Implementation Plan

### Phase 1: Network Interface Discovery
1. Implement `NetworkInterfaceService` for IP address discovery
2. Add platform-specific network interface detection
3. Create tests for IP address filtering and validation

### Phase 2: Connection Enhancement
1. Implement `ConcurrentConnectionService` for multi-IP connections
2. Update existing connection logic to use new service
3. Add connection attempt prioritization (local network first)

### Phase 3: Broadcasting Updates
1. Enhance broadcasting to use all network interfaces
2. Update QR code generation for multiple IPs
3. Modify peer discovery to handle multiple IP addresses

### Phase 4: UI Components
1. Add manual IP address entry dialog
2. Update sync device list to show multiple IP addresses
3. Add connection status indicators for different interfaces

### Phase 5: Integration & Testing
1. Integrate all components into existing sync services
2. Test across different network configurations
3. Performance optimization and error handling

## Protocol Changes

### Discovery Message Format
```json
{
  "deviceId": "uuid",
  "deviceName": "string",
  "ipAddresses": ["192.168.1.100", "10.0.0.50"],
  "port": 8080,
  "timestamp": "iso8601",
  "protocol": "whph-sync-v2"
}
```

### Connection Attempt Strategy
1. **Concurrent Attempts**: Try all IP addresses simultaneously
2. **Timeout Handling**: 3-5 second timeout per attempt
3. **Success Handling**: Use first successful connection, cancel others
4. **Failure Handling**: Try next available device if all IPs fail
5. **Retry Logic**: Exponential backoff for failed connections

## Platform Considerations

### Android
- Request network permissions if not already present
- Handle network state changes and interface updates
- Work with existing nearby connections implementation

### Desktop (Linux/Windows)
- Use native network interface enumeration
- Handle virtual interfaces and VPN connections appropriately
- Integrate with existing UDP broadcast implementation

### Cross-Platform
- Abstract platform differences behind service interfaces
- Maintain consistent behavior across all platforms
- Handle platform-specific network limitations

## Security Considerations

- **IP Validation**: Strict validation to prevent injection attacks
- **Local Network Only**: Restrict to private IP address ranges
- **Connection Limits**: Limit concurrent connection attempts to prevent DoS
- **Timeout Protection**: Prevent resource exhaustion with proper timeouts

## Performance Impact

- **Minimal Overhead**: Network discovery runs in background
- **Connection Speed**: Concurrent attempts should improve connection speed
- **Resource Usage**: Monitor CPU/network usage during discovery
- **Battery Impact**: Optimize mobile implementation for battery life

## Testing Strategy

1. **Unit Tests**: Network interface discovery, IP validation
2. **Integration Tests**: Multi-interface broadcasting and connection
3. **Platform Tests**: Behavior across Android, Windows, Linux
4. **Network Tests**: Various network configurations (Wi-Fi + Ethernet)
5. **Performance Tests**: Connection speed and resource usage
6. **User Tests**: Manual IP entry and connection flow

## Alternatives Considered

### 1. Manual Interface Selection
**Approach**: Settings dropdown for network interface selection  
**Rejected**: Requires technical knowledge, breaks seamless UX

### 2. mDNS-Only Discovery
**Approach**: Rely solely on mDNS for cross-network discovery  
**Rejected**: Can be blocked in corporate networks, less reliable

### 3. Single IP with Fallback
**Approach**: Try primary IP, fallback to others sequentially  
**Rejected**: Slower than concurrent attempts, poor UX

### 4. Network Configuration Detection
**Approach**: Automatically detect and adapt to network topology  
**Rejected**: Complex implementation, may not cover all scenarios

## Success Criteria

- **Reliability**: 95%+ connection success rate in multi-interface scenarios
- **Performance**: Connection establishment within 5 seconds
- **Usability**: Manual IP entry works without technical knowledge
- **Compatibility**: No regression in existing single-interface scenarios
- **Coverage**: Works across all supported platforms

## Dependencies

- `network_info_plus`: Already in use for network information
- `dart:io`: For network interface enumeration
- Existing sync infrastructure
- Platform-specific network APIs

## Migration Strategy

1. **Backward Compatibility**: New protocol supports old single-IP format
2. **Gradual Rollout**: Feature flag for multi-interface discovery
3. **Fallback Behavior**: Graceful degradation to single-IP mode if needed
4. **User Communication**: Clear messaging about improved connectivity

## Future Enhancements

- **IPv6 Support**: Add IPv6 address discovery and connection
- **Network Prioritization**: Prefer faster/more reliable interfaces
- **Mesh Networking**: Support for multi-hop connections
- **Cloud Relay**: Optional relay service for cross-network connections

## References

- [Issue #53](https://github.com/ahmet-cetinkaya/whph/issues/53): Multi-interface network discovery
- [RFC 006](./006_implement-peer-to-peer-synchronization.md): Original sync implementation  
- [Flutter network_info_plus](https://pub.dev/packages/network_info_plus): Network interface detection
- [LocalSend](https://localsend.org/): Reference implementation for multi-interface discovery