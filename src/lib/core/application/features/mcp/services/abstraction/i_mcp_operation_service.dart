enum McpOperationType { dataImport, syncPair }

enum McpOperationStatus {
  pendingApproval,
  running,
  succeeded,
  failed,
  rejected,
  cancelled,
  expired,
}

final class McpOperationResult {
  McpOperationResult(Map<String, dynamic> value)
      : value = Map.unmodifiable(value.map(
          (key, item) => MapEntry(key, _freezeJson(item)),
        ));

  final Map<String, dynamic> value;
}

Object? _freezeJson(Object? value) => switch (value) {
      null || String() || num() || bool() => value,
      List<dynamic>() => List<dynamic>.unmodifiable(value.map(_freezeJson)),
      Map<String, dynamic>() => Map<String, dynamic>.unmodifiable(
          value.map((key, item) => MapEntry(key, _freezeJson(item))),
        ),
      _ => throw ArgumentError.value(value, 'value', 'Must contain JSON data'),
    };

final class McpOperationFailure {
  const McpOperationFailure({required this.code, required this.message});

  final String code;
  final String message;
}

final class McpOperation {
  McpOperation({
    required this.id,
    required this.type,
    required this.status,
    required this.clientGrantId,
    required Set<String> requiredScopes,
    required this.requestHash,
    required this.summary,
    required this.createdAt,
    required this.approvalExpiresAt,
    this.result,
    this.failure,
  }) : requiredScopes = Set.unmodifiable(requiredScopes);

  final String id;
  final McpOperationType type;
  final McpOperationStatus status;
  final String clientGrantId;
  final Set<String> requiredScopes;
  final String requestHash;
  final String summary;
  final DateTime createdAt;
  final DateTime approvalExpiresAt;
  final McpOperationResult? result;
  final McpOperationFailure? failure;
}

typedef McpOperationExecutor = Future<McpOperationResult> Function();

abstract interface class IMcpOperationService {
  Future<McpOperation> prepare({
    required String clientGrantId,
    required McpOperationType type,
    required Set<String> requiredScopes,
    required String requestHash,
    required String summary,
    required McpOperationExecutor execute,
  });

  Future<McpOperation?> getForClient({
    required String operationId,
    required String clientGrantId,
    required Set<String> currentScopes,
  });

  Future<List<McpOperation>> listPending();

  Future<McpOperation> approve(String operationId);

  Future<McpOperation> reject(String operationId);
}
