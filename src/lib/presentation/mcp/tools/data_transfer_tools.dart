import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

const _fullExportScopes = {
  McpScopes.dataExport,
  McpScopes.tasksRead,
  McpScopes.habitsRead,
  McpScopes.notesRead,
  McpScopes.tagsRead,
  McpScopes.usageRead,
  McpScopes.settingsRead,
  McpScopes.syncRead,
};

List<McpToolDefinition> buildDataTransferTools({
  required IMcpDataTransferService transferService,
  required IMcpOperationService operationService,
  required IMcpRequestContext requestContext,
}) =>
    List.unmodifiable([
      McpToolDefinition(
        name: 'whph_data_export',
        description:
            'Exports all authorized WHPH data to a caller-owned expiring artifact.',
        inputSchema: _object(
          {'format': _enum(['json', 'csv', 'whph'])},
          required: const ['format'],
        ),
        outputSchema: _artifactOutput,
        annotations: _additive,
        requiredScopes: _fullExportScopes,
        handler: (arguments, extra) => requestContext.runOperation(() async {
          final grant =
              await requestContext.currentGrant(requiredScopes: _fullExportScopes);
          if (grant == null) return _permissionDenied();
          final format = McpDataExportFormat.values
              .byName(arguments.requireString('format'));
          final artifact = await transferService.exportData(
            clientGrantId: grant.id,
            format: format,
          );
          return McpToolResult.success(_artifactJson(artifact));
        }),
      ),
      McpToolDefinition(
        name: 'whph_data_import_prepare',
        description:
            'Stages a WHPH basename from the user-selected transfer directory for local approval.',
        inputSchema: _object({
          'artifactId': JsonSchema.string(minLength: 1, maxLength: 255),
          'strategy': _enum(['merge', 'replace']),
        }, required: const ['artifactId', 'strategy']),
        outputSchema: _preparedOutput,
        annotations: _additive,
        requiredScopes: const {McpScopes.dataImport},
        handler: (arguments, extra) => requestContext.runOperation(() async {
          final grant = await requestContext.currentGrant(
            requiredScopes: const {McpScopes.dataImport},
          );
          if (grant == null) return _permissionDenied();
          final McpOperation operation;
          try {
            operation = await transferService.prepareImport(
              clientGrantId: grant.id,
              currentScopes: grant.scopes,
              sourceName: arguments.requireString('artifactId'),
              strategy: McpDataImportStrategy.values
                  .byName(arguments.requireString('strategy')),
            );
          } on McpDataTransferException catch (error) {
            return McpToolResult.failure(McpToolError(
              code: switch (error.failure) {
                McpDataTransferFailure.permissionRequired =>
                  McpToolErrorCode.permissionRequired,
                McpDataTransferFailure.permissionDenied =>
                  McpToolErrorCode.permissionDenied,
                McpDataTransferFailure.invalidInput ||
                McpDataTransferFailure.limitExceeded =>
                  McpToolErrorCode.validationError,
              },
              message: error.message,
            ));
          }
          return McpToolResult.failure(McpToolError(
            code: McpToolErrorCode.approvalRequired,
            message: 'Local approval is required before this import runs.',
            details: _preparedJson(operation),
          ));
        }),
      ),
      McpToolDefinition(
        name: 'whph_operations_get',
        description:
            'Returns a caller-owned operation status; it cannot approve an operation.',
        inputSchema: _object(
          {'operationId': JsonSchema.string(minLength: 1, maxLength: 128)},
          required: const ['operationId'],
        ),
        outputSchema: _operationOutput,
        annotations: _read,
        requiredScopes: const {},
        anyOfScopes: const {McpScopes.dataImport, McpScopes.syncManage},
        handler: (arguments, extra) async {
          final grant = await requestContext.currentGrant();
          if (grant == null) return _permissionDenied();
          final operation = await operationService.getForClient(
            operationId: arguments.requireString('operationId'),
            clientGrantId: grant.id,
            currentScopes: grant.scopes,
          );
          if (operation == null) {
            return McpToolResult.failure(McpToolError(
              code: McpToolErrorCode.notFound,
              message: 'The operation was not found.',
            ));
          }
          return McpToolResult.success(_operationJson(operation));
        },
      ),
    ]);

