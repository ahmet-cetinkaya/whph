import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';

const _operationDocumentVersion = 1;
const _maximumOperationDocumentBytes = 1024 * 1024;

final class McpOperationStore {
  McpOperationStore({
    required IApplicationDirectoryService applicationDirectoryService,
  }) : _applicationDirectoryService = applicationDirectoryService;

  final IApplicationDirectoryService _applicationDirectoryService;
  Future<void> _writeQueue = Future.value();

  Future<List<McpOperation>> load() async {
    final file = await _resolveFile();
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return const [];
    if (type != FileSystemEntityType.file) {
      throw const FormatException('Invalid MCP operation store');
    }
    if (!Platform.isWindows) {
      await _validateOwnerOnly(file.parent.path, 0x1c0);
      await _validateOwnerOnly(file.path, 0x180);
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > _maximumOperationDocumentBytes) {
      throw const FormatException('MCP operation store is too large');
    }
    final document = jsonDecode(utf8.decode(bytes));
    if (document is! Map<String, dynamic> ||
        document['version'] != _operationDocumentVersion ||
        document['operations'] is! List) {
      throw const FormatException('Invalid MCP operation store');
    }
    return List<McpOperation>.unmodifiable(
      (document['operations'] as List).map((value) => _decode(Map<String, dynamic>.from(value as Map))),
    );
  }

  Future<T> update<T>(
    Future<(List<McpOperation>, T)> Function(List<McpOperation>) operation,
  ) {
    final result = _writeQueue.then((_) async {
      final update = await operation(await load());
      await _save(update.$1);
      return update.$2;
    });
    _writeQueue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _save(List<McpOperation> operations) async {
    final bytes = utf8.encode(jsonEncode({
      'version': _operationDocumentVersion,
      'operations': operations.map(_encode).toList(growable: false),
    }));
    if (bytes.length > _maximumOperationDocumentBytes) {
      throw const FormatException('MCP operation store is too large');
    }

    final file = await _resolveFile();
    final directory = file.parent;
    final directoryType = await FileSystemEntity.type(directory.path, followLinks: false);
    if (directoryType == FileSystemEntityType.link) {
      throw const FileSystemException('MCP directory must not be a link');
    }
    await directory.create(recursive: true);
    if (!Platform.isWindows) {
      await _chmod(directory.path, '700');
    }
    final temporary = File('${file.path}.$pid.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (!Platform.isWindows) await _chmod(temporary.path, '600');
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<File> _resolveFile() async {
    final applicationDirectory = await _applicationDirectoryService.getApplicationDirectory();
    return File(p.join(applicationDirectory.path, 'mcp', 'operations.json'));
  }

  Future<void> _chmod(String path, String mode) async {
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw const FileSystemException('MCP operation permissions failed');
    }
  }

  Future<void> _validateOwnerOnly(String path, int expectedMode) async {
    if ((await FileStat.stat(path)).mode & 0x1ff != expectedMode) {
      throw const FileSystemException('MCP operation permissions are not private');
    }
  }

  Map<String, dynamic> _encode(McpOperation operation) => {
        'id': operation.id,
        'type': operation.type.name,
        'status': operation.status.name,
        'clientGrantId': operation.clientGrantId,
        'requiredScopes': operation.requiredScopes.toList()..sort(),
        'requestHash': operation.requestHash,
        'summary': operation.summary,
        'createdAt': operation.createdAt.toUtc().toIso8601String(),
        'approvalExpiresAt': operation.approvalExpiresAt.toUtc().toIso8601String(),
        if (operation.result != null) 'result': operation.result!.value,
        if (operation.failure != null)
          'failure': {
            'code': operation.failure!.code,
            'message': operation.failure!.message,
          },
      };

  McpOperation _decode(Map<String, dynamic> json) {
    final scopes = json['requiredScopes'];
    final result = json['result'];
    final failure = json['failure'];
    if (scopes is! List || scopes.any((scope) => scope is! String)) {
      throw const FormatException('Invalid operation scopes');
    }
    return McpOperation(
      id: json['id'] as String,
      type: McpOperationType.values.byName(json['type'] as String),
      status: McpOperationStatus.values.byName(json['status'] as String),
      clientGrantId: json['clientGrantId'] as String,
      requiredScopes: scopes.cast<String>().toSet(),
      requestHash: json['requestHash'] as String,
      summary: json['summary'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      approvalExpiresAt: DateTime.parse(json['approvalExpiresAt'] as String).toUtc(),
      result: result is Map ? McpOperationResult(Map<String, dynamic>.from(result)) : null,
      failure: failure is Map
          ? McpOperationFailure(
              code: failure['code'] as String,
              message: failure['message'] as String,
            )
          : null,
    );
  }
}
