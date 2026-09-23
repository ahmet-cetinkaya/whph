import 'dart:async';

import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

class McpRuntimeState {
  final McpServerPreferences? preferences;
  final bool isRunning;
  final Uri? endpoint;
  final String? lastError;

  const McpRuntimeState({
    required this.preferences,
    required this.isRunning,
    required this.endpoint,
    required this.lastError,
  });
}

class McpRuntimeService {
  final IMcpAccessService _accessService;
  final IMcpServerService _serverService;
  final bool _isAndroid;
  final StreamController<McpRuntimeState> _changes = StreamController<McpRuntimeState>.broadcast();

  Future<void> _operationQueue = Future.value();
  bool _isForeground = false;
  McpRuntimeState _state = const McpRuntimeState(
    preferences: null,
    isRunning: false,
    endpoint: null,
    lastError: null,
  );

  McpRuntimeService({
    required IMcpAccessService accessService,
    required IMcpServerService serverService,
    required bool isAndroid,
  })  : _accessService = accessService,
        _serverService = serverService,
        _isAndroid = isAndroid;

  McpRuntimeState get state => _state;
  Stream<McpRuntimeState> get changes => _changes.stream;

  Future<void> initialize() => _enqueue(_reconcileSafely);

  Future<void> enterForeground() => _enqueue(() async {
        _isForeground = true;
        await _reconcileSafely();
      });

  Future<void> leaveForeground() => _enqueue(() async {
        _isForeground = false;
        if (_isAndroid) await _stop();
      });

  Future<void> updatePreferences(McpServerPreferences preferences) => _enqueue(() async {
        await _accessService.setPreferences(preferences);
        await _reconcileSafely(preferences);
      });

  Future<void> reload() => _enqueue(_reconcileSafely);

  Future<void> shutdown() => _enqueue(_stop);

  Future<void> dispose() async {
    await shutdown();
    await _changes.close();
  }

  Future<void> _reconcileSafely([McpServerPreferences? requestedPreferences]) async {
    try {
      await _reconcile();
    } catch (error, stackTrace) {
      Logger.error(
        'MCP listener could not be initialized',
        component: 'McpRuntimeService',
        stackTrace: stackTrace,
      );
      await _stop();
      _replaceState(
        McpRuntimeState(
          preferences: requestedPreferences ?? _state.preferences,
          isRunning: false,
          endpoint: null,
          lastError: _safeError(error),
        ),
      );
    }
  }

  Future<void> _reconcile() async {
    final accessState = await _accessService.readState();
    final preferences = accessState.preferences;
    final shouldRun = preferences.isEnabled && (!_isAndroid || _isForeground);

    if (!shouldRun) {
      await _stop();
      _replaceState(McpRuntimeState(
        preferences: preferences,
        isRunning: false,
        endpoint: null,
        lastError: null,
      ));
      return;
    }

    if (_serverService.isRunning && _serverService.boundPort != preferences.port) {
      await _serverService.stop();
    }
    if (!_serverService.isRunning) {
      await _serverService.start(port: preferences.port);
    }
    _replaceState(McpRuntimeState(
      preferences: preferences,
      isRunning: true,
      endpoint: _serverService.endpoint,
      lastError: null,
    ));
  }

  Future<void> _stop() async {
    if (_serverService.isRunning) await _serverService.stop();
    _replaceState(McpRuntimeState(
      preferences: _state.preferences,
      isRunning: false,
      endpoint: null,
      lastError: _state.lastError,
    ));
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _operationQueue.then((_) => operation());
    _operationQueue = result.catchError((_) {});
    return result;
  }

  void _replaceState(McpRuntimeState state) {
    _state = state;
    if (!_changes.isClosed) _changes.add(state);
  }

  String _safeError(Object error) => switch (error) {
        McpAccessStorageException() => 'Secure MCP settings storage is unavailable.',
        _ => 'The local MCP listener could not be started.',
      };
}
