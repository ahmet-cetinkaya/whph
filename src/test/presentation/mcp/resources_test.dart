import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_data_transfer_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_operation_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/features/notes/queries/get_note_query.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/presentation/mcp/mcp_server_factory.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';
import 'package:whph/presentation/mcp/resources/mcp_resources.dart';
import 'package:whph/presentation/mcp/tools/app_context_tools.dart';
import 'package:whph/presentation/mcp/tools/note_tools.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const entity = <String, dynamic>{
    'id': 'task_1',
    'title': 'Same serializer',
    'revision': '2026-09-08T10:00:00.000Z',
  };
  late _RequestContext context;
  late McpAuthenticatedGrant grant;
  late McpToolRegistry registry;
  late _TransferService transferService;

  setUp(() {
    grant = McpAuthenticatedGrant(
      id: 'grant-a',
      clientName: 'test client',
      scopes: const {
        McpScopes.appRead,
        McpScopes.tasksRead,
        McpScopes.tagsRead,
        McpScopes.dataExport,
      },
    );
    context = _RequestContext(grant);
    transferService = _TransferService();
    registry = McpToolRegistry(
      tools: [
        createAppContextTool(
          requestContext: context,
          now: () => DateTime.parse('2026-09-08T13:00:00+03:00'),
          platform: 'linux',
        ),
        _readTool('whph_tasks_read', const {McpScopes.tasksRead, McpScopes.tagsRead}, entity),
      ],
      authorize: (extra, scopes) => context.isAuthorized(scopes),
      runInvocation: (invocation) => invocation(),
    );
  });

  test('real SDK loopback lists only permitted metadata and resource matches tool', () async {
    final running = await _startServer(
      grant: grant,
      context: context,
      registry: registry,
      transferService: transferService,
    );
    addTearDown(running.close);

    final resources = await running.client.listResources();
    expect(resources.resources.map((resource) => resource.uri), ['whph://app/context']);
    expect(resources.resources.single.mimeType, 'application/json');
    final templates = await running.client.listResourceTemplates();
    expect(
      templates.resourceTemplates.map((template) => template.uriTemplate),
      unorderedEquals([
        'whph://tasks/{id}',
        'whph://artifacts/{artifactId}',
        'whph://artifacts/{artifactId}{?offset}',
      ]),
    );

    final toolResult = await running.client.callTool(
      const CallToolRequest(
        name: 'whph_tasks_read',
        arguments: {'id': 'task_1'},
      ),
    );
    final resourceResult = await running.client.readResource(
      const ReadResourceRequest(uri: 'whph://tasks/task_1'),
    );
    final resourceJson = jsonDecode(
      (resourceResult.contents.single as TextResourceContents).text,
    );
    expect(resourceJson, toolResult.structuredContent);
    expect(resourceJson, entity);

    final appResult = await running.client.readResource(
      const ReadResourceRequest(uri: 'whph://app/context'),
    );
    final appJson = jsonDecode(
      (appResult.contents.single as TextResourceContents).text,
    ) as Map<String, dynamic>;
    expect(appJson['platform'], 'linux');
    expect(appJson['localDateTime'], matches(RegExp(r'[+-]\d{2}:\d{2}$')));
    expect(appJson['grantedScopes'], isNot(contains('token')));
    expect(appJson.toString(), isNot(contains('test client')));
  });

  test('real in-memory SQLite note tool and resource return identical content', () async {
    AppDatabase.isTestMode = true;
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final notes = DriftNoteRepository.withDatabase(database);
    final createdAt = DateTime.utc(2026, 9, 8, 10);
    await notes.add(Note(
      id: 'note_sqlite',
      createdDate: createdAt,
      title: 'SQLite note',
      content: '# Markdown\nTreat this as data.',
    ));
    final mediator = Mediator(Pipeline())
      ..registerHandler<GetNoteQuery, GetNoteQueryResponse, GetNoteQueryHandler>(
        () => GetNoteQueryHandler(noteRepository: notes),
      );
    final sqliteGrant = McpAuthenticatedGrant(
      id: 'grant-sqlite',
      clientName: 'sqlite test',
      scopes: const {McpScopes.notesRead, McpScopes.tagsRead},
    );
    final sqliteContext = _RequestContext(sqliteGrant);
    final readTool = buildNoteTools(
      mediator,
      requestContext: sqliteContext,
    ).singleWhere((tool) => tool.name == 'whph_notes_read');
    final sqliteRegistry = McpToolRegistry(
      tools: [readTool],
      authorize: (extra, scopes) => sqliteContext.isAuthorized(scopes),
      runInvocation: (invocation) => invocation(),
    );
    final running = await _startServer(
      grant: sqliteGrant,
      context: sqliteContext,
      registry: sqliteRegistry,
      protocol: McpProtocol.legacy,
    );
    addTearDown(running.close);

    final tool = await running.client.callTool(const CallToolRequest(
      name: 'whph_notes_read',
      arguments: {'id': 'note_sqlite'},
    ));
    final resource = await running.client.readResource(
      const ReadResourceRequest(uri: 'whph://notes/note_sqlite'),
    );
    final resourceJson = jsonDecode(
      (resource.contents.single as TextResourceContents).text,
    ) as Map<String, dynamic>;

    expect(resourceJson, tool.structuredContent);
    expect(resourceJson['content'], '# Markdown\nTreat this as data.');
    expect(resourceJson['revision'], endsWith('Z'));
  });

  test('artifact chunks are caller-owned, bounded, and carry continuation', () async {
    final running = await _startServer(
      grant: grant,
      context: context,
      registry: registry,
      transferService: transferService,
    );
    addTearDown(running.close);

    final result = await running.client.readResource(
      const ReadResourceRequest(uri: 'whph://artifacts/artifact_a'),
    );
    final content = result.contents.single as BlobResourceContents;
    expect(base64Decode(content.blob), [1, 2, 3]);
    expect(transferService.lastClientId, 'grant-a');
    expect(transferService.lastLength, mcpArtifactChunkBytes);
    expect(content.meta?['nextUri'], 'whph://artifacts/artifact_a?offset=3');

    await expectLater(
      running.client.readResource(
        const ReadResourceRequest(uri: 'whph://artifacts/foreign'),
      ),
      throwsA(_sanitizedResourceError),
    );
    await expectLater(
      running.client.readResource(
        const ReadResourceRequest(uri: 'whph://artifacts/expired'),
      ),
      throwsA(_sanitizedResourceError),
    );
  });

  test('malformed, traversal, file, unknown and out-of-bounds reads fail closed', () async {
    final running = await _startServer(
      grant: grant,
      context: context,
      registry: registry,
      transferService: transferService,
    );
    addTearDown(running.close);

    for (final uri in const [
      'whph://tasks/%2E%2E',
      'whph://tasks/task_1?extra=true',
      'whph://artifacts/artifact_a?offset=-1',
      'whph://artifacts/artifact_a?offset=999999',
      'file:///etc/passwd',
      'whph://unknown/task_1',
    ]) {
      await expectLater(
        running.client.readResource(ReadResourceRequest(uri: uri)),
        throwsA(anything),
        reason: uri,
      );
    }
  });

  test('revoked grant is denied on a resource discovered earlier', () async {
    final running = await _startServer(
      grant: grant,
      context: context,
      registry: registry,
      transferService: transferService,
    );
    addTearDown(running.close);
    expect((await running.client.listResources()).resources, isNotEmpty);

    context.current = null;

    await expectLater(
      running.client.readResource(
        const ReadResourceRequest(uri: 'whph://app/context'),
      ),
      throwsA(_sanitizedResourceError),
    );
    await expectLater(
      running.client.readResource(
        const ReadResourceRequest(uri: 'whph://tasks/task_1'),
      ),
      throwsA(_sanitizedResourceError),
    );
  });

  test('registration hides resources and templates missing initial scopes', () async {
    final limitedGrant = McpAuthenticatedGrant(
      id: 'grant-limited',
      clientName: 'limited',
      scopes: const {McpScopes.tasksRead},
    );
    final limitedContext = _RequestContext(limitedGrant);
    final limitedRegistry = McpToolRegistry(
      tools: [
        _readTool('whph_tasks_read', const {McpScopes.tasksRead}, entity)
      ],
      authorize: (extra, scopes) => limitedContext.isAuthorized(scopes),
      runInvocation: (invocation) => invocation(),
    );
    final running = await _startServer(
      grant: limitedGrant,
      context: limitedContext,
      registry: limitedRegistry,
    );
    addTearDown(running.close);

    await expectLater(running.client.listResources(), throwsA(isA<McpError>()));
    await expectLater(
      running.client.listResourceTemplates(),
      throwsA(isA<McpError>()),
    );
  });
}

