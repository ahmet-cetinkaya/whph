import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/presentation/ui/shared/services/mcp_runtime_service.dart';

class McpSettingsController extends ChangeNotifier {
  final IMcpAccessService _accessService;
  final McpRuntimeService _runtimeService;
  late final StreamSubscription<McpRuntimeState> _runtimeSubscription;

  McpAccessState? _accessState;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _lastError;

  McpSettingsController({
    required IMcpAccessService accessService,
    required McpRuntimeService runtimeService,
  })  : _accessService = accessService,
        _runtimeService = runtimeService {
    _runtimeSubscription = _runtimeService.changes.listen((runtimeState) {
      _lastError = runtimeState.lastError;
      notifyListeners();
    });
  }

  McpAccessState? get accessState => _accessState;
  McpRuntimeState get runtimeState => _runtimeService.state;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get lastError => _lastError ?? runtimeState.lastError;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _accessState = await _accessService.readState();
      _lastError = null;
    } catch (_) {
      _lastError = 'Secure MCP settings storage is unavailable.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool isEnabled) async {
    final preferences = _requirePreferences();
    await _updatePreferences(McpServerPreferences(
      isEnabled: isEnabled,
      port: preferences.port,
      transferDirectory: preferences.transferDirectory,
    ));
  }

  Future<void> setPort(int port) async {
    if (port < 1 || port > 65535) {
      _lastError = 'Port must be between 1 and 65535.';
      notifyListeners();
      return;
    }
    final preferences = _requirePreferences();
    await _updatePreferences(McpServerPreferences(
      isEnabled: preferences.isEnabled,
      port: port,
      transferDirectory: preferences.transferDirectory,
    ));
  }

  Future<void> setTransferDirectory(String directory) async {
    final preferences = _requirePreferences();
    await _updatePreferences(McpServerPreferences(
      isEnabled: preferences.isEnabled,
      port: preferences.port,
      transferDirectory: directory,
    ));
  }

  Future<String?> createGrant(String clientName, Set<String> scopes) =>
      _runGrantOperation(() => _accessService.createGrant(
            clientName: clientName,
            scopes: scopes,
          ));

  Future<String?> rotateGrant(String grantId) => _runGrantOperation(() => _accessService.rotateGrant(grantId));

  Future<void> revokeGrant(String grantId) => _runOperation(() async {
        await _accessService.revokeGrant(grantId);
        await _reloadAccessState();
      });

  Future<String?> _runGrantOperation(
    Future<McpIssuedGrant> Function() operation,
  ) async {
    String? token;
    await _runOperation(() async {
      token = (await operation()).token;
      await _reloadAccessState();
    });
    return token;
  }

  Future<void> _updatePreferences(McpServerPreferences preferences) => _runOperation(() async {
        await _runtimeService.updatePreferences(preferences);
        await _reloadAccessState();
      });

  Future<void> _runOperation(Future<void> Function() operation) async {
    if (_isUpdating) return;
    _isUpdating = true;
    _lastError = null;
    notifyListeners();
    try {
      await operation();
    } catch (_) {
      _lastError = _runtimeService.state.lastError ?? 'The MCP setting could not be updated.';
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAccessState() async {
    _accessState = await _accessService.readState();
  }

  McpServerPreferences _requirePreferences() {
    final preferences = _accessState?.preferences;
    if (preferences == null) throw StateError('MCP settings are not loaded');
    return preferences;
  }

  @override
  void dispose() {
    unawaited(_runtimeSubscription.cancel());
    super.dispose();
  }
}
