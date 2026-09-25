import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/presentation/mcp/mcp_server_factory.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_arguments.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_error.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

void main() {
  group('MCP tool contract', () {
    test('arguments are immutable and expose typed values', () {
      final nested = <String, dynamic>{
        'name': 'Ada',
        'count': 2,
        'enabled': true,
        'metadata': <String, dynamic>{'source': 'test'},
      };
      final arguments = McpToolArguments(nested);

      nested['name'] = 'mutated';
      (nested['metadata'] as Map<String, dynamic>)['source'] = 'mutated';

      expect(arguments.requireString('name'), 'Ada');
      expect(arguments.optionalInt('count'), 2);
      expect(arguments.optionalBool('enabled'), isTrue);
      expect(arguments.optionalObject('metadata'), {'source': 'test'});
      expect(arguments.contains('name'), isTrue);
      expect(arguments['name'], 'Ada');
      expect(arguments.optionalString('name'), 'Ada');
      expect(arguments.optionalNumber('count'), 2);
      expect(arguments.optionalList('missing'), isNull);
      expect(
        () => arguments.optionalObject('metadata')!['source'] = 'mutated',
        throwsUnsupportedError,
      );
      final projected = arguments.toJson();
      (projected['metadata'] as Map<String, dynamic>)['source'] = 'projected';
      expect(arguments.optionalObject('metadata'), {'source': 'test'});
      expect(() => arguments.requireString('missing'), throwsMcpToolException);
      expect(() => arguments.optionalInt('name'), throwsMcpToolException);
      expect(
        () => McpToolArguments({'unsupported': Object()}),
        throwsArgumentError,
      );
    });

    test('definitions require strict schemas and complete metadata', () {
      expect(
        () => _definition(inputSchema: JsonSchema.object()),
        throwsArgumentError,
      );
      for (final openNestedSchema in [
        JsonSchema.object(
          properties: {'nested': JsonSchema.object()},
          additionalProperties: false,
        ),
        JsonSchema.object(
          properties: {
            'nested': JsonSchema.array(items: JsonSchema.object()),
          },
          additionalProperties: false,
        ),
        JsonSchema.object(
          properties: {
            'nested': JsonSchema.oneOf([
              JsonSchema.string(),
              JsonSchema.object(),
            ]),
          },
          additionalProperties: false,
        ),
      ]) {
        expect(
          () => _definition(inputSchema: openNestedSchema),
          throwsArgumentError,
        );
      }
      expect(() => _definition(name: 'Invalid-name'), throwsArgumentError);
      expect(() => _definition(description: ' '), throwsArgumentError);
      expect(() => _definition(requiredScopes: const {}), throwsArgumentError);

      final scopes = {'tasks:read'};
      final definition = _definition(requiredScopes: scopes);
      scopes.add('tasks:write');
      expect(definition.requiredScopes, {'tasks:read'});
      expect(
        () => definition.requiredScopes.add('tasks:delete'),
        throwsUnsupportedError,
      );
    });

    test('typed access failures project to a structured tool error', () async {
      final tool = McpToolDefinition(
        name: 'whph_contract_echo',
        description: 'Returns the supplied value.',
        inputSchema: JsonSchema.object(
          properties: {'value': JsonSchema.string()},
          required: ['value'],
          additionalProperties: false,
        ),
        outputSchema: JsonSchema.object(
          properties: {'value': JsonSchema.string()},
          required: ['value'],
          additionalProperties: false,
        ),
        annotations: const ToolAnnotations(
          readOnlyHint: true,
          destructiveHint: false,
          idempotentHint: true,
          openWorldHint: false,
        ),
        requiredScopes: const {'tasks:read'},
        handler: (arguments, extra) => McpToolResult.success({
          'value': arguments.requireString('value'),
        }),
      );
      final server = McpServer(
        const Implementation(name: 'whph-test', version: '1.0.0'),
      );
      final registration = tool.registerWith(server);
      final callback = (registration.callback! as FunctionToolCallback).function;

      final result = await callback(
        {'value': 42},
        _requestExtra(),
      );

      expect(result.isError, isTrue);
      expect(result.structuredContent, {
        'error': {
          'code': 'validation_error',
          'message': 'Argument "value" must be a string.',
          'details': {'field': 'value'},
        },
      });
    });

    test('error codes and JSON projection are stable', () {
      final error = McpToolError(
        code: McpToolErrorCode.conflict,
        message: 'The record changed.',
        details: {'revision': 4},
      );

      final result = McpToolResult.failure(error);

      expect(result.isError, isTrue);
      expect(result.structuredContent, {
        'error': {
          'code': 'conflict',
          'message': 'The record changed.',
          'details': {'revision': 4},
        },
      });
    });

    test('unexpected failures do not expose internal details', () async {
      final tool = _echoTool(
        handler: (arguments, extra) => throw StateError('database /private/user.db failed'),
      );
      final server = McpServer(
        const Implementation(name: 'whph-test', version: '1.0.0'),
      );
      final registration = tool.registerWith(server);
      final callback = (registration.callback! as FunctionToolCallback).function;

      final result = await callback({'value': 'Ada'}, _requestExtra());

      expect(result.isError, isTrue);
      expect(result.toJson().toString(), isNot(contains('/private')));
      expect(result.structuredContent, {
        'error': {
          'code': 'operation_failed',
          'message': 'The operation failed.',
        },
      });
    });
  });

  test('factory supports modern and legacy protocol versions', () {
    final server = createMcpServer(
      serverInfo: const Implementation(name: 'whph-test', version: '1.0.0'),
    );

    expect(McpProtocol.stable.supportedVersions, contains(stableProtocolVersion));
    expect(
      McpProtocol.stable.supportedVersions,
      contains(latestInitializationProtocolVersion),
    );
    expect(server.server.getCapabilities().toJson(), isEmpty);
  });

  group('real Streamable HTTP contract', () {
    for (final protocol in [McpProtocol.stable, McpProtocol.legacy]) {
      test('${protocol.name} lists and calls a schema-backed tool', () async {
        final server = await _startHttpServer(() => _echoTool());
        final client = McpClient(
          const Implementation(name: 'whph-test-client', version: '1.0.0'),
          options: McpClientOptions(protocol: protocol),
        );
        final transport = StreamableHttpClientTransport(
          Uri.parse('http://127.0.0.1:${server.boundPort}/mcp'),
        );
        addTearDown(client.close);
        addTearDown(server.stop);

        await client.connect(transport);
        final tools = await client.listTools();
        final result = await client.callTool(
          const CallToolRequest(
            name: 'whph_contract_echo',
            arguments: {'value': 'Ada'},
          ),
        );

        expect(tools.tools.single.name, 'whph_contract_echo');
        expect(tools.tools.single.annotations?.readOnlyHint, isTrue);
        expect(result.isError, isFalse);
        expect(result.structuredContent, {'value': 'Ada'});
        stdout.writeln(
          'HTTP_PROOF ${jsonEncode({
                'profile': protocol.name,
                'negotiatedProtocol': client.getProtocolVersion(),
                'request': {
                  'method': Method.toolsCall,
                  'name': 'whph_contract_echo',
                  'arguments': {'value': 'Ada'},
                },
                'response': result.toJson(),
              })}',
        );
      });
    }

    test('schema rejects unknown fields before invoking the handler', () async {
      var invocationCount = 0;
      final server = await _startHttpServer(
        () => _echoTool(
          handler: (arguments, extra) {
            invocationCount++;
            return McpToolResult.success({'value': 'unexpected'});
          },
        ),
      );
      final client = McpClient(
        const Implementation(name: 'whph-test-client', version: '1.0.0'),
      );
      final transport = StreamableHttpClientTransport(
        Uri.parse('http://127.0.0.1:${server.boundPort}/mcp'),
      );
      addTearDown(client.close);
      addTearDown(server.stop);

      await client.connect(transport);
      final result = await client.callTool(
        const CallToolRequest(
          name: 'whph_contract_echo',
          arguments: {'value': 'Ada', 'unexpected': true},
        ),
      );

      expect(result.isError, isTrue);
      expect(invocationCount, 0);
      stdout.writeln(
        'FAILURE_PROOF ${jsonEncode({
              'scenario': 'additionalProperties',
              'isError': result.isError,
              'handlerInvocations': invocationCount,
            })}',
      );
    });

    test('unsupported protocol and malformed envelope are rejected', () async {
      final server = await _startHttpServer(() => _echoTool());
      addTearDown(server.stop);
      final endpoint = Uri.parse(
        'http://127.0.0.1:${server.boundPort}/mcp',
      );

      final unsupported = await _postRaw(
        endpoint,
        body: jsonEncode({
          'jsonrpc': jsonRpcVersion,
          'id': 'unsupported',
          'method': Method.ping,
        }),
        protocolVersion: '1900-01-01',
      );
      final malformed = await _postRaw(
        endpoint,
        body: '{not-json',
        protocolVersion: stableProtocolVersion,
        method: Method.toolsList,
      );

      expect(unsupported.statusCode, HttpStatus.badRequest);
      expect(unsupported.body, contains('Unsupported protocol version'));
      expect(malformed.statusCode, HttpStatus.badRequest);
      stdout.writeln(
        'FAILURE_PROOF ${jsonEncode({
              'scenario': 'invalidProtocolAndEnvelope',
              'unsupportedStatus': unsupported.statusCode,
              'unsupportedResponse': jsonDecode(unsupported.body),
              'malformedStatus': malformed.statusCode,
              'malformedResponse': jsonDecode(malformed.body),
            })}',
      );
    });
  });
}