Map<String, dynamic> _artifactJson(McpTransferArtifact artifact) => {
      'artifactId': artifact.id,
      'fileName': artifact.fileName,
      'fileExtension': artifact.fileExtension,
      'sizeBytes': artifact.sizeBytes,
      'sha256': artifact.sha256,
      'expiresAt': artifact.expiresAt.toUtc().toIso8601String(),
    };

Map<String, dynamic> _preparedJson(McpOperation operation) => {
      'operationId': operation.id,
      'status': _statusName(operation.status),
      'requiresApproval': true,
      'expiresAt': operation.approvalExpiresAt.toUtc().toIso8601String(),
      'summary': operation.summary,
    };

Map<String, dynamic> _operationJson(McpOperation operation) => {
      'operationId': operation.id,
      'type': switch (operation.type) {
        McpOperationType.dataImport => 'data_import',
        McpOperationType.syncPair => 'sync_pair',
      },
      'status': _statusName(operation.status),
      'createdAt': operation.createdAt.toUtc().toIso8601String(),
      'expiresAt': operation.approvalExpiresAt.toUtc().toIso8601String(),
      'summary': operation.summary,
      if (operation.result != null) 'result': operation.result!.value,
      if (operation.failure != null)
        'error': {
          'code': operation.failure!.code,
          'message': operation.failure!.message,
        },
    };

String _statusName(McpOperationStatus status) => switch (status) {
      McpOperationStatus.pendingApproval => 'pending_approval',
      McpOperationStatus.running => 'running',
      McpOperationStatus.succeeded => 'succeeded',
      McpOperationStatus.failed => 'failed',
      McpOperationStatus.rejected => 'rejected',
      McpOperationStatus.cancelled => 'cancelled',
      McpOperationStatus.expired => 'expired',
    };

Never _permissionDenied() => throw McpToolException(McpToolError(
      code: McpToolErrorCode.permissionDenied,
      message: 'The connection is not permitted to use this tool.',
    ));

JsonObject _object(
  Map<String, JsonSchema> properties, {
  List<String>? required,
}) =>
    JsonSchema.object(
      properties: properties,
      required: required,
      additionalProperties: false,
    );

JsonSchema _enum(List<String> values) =>
    JsonSchema.fromJson({'type': 'string', 'enum': values});

const _read = ToolAnnotations(
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
);
const _additive = ToolAnnotations(
  readOnlyHint: false,
  destructiveHint: false,
  idempotentHint: false,
  openWorldHint: false,
);

final _artifactOutput = _object({
  'artifactId': JsonSchema.string(),
  'fileName': JsonSchema.string(),
  'fileExtension': JsonSchema.string(),
  'sizeBytes': JsonSchema.integer(minimum: 0),
  'sha256': JsonSchema.string(),
  'expiresAt': JsonSchema.string(format: 'date-time'),
}, required: const [
  'artifactId',
  'fileName',
  'fileExtension',
  'sizeBytes',
  'sha256',
  'expiresAt',
]);

final _preparedOutput = _object({
  'operationId': JsonSchema.string(),
  'status': JsonSchema.string(),
  'requiresApproval': JsonSchema.boolean(),
  'expiresAt': JsonSchema.string(format: 'date-time'),
  'summary': JsonSchema.string(),
}, required: const [
  'operationId',
  'status',
  'requiresApproval',
  'expiresAt',
  'summary',
]);

final _operationOutput = _object({
  'operationId': JsonSchema.string(),
  'type': JsonSchema.string(),
  'status': JsonSchema.string(),
  'createdAt': JsonSchema.string(format: 'date-time'),
  'expiresAt': JsonSchema.string(format: 'date-time'),
  'summary': JsonSchema.string(),
  'result': _object({
    'strategy': JsonSchema.string(),
    'imported': JsonSchema.boolean(),
    'deviceId': JsonSchema.string(),
    'status': JsonSchema.string(),
  }),
  'error': _object({
    'code': JsonSchema.string(),
    'message': JsonSchema.string(),
  }, required: const ['code', 'message']),
}, required: const [
  'operationId',
  'type',
  'status',
  'createdAt',
  'expiresAt',
  'summary',
]);
