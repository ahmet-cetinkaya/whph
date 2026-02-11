import 'package:domain/features/sync/models/desktop_sync_mode.dart';

/// Settings for desktop sync functionality
class DesktopSyncSettings {
  /// The preferred sync mode for this desktop instance
  final DesktopSyncMode preferredMode;

  /// Last successful server connection address (for client mode)
  final String? lastServerAddress;

  /// Last successful server connection port (for client mode)
  final int? lastServerPort;

  /// Whether to automatically reconnect to the last server on startup
  final bool autoReconnectToServer;

  /// Interval for client heartbeat messages (in seconds)
  final Duration clientHeartbeatInterval;

  /// Whether to remember server connection details
  final bool rememberServerConnection;

  /// Maximum number of retry attempts for client connections
  final int maxRetryAttempts;

  /// Delay between retry attempts (in seconds)
  final Duration retryDelay;

  /// Whether to start server automatically on application startup
  final bool autoStartServer;

  /// Custom server port (if different from default 44040)
  final int? customServerPort;

  const DesktopSyncSettings({
    this.preferredMode = DesktopSyncMode.server,
    this.lastServerAddress,
    this.lastServerPort,
    this.autoReconnectToServer = true,
    this.clientHeartbeatInterval = const Duration(minutes: 2),
    this.rememberServerConnection = true,
    this.maxRetryAttempts = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.autoStartServer = true,
    this.customServerPort,
  });

  /// Create settings with updated values
  DesktopSyncSettings copyWith({
    DesktopSyncMode? preferredMode,
    String? lastServerAddress,
    int? lastServerPort,
    bool? autoReconnectToServer,
    Duration? clientHeartbeatInterval,
    bool? rememberServerConnection,
    int? maxRetryAttempts,
    Duration? retryDelay,
    bool? autoStartServer,
    int? customServerPort,
  }) {
    return DesktopSyncSettings(
      preferredMode: preferredMode ?? this.preferredMode,
      lastServerAddress: lastServerAddress ?? this.lastServerAddress,
      lastServerPort: lastServerPort ?? this.lastServerPort,
      autoReconnectToServer: autoReconnectToServer ?? this.autoReconnectToServer,
      clientHeartbeatInterval: clientHeartbeatInterval ?? this.clientHeartbeatInterval,
      rememberServerConnection: rememberServerConnection ?? this.rememberServerConnection,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      autoStartServer: autoStartServer ?? this.autoStartServer,
      customServerPort: customServerPort ?? this.customServerPort,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'preferredMode': preferredMode.name,
      'lastServerAddress': lastServerAddress,
      'lastServerPort': lastServerPort,
      'autoReconnectToServer': autoReconnectToServer,
      'clientHeartbeatIntervalMinutes': clientHeartbeatInterval.inMinutes,
      'rememberServerConnection': rememberServerConnection,
      'maxRetryAttempts': maxRetryAttempts,
      'retryDelaySeconds': retryDelay.inSeconds,
      'autoStartServer': autoStartServer,
      'customServerPort': customServerPort,
    };
  }

  /// Create settings from JSON
  factory DesktopSyncSettings.fromJson(Map<String, dynamic> json) {
    return DesktopSyncSettings(
      preferredMode: DesktopSyncMode.values.firstWhere(
        (mode) => mode.name == json['preferredMode'],
        orElse: () => DesktopSyncMode.server,
      ),
      lastServerAddress: json['lastServerAddress'] as String?,
      lastServerPort: json['lastServerPort'] as int?,
      autoReconnectToServer: json['autoReconnectToServer'] as bool? ?? true,
      clientHeartbeatInterval: Duration(
        minutes: json['clientHeartbeatIntervalMinutes'] as int? ?? 2,
      ),
      rememberServerConnection: json['rememberServerConnection'] as bool? ?? true,
      maxRetryAttempts: json['maxRetryAttempts'] as int? ?? 3,
      retryDelay: Duration(
        seconds: json['retryDelaySeconds'] as int? ?? 5,
      ),
      autoStartServer: json['autoStartServer'] as bool? ?? true,
      customServerPort: json['customServerPort'] as int?,
    );
  }

  /// Get the effective server port (custom or default)
  int get effectiveServerPort => customServerPort ?? 44040;

  /// Check if client mode has valid connection settings
  bool get hasValidClientSettings =>
      lastServerAddress != null && lastServerAddress!.isNotEmpty && lastServerPort != null;

  @override
  String toString() {
    return 'DesktopSyncSettings('
        'preferredMode: $preferredMode, '
        'lastServerAddress: $lastServerAddress, '
        'lastServerPort: $lastServerPort, '
        'autoReconnectToServer: $autoReconnectToServer)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopSyncSettings &&
          runtimeType == other.runtimeType &&
          preferredMode == other.preferredMode &&
          lastServerAddress == other.lastServerAddress &&
          lastServerPort == other.lastServerPort &&
          autoReconnectToServer == other.autoReconnectToServer &&
          clientHeartbeatInterval == other.clientHeartbeatInterval &&
          rememberServerConnection == other.rememberServerConnection &&
          maxRetryAttempts == other.maxRetryAttempts &&
          retryDelay == other.retryDelay &&
          autoStartServer == other.autoStartServer &&
          customServerPort == other.customServerPort;

  @override
  int get hashCode => Object.hash(
        preferredMode,
        lastServerAddress,
        lastServerPort,
        autoReconnectToServer,
        clientHeartbeatInterval,
        rememberServerConnection,
        maxRetryAttempts,
        retryDelay,
        autoStartServer,
        customServerPort,
      );
}
