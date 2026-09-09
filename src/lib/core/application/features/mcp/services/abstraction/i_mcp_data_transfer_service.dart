import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';

enum McpDataExportFormat { json, csv, whph }

enum McpDataImportStrategy { merge, replace }

enum McpDataTransferFailure {
  invalidInput,
  permissionRequired,
  permissionDenied,
  limitExceeded,
}

final class McpDataTransferException implements Exception {
  const McpDataTransferException(this.failure, this.message);

  final McpDataTransferFailure failure;
  final String message;
}

final class McpTransferArtifact {
  const McpTransferArtifact({
    required this.id,
    required this.ownerGrantId,
    required this.fileName,
    required this.fileExtension,
    required this.sizeBytes,
    required this.sha256,
    required this.expiresAt,
  });

  final String id;
  final String ownerGrantId;
  final String fileName;
  final String fileExtension;
  final int sizeBytes;
  final String sha256;
  final DateTime expiresAt;
}

final class McpArtifactChunk {
  McpArtifactChunk({
    required this.artifact,
    required this.offset,
    required List<int> bytes,
    required this.nextOffset,
  }) : bytes = List.unmodifiable(bytes);

  final McpTransferArtifact artifact;
  final int offset;
  final List<int> bytes;
  final int? nextOffset;
}

abstract interface class IMcpDataTransferService {
  Future<McpTransferArtifact> exportData({
    required String clientGrantId,
    required McpDataExportFormat format,
  });

  Future<McpOperation> prepareImport({
    required String clientGrantId,
    required Set<String> currentScopes,
    required String sourceName,
    required McpDataImportStrategy strategy,
  });

  Future<McpArtifactChunk?> readArtifactChunk({
    required String clientGrantId,
    required String artifactId,
    required int offset,
    int length = 256 * 1024,
  });
}
