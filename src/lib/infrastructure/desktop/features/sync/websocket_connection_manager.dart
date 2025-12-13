import 'dart:async';
import 'dart:io';
import 'package:whph/core/domain/shared/utils/logger.dart';

const int maxConcurrentConnections = 10;
const int maxConnectionsPerIP = 5;
const int connectionTimeoutSeconds = 300;
const int connectionRecycleIdleSeconds = 5;

/// Manages WebSocket connections with rate limiting and lifecycle tracking.
///
/// Handles:
/// - Connection tracking (IPs, times, activity)
/// - Rate limiting per IP and total connections
/// - Idle connection recycling
/// - Clean shutdown and validation
class WebSocketConnectionManager {
  final List<WebSocket> _activeConnections = [];
  final Map<WebSocket, String> _connectionIPs = {};
  final Map<WebSocket, DateTime> _connectionTimes = {};
  final Map<WebSocket, DateTime> _connectionLastActivity = {};
  final Map<String, int> _ipConnectionCounts = {};

  List<WebSocket> get activeConnections => List.unmodifiable(_activeConnections);
  int get connectionCount => _activeConnections.length;

  /// Validates and cleans up any stale connection state from previous instances
  Future<void> validateAndCleanConnectionState() async {
    Logger.debug('Validating and cleaning up connection state...');

    try {
      if (_hasStaleData()) {
        Logger.warning('Found stale connection data from previous instance');
        await forceCleanupAllConnections();
        Logger.info('Forced cleanup of stale connection data completed');
      } else {
        Logger.debug('No stale connection data found');
      }
    } catch (e) {
      Logger.error('Error during connection state validation: $e');
      await forceCleanupAllConnections();
    }
  }

  bool _hasStaleData() =>
      _activeConnections.isNotEmpty ||
      _connectionIPs.isNotEmpty ||
      _connectionTimes.isNotEmpty ||
      _connectionLastActivity.isNotEmpty ||
      _ipConnectionCounts.isNotEmpty;

  /// Register a new connection
  void registerConnection(WebSocket socket, String clientIP) {
    final now = DateTime.now();
    _activeConnections.add(socket);
    _connectionIPs[socket] = clientIP;
    _connectionTimes[socket] = now;
    _connectionLastActivity[socket] = now;
    _ipConnectionCounts[clientIP] = (_ipConnectionCounts[clientIP] ?? 0) + 1;
  }

  /// Update last activity time for a connection
  void updateActivity(WebSocket socket) {
    _connectionLastActivity[socket] = DateTime.now();
  }

  /// Get client IP for a socket
  String? getClientIP(WebSocket socket) => _connectionIPs[socket];

  /// Check if a new connection can be accepted based on limits
  bool canAcceptNewConnection(String clientIP) {
    if (clientIP.isEmpty) {
      Logger.warning('Invalid empty client IP in connection check');
      return false;
    }

    if (_activeConnections.length >= maxConcurrentConnections) {
      Logger.debug('Connection pool at capacity: ${_activeConnections.length}/$maxConcurrentConnections');
      return false;
    }

    final ipConnections = _ipConnectionCounts[clientIP] ?? 0;
    if (ipConnections >= maxConnectionsPerIP) {
      Logger.debug('IP $clientIP at connection limit: $ipConnections/$maxConnectionsPerIP');
      return false;
    }

    return true;
  }

  /// Check if a connection has exceeded the timeout
  bool isConnectionExpired(WebSocket socket) {
    final connectionTime = _connectionTimes[socket];
    if (connectionTime == null) return false;
    return DateTime.now().difference(connectionTime).inSeconds > connectionTimeoutSeconds;
  }

  /// Cleanup expired and closed connections
  void cleanupExpiredConnections() {
    final toCleanup =
        _activeConnections.where((ws) => ws.readyState == WebSocket.closed || isConnectionExpired(ws)).toList();

    for (final ws in toCleanup) {
      if (isConnectionExpired(ws)) {
        Logger.debug('Closing expired connection');
        ws.close();
      }
      cleanupConnection(ws);
    }
  }

