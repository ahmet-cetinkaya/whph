import 'i_mcp_access_service.dart';

abstract class IMcpServerService {
  bool get isRunning;

  int? get boundPort;

  Uri? get endpoint;

  Future<void> start({required int port});

  Future<void> stop();
}

abstract class IMcpRequestContext {
  Future<T> runOperation<T>(Future<T> Function() operation);

  Future<bool> isAuthorized(Set<String> requiredScopes);

  Future<McpAuthenticatedGrant?> currentGrant({
    Set<String> requiredScopes = const {},
  });
}