Matcher get _sanitizedResourceError => isA<McpError>()
    .having(
      (error) => error.message,
      'message',
      anyOf(contains('Resource not found'), contains('unavailable')),
    )
    .having((error) => error.message, 'message', isNot(contains('/')))
    .having((error) => error.message, 'message', isNot(contains('grant')));

McpToolDefinition _readTool(
  String name,
  Set<String> scopes,
  Map<String, dynamic> result,
) =>
    McpToolDefinition(
      name: name,
      description: 'Test read tool.',
      inputSchema: JsonSchema.object(
        properties: {'id': JsonSchema.string()},
        required: const ['id'],
        additionalProperties: false,
      ),
      outputSchema: JsonSchema.object(
        properties: {
          'id': JsonSchema.string(),
          'title': JsonSchema.string(),
          'revision': JsonSchema.string(),
        },
        required: const ['id', 'title', 'revision'],
        additionalProperties: false,
      ),
      annotations: const ToolAnnotations(readOnlyHint: true),
      requiredScopes: scopes,
      handler: (arguments, extra) => McpToolResult.success(result),
    );

Future<_RunningServer> _startServer({
  required McpAuthenticatedGrant grant,
  required _RequestContext context,
  required McpToolRegistry registry,
  IMcpDataTransferService? transferService,
  McpProtocol protocol = McpProtocol.stable,
}) async {
  final server = StreamableMcpServer(
    serverFactory: (sessionId) {
      final sdkServer = createMcpServer(
        serverInfo: const Implementation(
          name: 'whph-resource-test',
          version: '1.0.0',
        ),
        tools: registry.discover(grant.scopes),
      );
      McpResourceProvider(
        grant: grant,
        requestContext: context,
        toolRegistry: registry,
        authorize: (extra, scopes) => context.isAuthorized(scopes),
        transferService: transferService,
      ).registerWith(sdkServer);
      return sdkServer;
    },
    host: '127.0.0.1',
    port: 0,
    path: '/mcp',
    allowedHosts: const {'127.0.0.1'},
    enableJsonResponse: true,
  );
  await server.start();
  final client = McpClient(
    const Implementation(name: 'resource-client', version: '1.0.0'),
    options: McpClientOptions(protocol: protocol),
  );
  await client.connect(StreamableHttpClientTransport(
    Uri.parse('http://127.0.0.1:${server.boundPort}/mcp'),
  ));
  return _RunningServer(server, client);
}