  /// Recycle idle connections to prevent pool exhaustion
  void recycleIdleConnections() {
    if (_activeConnections.isEmpty) return;

    final now = DateTime.now();
    final toRecycle = <WebSocket>[];

    for (final socket in List<WebSocket>.from(_activeConnections)) {
      try {
        if (socket.readyState == WebSocket.closed || socket.readyState == WebSocket.closing) continue;

        final lastActivity = _connectionLastActivity[socket];
        if (lastActivity == null) {
          Logger.debug('Connection missing activity timestamp, marking for recycling');
          toRecycle.add(socket);
          continue;
        }

        if (now.difference(lastActivity).inSeconds > connectionRecycleIdleSeconds) {
          Logger.debug('Recycling idle connection');
          toRecycle.add(socket);
        }
      } catch (e) {
        Logger.debug('Error checking connection for recycling: $e');
      }
    }

    for (final socket in toRecycle) {
      try {
        socket.close(1000, 'Connection recycled due to inactivity');
        cleanupConnection(socket);
      } catch (e) {
        Logger.debug('Error closing connection during recycling: $e');
        cleanupConnection(socket);
      }
    }
  }

  /// Clean up connection tracking data
  void cleanupConnection(WebSocket socket) {
    try {
      final clientIP = _connectionIPs[socket];
      _activeConnections.remove(socket);
      _connectionIPs.remove(socket);
      _connectionTimes.remove(socket);
      _connectionLastActivity.remove(socket);

      if (clientIP != null && clientIP.isNotEmpty) {
        final currentCount = _ipConnectionCounts[clientIP] ?? 0;
        if (currentCount > 1) {
          _ipConnectionCounts[clientIP] = currentCount - 1;
        } else if (currentCount == 1) {
          _ipConnectionCounts.remove(clientIP);
        }
      }
    } catch (e) {
      Logger.warning('Error during connection cleanup: $e');
    }
  }

  /// Forces cleanup of all connections
  Future<void> forceCleanupAllConnections() async {
    try {
      final closeFutures = <Future>[];
      for (final socket in List<WebSocket>.from(_activeConnections)) {
        try {
          if (socket.readyState != WebSocket.closed && socket.readyState != WebSocket.closing) {
            closeFutures.add(socket.close(1001, 'Server cleaning up'));
          }
        } catch (e) {
          Logger.debug('Error closing connection: $e');
        }
      }

      if (closeFutures.isNotEmpty) {
        try {
          await Future.wait(closeFutures).timeout(const Duration(seconds: 5), onTimeout: () => []);
        } catch (e) {
          Logger.warning('Error during connection closure: $e');
        }
      }
    } finally {
      _activeConnections.clear();
      _connectionIPs.clear();
      _connectionTimes.clear();
      _connectionLastActivity.clear();
      _ipConnectionCounts.clear();
    }
  }

  /// Gracefully close a WebSocket connection
  Future<void> closeSocketGracefully(WebSocket socket, int code, String reason) async {
    try {
      if (socket.readyState == WebSocket.closed || socket.readyState == WebSocket.closing) {
        cleanupConnection(socket);
        return;
      }

      Logger.debug('Closing socket gracefully: $reason (code: $code)');
      await Future.delayed(const Duration(milliseconds: 100));

      await socket.close(code, reason).timeout(
            const Duration(seconds: 2),
            onTimeout: () => socket.close(),
          );

      Logger.debug('Socket closed successfully');
    } catch (e) {
      Logger.warning('Error during graceful socket close: $e');
      try {
        await socket.close();
      } catch (_) {}
    } finally {
      cleanupConnection(socket);
    }
  }

  /// Check if an IP is from a private network
  static bool isPrivateIP(String ip) {
    try {
      final address = InternetAddress(ip);

      if (address.type == InternetAddressType.IPv4) {
        final parts = ip.split('.');
        if (parts.length != 4) return false;

        final first = int.tryParse(parts[0]);
        final second = int.tryParse(parts[1]);
        if (first == null || second == null) return false;

        return (first == 10) ||
            (first == 172 && second >= 16 && second <= 31) ||
            (first == 192 && second == 168) ||
            (first == 127);
      }

      if (address.type == InternetAddressType.IPv6) {
        return ip.startsWith('fe80:') || ip == '::1' || ip.startsWith('fc') || ip.startsWith('fd');
      }
    } catch (e) {
      Logger.debug('Error parsing IP address $ip: $e');
      return false;
    }
    return false;
  }
}
