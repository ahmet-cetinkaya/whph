# Implement PC Client Sync Capability

> RFC: 012  
> Status: Draft  
> Related Issues: #36

## Summary

This RFC proposes enabling PC/Desktop applications to function as sync clients, allowing them to connect to other WHPH instances (mobile or desktop) acting as servers. Currently, desktop applications can only operate as servers in the sync architecture, creating an inflexible topology that prevents desktop-to-desktop sync scenarios.

## Motivation

The current sync architecture has an asymmetric limitation where:

- Desktop applications can only act as servers (`DesktopSyncService` with timer-based periodic sync)
- Mobile devices can act as both servers (`AndroidServerSyncService`) and clients
- Users cannot establish desktop-to-desktop sync with one device as primary server
- Laptop users cannot connect to their desktop as a client for data synchronization

This forces users into suboptimal sync topologies and prevents common use cases like syncing between home desktop and work laptop. Issue #36 specifically requests this functionality with support for both QR code pairing and manual connection strings.

## Detailed Design

### 1. Desktop Client Service Implementation

**Location**: `src/lib/infrastructure/desktop/features/sync/desktop_client_sync_service.dart`

```dart
class DesktopClientSyncService extends SyncService {
  WebSocketChannel? _clientChannel;
  Timer? _heartbeatTimer;
  String? _connectedServerAddress;
  int? _connectedServerPort;

  /// Connect to a WHPH server as client
  Future<bool> connectToServer(String serverAddress, int serverPort);

  /// Disconnect from current server
  Future<void> disconnectFromServer();

  /// Perform client-side sync with connected server
  Future<void> performClientSync();

  /// Start heartbeat to maintain connection
  void _startHeartbeat();

  /// Handle server messages and sync responses
  Future<void> _handleServerMessage(dynamic message);
}
```

### 2. Desktop Server Service Implementation

**Location**: `src/lib/infrastructure/desktop/features/sync/desktop_server_sync_service.dart`

Mirror the mobile server functionality for desktop platforms:

```dart
class DesktopServerSyncService extends SyncService {
  HttpServer? _server;
  List<WebSocket> _activeConnections = [];
  Timer? _serverKeepAlive;

  /// Start as WebSocket server on desktop
  Future<bool> startAsServer();

  /// Stop server and close all connections
  Future<void> stopServer();

  /// Handle incoming WebSocket connections
  void _handleServerConnections();

  /// Process WebSocket messages from clients
  Future<void> _handleWebSocketMessage(String message, WebSocket socket);
}
```

Note: `DesktopServerSyncService` extends `SyncService` directly to avoid circular dependencies. The main `DesktopSyncService` acts as a coordinator that creates and manages instances of both `DesktopServerSyncService` and `DesktopClientSyncService`.

### 3. Enhanced Desktop Sync Service

**Location**: Update `src/lib/infrastructure/desktop/features/sync/desktop_sync_service.dart`

```dart
enum DesktopSyncMode { server, client, disabled }

class DesktopSyncService extends SyncService {
  DesktopSyncMode _currentMode = DesktopSyncMode.server;
  DesktopServerSyncService? _serverService;
  DesktopClientSyncService? _clientService;

  /// Switch to server mode (current behavior)
  Future<void> switchToServerMode();

  /// Switch to client mode with server connection
  Future<void> switchToClientMode(String serverAddress, int serverPort);

  /// Get current sync mode
  DesktopSyncMode get currentMode => _currentMode;

  /// Check if connected as client
  bool get isConnectedAsClient;
}
```

Note: `DesktopSyncService` acts as the main coordinator for sync operations, managing instances of `DesktopServerSyncService` and `DesktopClientSyncService` without inheritance cycles.

### 4. Sync Settings and Persistence

**Location**: `src/lib/core/domain/features/sync/models/sync_settings.dart`

```dart
class DesktopSyncSettings {
  final DesktopSyncMode preferredMode;
  final String? lastServerAddress;
  final int? lastServerPort;
  final bool autoReconnectToServer;
  final Duration clientHeartbeatInterval;
  final bool rememberServerConnection;

  // Settings persistence in local storage
  // User preference for sync mode
  // Auto-reconnection configuration
}
```