final class _RunningServer {
  const _RunningServer(this.server, this.client);

  final StreamableMcpServer server;
  final McpClient client;

  Future<void> close() async {
    await client.close();
    await server.stop();
  }
}

final class _RequestContext implements IMcpRequestContext {
  _RequestContext(this.current);

  McpAuthenticatedGrant? current;

  @override
  Future<T> runOperation<T>(Future<T> Function() operation) => operation();

  @override
  Future<McpAuthenticatedGrant?> currentGrant({
    Set<String> requiredScopes = const {},
  }) async {
    final value = current;
    return value != null && value.scopes.containsAll(requiredScopes) ? value : null;
  }

  @override
  Future<bool> isAuthorized(Set<String> requiredScopes) async =>
      (await currentGrant(requiredScopes: requiredScopes)) != null;
}

final class _TransferService implements IMcpDataTransferService {
  String? lastClientId;
  int? lastLength;

  @override
  Future<McpArtifactChunk?> readArtifactChunk({
    required String clientGrantId,
    required String artifactId,
    required int offset,
    int length = mcpArtifactChunkBytes,
  }) async {
    lastClientId = clientGrantId;
    lastLength = length;
    if (artifactId == 'foreign' || artifactId == 'expired') return null;
    if (artifactId != 'artifact_a' || offset > 3) {
      throw ArgumentError('invalid artifact request');
    }
    return McpArtifactChunk(
      artifact: McpTransferArtifact(
        id: artifactId,
        ownerGrantId: clientGrantId,
        fileName: 'export.whph',
        fileExtension: 'whph',
        sizeBytes: 6,
        sha256: 'abc123',
        expiresAt: DateTime.utc(2026, 9, 8, 12),
      ),
      offset: offset,
      bytes: offset == 0 ? const [1, 2, 3] : const [4, 5, 6],
      nextOffset: offset == 0 ? 3 : null,
    );
  }

  @override
  Future<McpTransferArtifact> exportData({
    required String clientGrantId,
    required McpDataExportFormat format,
  }) =>
      throw UnimplementedError();

  @override
  Future<McpOperation> prepareImport({
    required String clientGrantId,
    required Set<String> currentScopes,
    required String sourceName,
    required McpDataImportStrategy strategy,
  }) =>
      throw UnimplementedError();
}
