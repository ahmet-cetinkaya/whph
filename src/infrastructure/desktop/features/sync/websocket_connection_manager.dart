import 'dart:async';
import 'dart:io';
import 'package:domain/shared/utils/logger.dart';

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
    DomainLogger.debug('Validating and cleaning up connection state...');

    try {
      if (_hasStaleData()) {
        DomainLogger.warning('Found stale connection data from previous instance');
        await forceCleanupAllConnections();
        DomainLogger.info('Forced cleanup of stale connection data completed');
      } else {
        DomainLogger.debug('No stale connection data found');
      }
    } catch (e) {
      DomainLogger.error('Error during connection state validation: $e');
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
      DomainLogger.warning('Invalid empty client IP in connection check');
      return false;
    }

    if (_activeConnections.length >= maxConcurrentConnections) {
      DomainLogger.debug('Connection pool at capacity: ${_activeConnections.length}/$maxConcurrentConnections');
      return false;
    }

    final ipConnections = _ipConnectionCounts[clientIP] ?? 0;
    if (ipConnections >= maxConnectionsPerIP) {
      DomainLogger.debug('IP $clientIP at connection limit: $ipConnections/$maxConnectionsPerIP');
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
        DomainLogger.debug('Closing expired connection');
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
          DomainLogger.debug('Connection missing activity timestamp, marking for recycling');
          toRecycle.add(socket);
          continue;
        }

        if (now.difference(lastActivity).inSeconds > connectionRecycleIdleSeconds) {
          DomainLogger.debug('Recycling idle connection');
          toRecycle.add(socket);
        }
      } catch (e) {
        DomainLogger.debug('Error checking connection for recycling: $e');
      }
    }

    for (final socket in toRecycle) {
      try {
        socket.close(1000, 'Connection recycled due to inactivity');
        cleanupConnection(socket);
      } catch (e) {
        DomainLogger.debug('Error closing connection during recycling: $e');
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
      DomainLogger.warning('Error during connection cleanup: $e');
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
          DomainLogger.debug('Error closing connection: $e');
        }
      }

      if (closeFutures.isNotEmpty) {
        try {
          await Future.wait(closeFutures).timeout(const Duration(seconds: 5), onTimeout: () => []);
        } catch (e) {
          DomainLogger.warning('Error during connection closure: $e');
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

      DomainLogger.debug('Closing socket gracefully: $reason (code: $code)');
      await Future.delayed(const Duration(milliseconds: 100));

      await socket.close(code, reason).timeout(
            const Duration(seconds: 2),
            onTimeout: () => socket.close(),
          );

      DomainLogger.debug('Socket closed successfully');
    } catch (e) {
      DomainLogger.warning('Error during graceful socket close: $e');
      try {
        await socket.close();
      } catch (_) {}
    } finally {
      cleanupConnection(socket);
    }
  }
}
