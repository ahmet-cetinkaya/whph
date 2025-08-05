import 'package:whph/src/core/application/features/sync/services/v3/bidirectional_websocket_handler.dart';
import 'package:whph/src/core/application/features/sync/registry/sync_entity_registry.dart';
import 'package:whph/src/core/shared/utils/logger.dart';
import 'package:acore/acore.dart';

/// Initializes bidirectional sync system
class BidirectionalSyncInitializer {
  static BidirectionalWebSocketHandler? _handler;
  
  /// Initialize bidirectional sync system
  static Future<void> initialize(IContainer container) async {
    print('🔧 DEBUG: BidirectionalSyncInitializer.initialize() called');
    Logger.info('🔄 BidirectionalSyncInitializer: Starting bidirectional sync initialization...');
    
    final stopwatch = Stopwatch()..start();

    try {
      // Get registry (should be already initialized)
      print('🔧 DEBUG: Getting SyncEntityRegistry...');
      final registry = SyncEntityRegistry();
      print('🔧 DEBUG: Registry has ${registry.registrationCount} entities registered');
      
      if (registry.registrationCount == 0) {
        print('🔧 DEBUG: Registry is empty - no entities registered');
        Logger.warning('🔄 BidirectionalSyncInitializer: Registry is empty - no entities registered');
        return;
      }

      // Create WebSocket handler
      print('🔧 DEBUG: Creating BidirectionalWebSocketHandler...');
      _handler = BidirectionalWebSocketHandler(
        registry: registry,
        port: 44041, // Use different port to avoid conflict with existing sync system
      );
      print('🔧 DEBUG: WebSocket handler created, starting server...');

      // Start server (Desktop always acts as server)
      await _handler!.startServer();
      print('🔧 DEBUG: WebSocket server started successfully!');

      stopwatch.stop();
      Logger.info('🔄 BidirectionalSyncInitializer: Completed initialization in ${stopwatch.elapsedMilliseconds}ms');
      Logger.info(_handler!.statusSummary);

    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('🔄 BidirectionalSyncInitializer: Failed to initialize bidirectional sync: $e');
      Logger.error('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Get current handler instance
  static BidirectionalWebSocketHandler? get handler => _handler;

  /// Test the bidirectional sync system
  static Future<Map<String, dynamic>> runTest() async {
    Logger.info('🧪 BidirectionalSyncInitializer: Running bidirectional sync test...');

    try {
      final registry = SyncEntityRegistry();
      
      // Create test handler on different port
      final testHandler = BidirectionalWebSocketHandler(
        registry: registry,
        port: 44042,
      );

      final testResults = <String, dynamic>{};

      // Test server startup
      await testHandler.startServer();
      testResults['serverStarted'] = true;
      
      // Test registry
      testResults['registryStatus'] = {
        'entityCount': registry.registrationCount,
        'entityTypes': registry.entityTypes,
      };

      // Test handler status
      testResults['handlerStatus'] = {
        'isServerRunning': testHandler.isServerRunning,
        'activeConnections': testHandler.activeConnectionCount,
      };

      // Cleanup test handler
      await testHandler.stop();
      testResults['serverStopped'] = true;

      Logger.info('🧪 BidirectionalSyncInitializer: Test completed successfully');
      return {
        'success': true,
        'message': 'Bidirectional sync test passed',
        'results': testResults,
      };

    } catch (e, stackTrace) {
      Logger.error('🧪 BidirectionalSyncInitializer: Test failed: $e');
      Logger.error('StackTrace: $stackTrace');
      
      return {
        'success': false,
        'message': 'Bidirectional sync test failed',
        'error': e.toString(),
      };
    }
  }

  /// Stop bidirectional sync system
  static Future<void> stop() async {
    if (_handler != null) {
      Logger.info('🔄 BidirectionalSyncInitializer: Stopping bidirectional sync...');
      await _handler!.stop();
      _handler = null;
    }
  }

  /// Get initialization status
  static String getStatus() {
    if (_handler == null) {
      return '''
🔄 Bidirectional Sync Status: NOT INITIALIZED
  Handler: null
  Server: not running
''';
    }

    return '''
🔄 Bidirectional Sync Status: INITIALIZED
${_handler!.statusSummary}
''';
  }
}