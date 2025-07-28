enum SyncRole {
  /// Device acts as WebSocket server
  server,
  
  /// Device acts as WebSocket client
  client,
  
  /// Automatically determine role based on device characteristics
  auto,
}

extension SyncRoleExtension on SyncRole {
  String get displayName {
    switch (this) {
      case SyncRole.server:
        return 'Server (Host)';
      case SyncRole.client:
        return 'Client';
      case SyncRole.auto:
        return 'Auto';
    }
  }
  
  String get description {
    switch (this) {
      case SyncRole.server:
        return 'This device will host the sync connection and display QR code';
      case SyncRole.client:
        return 'This device will connect to another device for sync';
      case SyncRole.auto:
        return 'Role will be determined automatically when pairing devices';
    }
  }
}