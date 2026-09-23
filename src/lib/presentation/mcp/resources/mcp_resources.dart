import 'dart:convert';

import 'package:acore/acore.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/tools/app_context_tools.dart';

const _jsonMimeType = 'application/json';
const _binaryMimeType = 'application/octet-stream';
const _appContextUri = 'whph://app/context';
const _firstArtifactTemplate = 'whph://artifacts/{artifactId}';
const _artifactTemplate = 'whph://artifacts/{artifactId}{?offset}';
final _opaqueIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

void registerMcpResources({
  required McpServer server,
  required IContainer container,
  required McpAuthenticatedGrant grant,
  required IMcpRequestContext requestContext,
  required McpToolRegistry toolRegistry,
  required McpToolAuthorizer authorize,
}) {
  final transferService = grant.scopes.contains(McpScopes.dataExport)
      ? container.resolve<IMcpDataTransferService>()
      : null;
  McpResourceProvider(
    grant: grant,
    requestContext: requestContext,
    toolRegistry: toolRegistry,
    authorize: authorize,
    transferService: transferService,
  ).registerWith(server);
}

final class McpResourceProvider {
  const McpResourceProvider({
    required this.grant,
    required this.requestContext,
    required this.toolRegistry,
    required this.authorize,
    this.transferService,
  });

  final McpAuthenticatedGrant grant;
  final IMcpRequestContext requestContext;
  final McpToolRegistry toolRegistry;
  final McpToolAuthorizer authorize;
  final IMcpDataTransferService? transferService;

  void registerWith(McpServer server) {
    if (grant.scopes.contains(McpScopes.appRead)) {
      server.registerResource(
        'whph-app-context',
        _appContextUri,
        (
          description:
              'Current WHPH runtime and authorized capability summary.',
          mimeType: _jsonMimeType,
        ),
        (uri, extra) => _runResource(
          extra,
          const {McpScopes.appRead},
          () => _readAppContext(uri, extra),
        ),
        title: 'WHPH application context',
      );
    }
    _registerEntityTemplate(
      server: server,
      host: 'tasks',
      toolName: 'whph_tasks_read',
      requiredScopes: const {McpScopes.tasksRead, McpScopes.tagsRead},
      title: 'WHPH task',
    );
    _registerEntityTemplate(
      server: server,
      host: 'habits',
      toolName: 'whph_habits_read',
      requiredScopes: const {McpScopes.habitsRead},
      title: 'WHPH habit',
    );
    _registerEntityTemplate(
      server: server,
      host: 'notes',
      toolName: 'whph_notes_read',
      requiredScopes: const {McpScopes.notesRead, McpScopes.tagsRead},
      title: 'WHPH note',
    );
    if (grant.scopes.contains(McpScopes.dataExport) &&
        transferService != null) {
      _registerArtifactTemplate(
          server, 'whph-artifact-first', _firstArtifactTemplate);
      _registerArtifactTemplate(
          server, 'whph-artifact-chunk', _artifactTemplate);
    }
  }

  void _registerArtifactTemplate(
    McpServer server,
    String name,
    String template,
  ) {
    server.registerResourceTemplate(
      name,
      ResourceTemplateRegistration(template, listCallback: null),
      (
        description: 'A caller-owned export artifact read in bounded chunks.',
        mimeType: _binaryMimeType,
      ),
      (uri, variables, extra) => _runResource(
        extra,
        const {McpScopes.dataExport},
        () => _readArtifact(uri),
      ),
      title: 'WHPH export artifact',
    );
  }

  void _registerEntityTemplate({
    required McpServer server,
    required String host,
    required String toolName,
    required Set<String> requiredScopes,
    required String title,
  }) {
    if (!grant.scopes.containsAll(requiredScopes)) return;
    server.registerResourceTemplate(
      'whph-$host-item',
      ResourceTemplateRegistration('whph://$host/{id}', listCallback: null),
      (
        description: '$title content from the matching WHPH read tool.',
        mimeType: _jsonMimeType,
      ),
      (uri, variables, extra) => _runResource(
        extra,
        requiredScopes,
        () => _readEntity(
          uri: uri,
          expectedHost: host,
          toolName: toolName,
          extra: extra,
        ),
      ),
      title: title,
    );
  }

  Future<ReadResourceResult> _readAppContext(
    Uri uri,
    RequestHandlerExtra extra,
  ) async {
    _requireExactUri(uri, _appContextUri);
    return _readToolResource(
      uri: uri,
      toolName: 'whph_app_context',
      arguments: const {},
      extra: extra,
    );
  }

