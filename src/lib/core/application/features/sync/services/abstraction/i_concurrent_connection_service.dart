import 'dart:io';

/// Service interface for establishing concurrent connections to multiple IP addresses
abstract class IConcurrentConnectionService {
  /// Attempt to connect to any of the provided IP addresses concurrently
  /// Returns the first successful WebSocket connection, cancels others
  Future<WebSocket?> connectToAnyAddress(
    List<String> ipAddresses,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  });

  /// Test connectivity to multiple addresses and return successful ones
  /// Useful for pre-filtering viable addresses before attempting full connections
  Future<List<String>> testMultipleAddresses(
    List<String> ipAddresses,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  });

  /// Test WebSocket connectivity to a specific address
  Future<bool> testWebSocketConnection(String ipAddress, int port, {Duration? timeout});
}

/// Result of a connection attempt
class ConnectionAttemptResult {
  final String ipAddress;
  final bool successful;
  final String? errorMessage;
  final Duration responseTime;

  const ConnectionAttemptResult({
    required this.ipAddress,
    required this.successful,
    this.errorMessage,
    required this.responseTime,
  });

  @override
  String toString() => 'ConnectionAttemptResult(ip: $ipAddress, success: $successful, time: ${responseTime.inMilliseconds}ms)';
}