Future<StreamableMcpServer> _startHttpServer(
  McpToolDefinition Function() toolFactory,
) async {
  final server = StreamableMcpServer(
    serverFactory: (_) => createMcpServer(
      serverInfo: const Implementation(name: 'whph-test', version: '1.0.0'),
      tools: [toolFactory()],
    ),
    host: '127.0.0.1',
    port: 0,
    allowedHosts: const {'127.0.0.1', 'localhost'},
  );
  await server.start();
  return server;
}

Future<({int statusCode, String body})> _postRaw(
  Uri endpoint, {
  required String body,
  required String protocolVersion,
  String? method,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(endpoint);
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream')
      ..set('MCP-Protocol-Version', protocolVersion);
    if (method != null) request.headers.set('Mcp-Method', method);
    request.write(body);
    final response = await request.close();
    return (
      statusCode: response.statusCode,
      body: await utf8.decodeStream(response),
    );
  } finally {
    client.close(force: true);
  }
}

McpToolDefinition _echoTool({McpToolHandler? handler}) => McpToolDefinition(
      name: 'whph_contract_echo',
      description: 'Returns the supplied value.',
      inputSchema: JsonSchema.object(
        properties: {'value': JsonSchema.string()},
        required: ['value'],
        additionalProperties: false,
      ),
      outputSchema: JsonSchema.object(
        properties: {'value': JsonSchema.string()},
        required: ['value'],
        additionalProperties: false,
      ),
      annotations: const ToolAnnotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      ),
      requiredScopes: const {'tasks:read'},
      handler: handler ??
          (arguments, extra) => McpToolResult.success({
                'value': arguments.requireString('value'),
              }),
    );

McpToolDefinition _definition({
  String name = 'whph_contract_echo',
  String description = 'Returns the supplied value.',
  JsonObject? inputSchema,
  Set<String> requiredScopes = const {'tasks:read'},
}) =>
    McpToolDefinition(
      name: name,
      description: description,
      inputSchema: inputSchema ??
          JsonSchema.object(
            properties: {'value': JsonSchema.string()},
            required: ['value'],
            additionalProperties: false,
          ),
      outputSchema: JsonSchema.object(
        properties: {'value': JsonSchema.string()},
        required: ['value'],
        additionalProperties: false,
      ),
      annotations: const ToolAnnotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      ),
      requiredScopes: requiredScopes,
      handler: (arguments, extra) => McpToolResult.success({
        'value': arguments.requireString('value'),
      }),
    );

final throwsMcpToolException = throwsA(isA<McpToolException>());

RequestHandlerExtra _requestExtra() => RequestHandlerExtra(
      signal: BasicAbortController().signal,
      requestId: 'contract-test',
      sendNotification: (notification, {relatedTask}) async {},
      sendRequest: <T extends BaseResultData>(
        request,
        resultFactory,
        options,
      ) async =>
          resultFactory(const {}),
    );
