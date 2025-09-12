/// Desktop sync operation modes
enum DesktopSyncMode {
  /// Desktop acts as sync server (default behavior)
  server,
  
  /// Desktop acts as sync client connecting to other servers  
  client,
  
  /// Sync is disabled
  disabled;

  /// Display name for the sync mode
  String get displayName {
    switch (this) {
      case DesktopSyncMode.server:
        return 'Server Mode';
      case DesktopSyncMode.client:
        return 'Client Mode';
      case DesktopSyncMode.disabled:
        return 'Disabled';
    }
  }

  /// Description of what the sync mode does
  String get description {
    switch (this) {
      case DesktopSyncMode.server:
        return 'This device acts as a server that other devices can connect to for synchronization';
      case DesktopSyncMode.client:
        return 'This device connects to another WHPH device acting as a server';
      case DesktopSyncMode.disabled:
        return 'Sync functionality is disabled';
    }
  }

  /// Whether this mode allows incoming connections
  bool get acceptsIncomingConnections {
    switch (this) {
      case DesktopSyncMode.server:
        return true;
      case DesktopSyncMode.client:
      case DesktopSyncMode.disabled:
        return false;
    }
  }

  /// Whether this mode initiates outgoing connections
  bool get initiatesOutgoingConnections {
    switch (this) {
      case DesktopSyncMode.client:
        return true;
      case DesktopSyncMode.server:
      case DesktopSyncMode.disabled:
        return false;
    }
  }
}