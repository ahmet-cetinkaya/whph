import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

const mcpArtifactChunkBytes = 256 * 1024;

McpToolDefinition createAppContextTool({
  required IMcpRequestContext requestContext,
  DateTime Function()? now,
  String? platform,
}) =>
    McpToolDefinition(
      name: 'whph_app_context',
      description:
          'Reports the local WHPH runtime, supported capabilities, limits, and current connection scopes. It never returns credentials.',
      inputSchema: JsonSchema.object(additionalProperties: false),
      outputSchema: _outputSchema,
      annotations: const ToolAnnotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      ),
      requiredScopes: const {McpScopes.appRead},
      handler: (arguments, extra) async {
        final grant = await requestContext.currentGrant(
          requiredScopes: const {McpScopes.appRead},
        );
        if (grant == null) {
          return McpToolResult.failure(McpToolError(
            code: McpToolErrorCode.permissionDenied,
            message: 'The connection is not permitted to read app context.',
          ));
        }
        final localNow = (now ?? DateTime.now)().toLocal();
        final scopes = grant.scopes.toList(growable: false)..sort();
        return McpToolResult.success({
          'version': AppInfo.version,
          'platform': platform ?? Platform.operatingSystem,
          'localDateTime': _iso8601WithOffset(localNow),
          'timeZone': localNow.timeZoneName,
          'supportedFeatures': _supportedFeatures(grant.scopes),
          'limits': const {
            'maximumRequestBytes': 1024 * 1024,
            'maximumPageSize': 200,
            'artifactChunkBytes': mcpArtifactChunkBytes,
            'normalRequestTimeoutSeconds': 30,
            'longOperationTimeoutSeconds': 120,
          },
          'grantedScopes': scopes,
        });
      },
    );

String _iso8601WithOffset(DateTime value) {
  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absoluteOffset = offset.abs();
  final hours = absoluteOffset.inHours.toString().padLeft(2, '0');
  final minutes = (absoluteOffset.inMinutes % 60).toString().padLeft(2, '0');
  return '${value.toIso8601String()}$sign$hours:$minutes';
}

List<String> _supportedFeatures(Set<String> scopes) {
  const features = <String, Set<String>>{
    'tasks': {McpScopes.tasksRead, McpScopes.tasksWrite, McpScopes.tasksDelete},
    'habits': {
      McpScopes.habitsRead,
      McpScopes.habitsWrite,
      McpScopes.habitsDelete
    },
    'notes': {McpScopes.notesRead, McpScopes.notesWrite, McpScopes.notesDelete},
    'tags': {McpScopes.tagsRead, McpScopes.tagsWrite, McpScopes.tagsDelete},
    'timers': {McpScopes.timersRead, McpScopes.timersWrite},
    'usage': {
      McpScopes.usageRead,
      McpScopes.usageWrite,
      McpScopes.usageDelete,
      McpScopes.usageTrack
    },
    'settings': {McpScopes.settingsRead, McpScopes.settingsWrite},
    'sync': {McpScopes.syncRead, McpScopes.syncManage},
    'overview': {McpScopes.overviewRead},
    'dataTransfer': {McpScopes.dataExport, McpScopes.dataImport},
  };
  return [
    for (final entry in features.entries)
      if (entry.value.any(scopes.contains)) entry.key,
  ];
}

final JsonObject _outputSchema = JsonSchema.object(
  properties: {
    'version': JsonSchema.string(),
    'platform': JsonSchema.string(),
    'localDateTime': JsonSchema.string(format: 'date-time'),
    'timeZone': JsonSchema.string(),
    'supportedFeatures': JsonSchema.array(items: JsonSchema.string()),
    'limits': JsonSchema.object(
      properties: {
        'maximumRequestBytes': JsonSchema.integer(),
        'maximumPageSize': JsonSchema.integer(),
        'artifactChunkBytes': JsonSchema.integer(),
        'normalRequestTimeoutSeconds': JsonSchema.integer(),
        'longOperationTimeoutSeconds': JsonSchema.integer(),
      },
      required: const [
        'maximumRequestBytes',
        'maximumPageSize',
        'artifactChunkBytes',
        'normalRequestTimeoutSeconds',
        'longOperationTimeoutSeconds',
      ],
      additionalProperties: false,
    ),
    'grantedScopes': JsonSchema.array(items: JsonSchema.string()),
  },
  required: const [
    'version',
    'platform',
    'localDateTime',
    'timeZone',
    'supportedFeatures',
    'limits',
    'grantedScopes',
  ],
  additionalProperties: false,
);