  Future<ReadResourceResult> _readEntity({
    required Uri uri,
    required String expectedHost,
    required String toolName,
    required RequestHandlerExtra extra,
  }) async {
    final id = _entityId(uri, expectedHost);
    return _readToolResource(
      uri: uri,
      toolName: toolName,
      arguments: {'id': id},
      extra: extra,
    );
  }

  Future<ReadResourceResult> _readToolResource({
    required Uri uri,
    required String toolName,
    required Map<String, dynamic> arguments,
    required RequestHandlerExtra extra,
  }) async {
    try {
      final result = await toolRegistry.invoke(
        toolName,
        McpToolArguments(arguments),
        extra,
      );
      final value = result.structuredContent;
      if (result.isError || value == null) throw const _UnavailableResource();
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: uri.toString(),
            mimeType: _jsonMimeType,
            text: jsonEncode(value),
          ),
        ],
        cacheScope: 'private',
      );
    } on McpError {
      rethrow;
    } catch (_) {
      throw McpError(
        ErrorCode.resourceNotFound.value,
        'The requested WHPH resource is unavailable.',
      );
    }
  }

  Future<ReadResourceResult> _readArtifact(Uri uri) async {
    final service = transferService;
    if (service == null) return _unavailable();
    final parsed = _artifactRequest(uri);
    try {
      final chunk = await service.readArtifactChunk(
        clientGrantId: grant.id,
        artifactId: parsed.id,
        offset: parsed.offset,
        length: mcpArtifactChunkBytes,
      );
      if (chunk == null) return _unavailable();
      return ReadResourceResult(
        contents: [
          BlobResourceContents(
            uri: uri.toString(),
            mimeType: _binaryMimeType,
            blob: base64Encode(chunk.bytes),
            meta: {
              'artifactId': chunk.artifact.id,
              'offset': chunk.offset,
              'sizeBytes': chunk.artifact.sizeBytes,
              'sha256': chunk.artifact.sha256,
              'expiresAt': chunk.artifact.expiresAt.toUtc().toIso8601String(),
              if (chunk.nextOffset != null)
                'nextUri':
                    'whph://artifacts/${chunk.artifact.id}?offset=${chunk.nextOffset}',
            },
          ),
        ],
        cacheScope: 'private',
      );
    } on McpError {
      rethrow;
    } catch (_) {
      return _unavailable();
    }
  }

  Future<ReadResourceResult> _runResource(
    RequestHandlerExtra extra,
    Set<String> scopes,
    Future<ReadResourceResult> Function() read,
  ) async {
    if (!await authorize(extra, scopes)) return _unavailable();
    return requestContext.runOperation(() async {
      final current = await requestContext.currentGrant(requiredScopes: scopes);
      if (current == null || current.id != grant.id) return _unavailable();
      return read();
    });
  }
}

Never _unavailable() => throw McpError(
      ErrorCode.resourceNotFound.value,
      'The requested WHPH resource is unavailable.',
    );

void _requireExactUri(Uri uri, String expected) {
  if (uri.toString() != expected) _invalidUri();
}

String _entityId(Uri uri, String expectedHost) {
  if (uri.scheme != 'whph' ||
      uri.host != expectedHost ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.length != 1) {
    _invalidUri();
  }
  final id = uri.pathSegments.single;
  if (!_opaqueIdPattern.hasMatch(id)) _invalidUri();
  return id;
}

({String id, int offset}) _artifactRequest(Uri uri) {
  if (uri.scheme != 'whph' ||
      uri.host != 'artifacts' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.pathSegments.length != 1 ||
      uri.queryParametersAll.keys.any((key) => key != 'offset') ||
      (uri.queryParametersAll['offset']?.length ?? 0) > 1) {
    _invalidUri();
  }
  final id = uri.pathSegments.single;
  if (!_opaqueIdPattern.hasMatch(id)) _invalidUri();
  final rawOffset = uri.queryParameters['offset'];
  final offset = rawOffset == null ? 0 : int.tryParse(rawOffset);
  if (offset == null || offset < 0) _invalidUri();
  return (id: id, offset: offset);
}

Never _invalidUri() => throw McpError(
      ErrorCode.invalidParams.value,
      'The WHPH resource URI is malformed.',
    );

final class _UnavailableResource implements Exception {
  const _UnavailableResource();
}
