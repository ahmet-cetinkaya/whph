import 'dart:async';
import 'dart:io';
import 'package:dart_json_mapper/dart_json_mapper.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_concurrent_connection_service.dart';
import 'package:whph/core/application/shared/models/websocket_request.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/core/shared/utils/unawaited.dart';

/// Service for establishing concurrent connections to multiple IP addresses
/// Implements intelligent connection logic with timeout handling and cancellation
class ConcurrentConnectionService implements IConcurrentConnectionService {
  static const Duration _defaultTimeout = Duration(seconds: 5);
  static const Duration _testTimeout = Duration(seconds: 3);

  @override
  Future<WebSocket?> connectToAnyAddress(
    List<String> ipAddresses,
    int port, {
    Duration timeout = _defaultTimeout,
  }) async {
    if (ipAddresses.isEmpty) {
      Logger.debug('No IP addresses provided for connection');
      return null;
    }

    Logger.debug('Attempting concurrent connections to ${ipAddresses.length} addresses: ${ipAddresses.join(', ')}');
    
    final Completer<WebSocket?> completer = Completer();
    bool connectionSucceeded = false;
    int failedAttempts = 0;

    // Create connection attempts for each IP address
    for (final ipAddress in ipAddresses) {
      unawaited(_attemptConnection(
        ipAddress,
        port,
        timeout,
        (socket) {
          if (!connectionSucceeded) {
            connectionSucceeded = true;
            Logger.debug('✅ First successful connection established to $ipAddress:$port');
            if (!completer.isCompleted) {
              completer.complete(socket);
            }
          } else {
            // Close extra successful connections
            socket.close();
          }
        },
        (error) {
          Logger.debug('❌ Connection failed to $ipAddress:$port: $error');
          if (connectionSucceeded) return;

          failedAttempts++;
          if (failedAttempts == ipAddresses.length && !completer.isCompleted) {
            Logger.debug('All connection attempts failed');
            completer.complete(null);
          }
        },
      ));
    }

    // Set up timeout for the entire operation
    Timer(timeout, () {
      if (!completer.isCompleted) {
        Logger.debug('⏰ Connection timeout after ${timeout.inSeconds}s, no successful connections');
        completer.complete(null);
      }
    });

    // Wait for first successful connection or timeout
    final result = await completer.future;
    
    return result;
  }

  @override
  Future<List<String>> testMultipleAddresses(
    List<String> ipAddresses,
    int port, {
    Duration timeout = _testTimeout,
  }) async {
    if (ipAddresses.isEmpty) {
      return [];
    }

    Logger.debug('Testing connectivity to ${ipAddresses.length} addresses');
    
    final List<Future<ConnectionAttemptResult>> testFutures = ipAddresses
        .map((ip) => _testSingleAddress(ip, port, timeout))
        .toList();

    try {
      final results = await Future.wait(testFutures);
      final successful = results
          .where((result) => result.successful)
          .map((result) => result.ipAddress)
          .toList();

      Logger.debug('Connectivity test completed: ${successful.length}/${ipAddresses.length} addresses reachable');
      return successful;
    } catch (e) {
      Logger.error('Error during connectivity testing: $e');
      return [];
    }
  }

  @override
  Future<bool> testWebSocketConnection(String ipAddress, int port, {Duration? timeout}) async {
    final result = await _testSingleAddress(ipAddress, port, timeout ?? _testTimeout);
    return result.successful;
  }

  /// Attempt connection to a single address with callbacks
  Future<void> _attemptConnection(
    String ipAddress,
    int port,
    Duration timeout,
    Function(WebSocket) onSuccess,
    Function(String) onError,
  ) async {
    try {
      final stopwatch = Stopwatch()..start();
      final wsUrl = 'ws://$ipAddress:$port';
      
      Logger.debug('🔍 Attempting WebSocket connection to $wsUrl');
      
      final socket = await WebSocket.connect(wsUrl).timeout(timeout);
      stopwatch.stop();
      
      // Test the connection with a simple message
      final isValid = await _validateConnection(socket);
      
      if (isValid) {
        Logger.debug('✅ Connection validated to $ipAddress:$port (${stopwatch.elapsedMilliseconds}ms)');
        onSuccess(socket);
      } else {
        Logger.debug('❌ Connection validation failed to $ipAddress:$port');
        socket.close();
        onError('Connection validation failed');
      }
    } catch (e) {
      Logger.debug('❌ Connection attempt failed to $ipAddress:$port: $e');
      onError(e.toString());
    }
  }

  /// Test connectivity to a single address and return result
  Future<ConnectionAttemptResult> _testSingleAddress(String ipAddress, int port, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // First try simple socket connection (faster than WebSocket)
      final socket = await Socket.connect(ipAddress, port, timeout: timeout);
      await socket.close();
      stopwatch.stop();
      
      Logger.debug('✅ Socket test passed for $ipAddress:$port (${stopwatch.elapsedMilliseconds}ms)');
      return ConnectionAttemptResult(
        ipAddress: ipAddress,
        successful: true,
        responseTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      Logger.debug('❌ Socket test failed for $ipAddress:$port: $e (${stopwatch.elapsedMilliseconds}ms)');
      return ConnectionAttemptResult(
        ipAddress: ipAddress,
        successful: false,
        errorMessage: e.toString(),
        responseTime: stopwatch.elapsed,
      );
    }
  }

  /// Validate WebSocket connection by sending a test message
  Future<bool> _validateConnection(WebSocket socket) async {
    try {
      // Send a connection test message and wait for specific response
      final testMessage = WebSocketMessage(
        type: 'connection_test',
        data: {'timestamp': DateTime.now().toIso8601String()},
      );
      
      socket.add(JsonMapper.serialize(testMessage));
      
      // Wait for the specific connection_test_response or timeout after 2 seconds
      final responseData = await socket.timeout(
        const Duration(seconds: 2),
        onTimeout: (_) => throw TimeoutException('Validation timeout'),
      ).first;
      
      // Parse the response and check if it's a valid connection_test_response
      final response = JsonMapper.deserialize<WebSocketMessage>(responseData);
      final isValid = response?.type == 'connection_test_response' && 
                     response?.data?['success'] == true;
      
      if (!isValid) {
        Logger.debug('Invalid connection test response: ${response?.type}');
      }
      
      return isValid;
    } catch (e) {
      Logger.debug('Connection validation failed: $e');
      return false;
    }
  }
}