### 5. Connection String Support

**Location**: `src/lib/presentation/ui/features/sync/models/sync_connection_string.dart`

```dart
class SyncConnectionString {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final int port;
  final String? accessToken;

  /// Parse connection string: whph://192.168.1.100:44040?name=Desktop-Server&id=uuid
  static SyncConnectionString? fromString(String connectionString);

  /// Generate connection string for sharing
  String toConnectionString();

  /// Generate QR code data
  String toQRCodeData();
}
```

### 6. UI Components

#### A. Sync Mode Selection

**Location**: `src/lib/presentation/ui/features/sync/components/desktop_sync_mode_selector.dart`

```dart
class DesktopSyncModeSelector extends StatefulWidget {
  // Radio buttons for Server/Client mode selection
  // Mode persistence and state management
  // Connection status display for current mode
  // Settings integration
}
```

#### B. Server Connection UI

**Location**: `src/lib/presentation/ui/features/sync/components/server_connection_dialog.dart`

```dart
class ServerConnectionDialog extends StatefulWidget {
  // Manual server address/port input
  // Connection string input and parsing
  // QR code scanning for server info
  // Connection testing and validation
  // Connection status indicators
  // Auto-fill from discovered devices
}
```

#### C. Enhanced Device Discovery

Update `src/lib/presentation/ui/features/sync/pages/add_sync_device_page.dart`:

```dart
// Display device capabilities (server, client, both)
// Show sync mode compatibility
// Connection direction indicators
// Enhanced device info display
```

### 7. Protocol Enhancements

#### A. Device Handshake Extension

Update `DeviceHandshakeService` to exchange capability information:

```json
{
  "type": "device_info_response",
  "data": {
    "success": true,
    "deviceId": "uuid",
    "deviceName": "Desktop PC",
    "appName": "WHPH",
    "platform": "windows",
    "capabilities": {
      "canActAsServer": true,
      "canActAsClient": true,
      "supportedModes": ["server", "client"]
    },
    "serverInfo": {
      "isServerActive": true,
      "serverPort": 44040,
      "activeConnections": 2
    }
  }
}
```

#### B. Connection Management Protocol

```json
{
  "type": "client_connect",
  "data": {
    "clientId": "uuid",
    "clientName": "Laptop",
    "requestedServices": ["sync"],
    "clientCapabilities": ["paginated_sync"]
  }
}

{
  "type": "client_connected",
  "data": {
    "success": true,
    "serverId": "uuid",
    "serverName": "Desktop",
    "syncInterval": 1800,
    "supportedOperations": ["paginated_sync"]
  }
}
```

### 8. Desktop Server Capabilities

Implement full server functionality on desktop platforms:

- WebSocket server on port 44040 (same as mobile)
- Handle `device_info`, `test`, and `paginated_sync` messages
- Support multiple concurrent client connections
- Connection keep-alive and heartbeat management
- Proper error handling and client disconnection

## Implementation Plan

### Phase 1: Core Infrastructure (Week 1-2)

1. Create `DesktopClientSyncService` with WebSocket client functionality
2. Implement basic server connection and disconnection
3. Add client-side sync protocol handling
4. Create sync mode enumeration and settings

### Phase 2: Desktop Server Service (Week 2-3)

1. Implement `DesktopServerSyncService` mirroring mobile server functionality
2. Port WebSocket server handling to desktop platforms
3. Add server-side connection management
4. Implement message routing and sync operations

### Phase 3: Enhanced Sync Management (Week 3-4)

1. Update `DesktopSyncService` with mode switching capabilities
2. Integrate server and client services
3. Add connection persistence and auto-reconnection
4. Implement heartbeat and connection health monitoring

### Phase 4: UI Components (Week 4-5)

1. Create desktop sync mode selector UI
2. Implement server connection dialog with manual input
3. Add connection string parsing and generation
4. Update device discovery UI for desktop capabilities

### Phase 5: Integration & Testing (Week 5-6)

1. Integrate all components with existing sync infrastructure
2. Test desktop-to-desktop sync scenarios
3. Test mixed platform sync (desktop client to mobile server)
4. Performance optimization and error handling

## Protocol Changes

### Enhanced QR Code Format

Include server capabilities in QR code data:

```json
{
  "deviceId": "uuid",
  "deviceName": "Desktop Server",
  "ipAddress": "192.168.1.100",
  "port": 44040,
  "capabilities": ["server", "client"],
  "serverActive": true,
  "accessToken": "optional-security-token"
}
```

### Connection String Format

Support shareable connection strings as alternative to QR codes:

```text
whph://192.168.1.100:44040?name=Desktop-Server&id=uuid&token=access-token
```

## Platform Considerations

### Windows Desktop

- Native TCP socket implementation for server functionality
- Windows firewall configuration guidance
- System tray integration for connection status

### Linux Desktop

- Cross-platform socket implementation
- Network interface handling
- Desktop environment integration

### Cross-Platform

- Consistent WebSocket implementation across desktop platforms
- Shared protocol handling between mobile and desktop servers
- Platform-agnostic sync service abstraction

## Security Considerations

- **Local Network Only**: Restrict connections to private IP ranges
- **Connection Validation**: Verify device identity during handshake
- **Access Control**: Optional token-based connection security
- **Connection Limits**: Prevent resource exhaustion with connection limits
- **Timeout Protection**: Proper timeouts for all network operations

## Testing Strategy

### Unit Tests

- Desktop client connection management
- Server service WebSocket handling
- Sync mode switching functionality
- Connection string parsing and validation
- Settings persistence and retrieval

### Integration Tests

- Desktop-to-desktop sync scenarios
- Mixed platform connections (desktop client to mobile server)
- Connection failure and recovery scenarios
- Mode switching during active connections

### End-to-End Tests

- Complete sync workflows in all modes
- QR code and connection string workflows
- Settings persistence across application restarts
- Multi-device sync topologies with desktop clients

## Alternatives Considered

### 1. Server-Only Enhancement

**Approach**: Improve desktop server discovery without client capability  
**Rejected**: Doesn't address core use case of desktop-as-client

### 2. Hybrid Mode Only

**Approach**: Desktop always acts as both server and client simultaneously  
**Rejected**: Resource intensive and complex connection management

### 3. Cloud Relay Service

**Approach**: Use cloud service for desktop-to-desktop connections  
**Rejected**: Contradicts privacy-focused P2P design, introduces dependencies

### 4. Separate Desktop Client Application

**Approach**: Create separate lightweight client application  
**Rejected**: Fragments user experience, increases maintenance burden

## Success Criteria

- **Functionality**: Desktop users can successfully connect as clients to other WHPH instances
- **Performance**: Connection establishment under 10 seconds
- **Reliability**: >95% sync success rate for stable network connections
- **Usability**: Intuitive mode switching with minimal configuration
- **Compatibility**: No regression in existing server-only functionality
- **Coverage**: Works across Windows and Linux desktop platforms

## Dependencies

- Existing sync infrastructure and protocol
- WebSocket implementation (`web_socket_channel` package)
- Network discovery services (`NetworkInterfaceService`)
- Device handshake protocol (`DeviceHandshakeService`)
- Sync settings and persistence

## Migration Strategy

1. **Backward Compatibility**: New client capability doesn't affect existing server behavior
2. **Opt-in Feature**: Desktop client mode is optional with server as default
3. **Settings Migration**: Preserve existing sync settings and device pairings
4. **Gradual Rollout**: Feature flag for desktop client functionality

## Future Enhancements

1. **Hybrid Mode**: Desktop acts as both server and client simultaneously
2. **Connection Mesh**: Multiple desktop clients connecting to multiple servers
3. **Load Balancing**: Intelligent server selection based on load and performance
4. **Enhanced Security**: Certificate-based authentication for client connections
5. **Mobile Client Mode**: Enable mobile devices as dedicated clients

## References

- [Issue #36](https://github.com/ahmet-cetinkaya/whph/issues/36): Original feature request
- [RFC 006](./006_implement-peer-to-peer-synchronization.md): P2P sync implementation
- [RFC 011](./011_enhance-network-discovery-multi-interface.md): Network discovery enhancements
- Existing sync services: `AndroidServerSyncService`, `DesktopSyncService`
- WebSocket protocol documentation: [RFC 6455](https://tools.ietf.org/html/rfc6455)
