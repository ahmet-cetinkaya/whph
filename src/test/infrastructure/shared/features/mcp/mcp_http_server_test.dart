import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_service.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_access_store.dart';
import 'package:whph/infrastructure/shared/features/mcp/mcp_server_service.dart';
import 'package:whph/presentation/mcp/mcp_server_factory.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_definition.dart';
import 'package:whph/presentation/mcp/models/mcp_tool_result.dart';

const _tokenA = 'test-token-a';
const _tokenB = 'test-token-b';
const _readScope = McpScopes.tasksRead;

void main() {
  group('authenticated MCP HTTP server', () {
    late _FakeAccessService access;

    setUp(() {
      access = _FakeAccessService();
    });

    tearDown(() => access.dispose());

    for (final protocol in [McpProtocol.stable, McpProtocol.legacy]) {
      test('${protocol.name} discovers and calls tools over a real socket', () async {
        final service = await _startService(access);
        final client = await _client(service, _tokenA, protocol: protocol);
        addTearDown(client.close);
        addTearDown(service.stop);

        final tools = await client.listTools();
        final result = await client.callTool(
          const CallToolRequest(
            name: 'whph_test_identity',
            arguments: {},
          ),
        );

        expect(tools.tools.map((tool) => tool.name), ['whph_test_identity']);
        expect(result.structuredContent, {'client': 'client-a'});
        expect(service.endpoint?.host, InternetAddress.loopbackIPv4.address);
        expect(service.boundPort, greaterThan(0));
      });
    }

    test('scopes discovery and keeps concurrent request grants isolated', () async {
      final entered = StreamController<String>();
      final release = Completer<void>();
      final service = await _startService(
        access,
        toolFactory: (grant) => _identityTool(
          grant,
          onCall: () async {
            entered.add(grant.id);
            await release.future;
          },
        ),
      );
      final clientA = await _client(service, _tokenA);
      final clientB = await _client(service, _tokenB);
      addTearDown(entered.close);
      addTearDown(clientA.close);
      addTearDown(clientB.close);
      addTearDown(service.stop);

      final first = clientA.callTool(
        const CallToolRequest(name: 'whph_test_identity', arguments: {}),
      );
      final second = clientB.callTool(
        const CallToolRequest(name: 'whph_test_identity', arguments: {}),
      );
      expect(await entered.stream.take(2).toList(), unorderedEquals(['a', 'b']));
      release.complete();

      expect((await first).structuredContent, {'client': 'client-a'});
      expect((await second).structuredContent, {'client': 'client-b'});
    });

    test('rejects missing auth, query tokens, wrong Host, and wrong Origin', () async {
      final service = await _startService(access);
      addTearDown(service.stop);
      final body = _modernRequest('host-origin', Method.toolsList);

      final missing = await _post(service, body: body);
      final queryToken = await _post(
        service,
        body: body,
        path: '/mcp?access_token=$_tokenA',
      );
      final wrongHost = await _post(
        service,
        body: body,
        token: _tokenA,
        host: 'attacker.invalid',
      );
      final wrongOrigin = await _post(
        service,
        body: body,
        token: _tokenA,
        origin: 'https://attacker.invalid',
      );

      expect(missing.statusCode, HttpStatus.unauthorized);
      expect(queryToken.statusCode, HttpStatus.forbidden);
      expect(wrongHost.statusCode, HttpStatus.forbidden);
      expect(wrongOrigin.statusCode, HttpStatus.forbidden);
      expect(wrongOrigin.headers['access-control-allow-origin'], isNull);
    });

    test('real curl process reaches the authenticated modern endpoint', () async {
      final service = await _startService(access);
      addTearDown(service.stop);
      final requestBody = _modernRequest('curl', Method.toolsList);
      final curl = await Process.start(
        'curl',
        ['--silent', '--show-error', '--config', '-'],
      );
      curl.stdin.write('''
url = "${service.endpoint}"
request = "POST"
header = "Authorization: Bearer $_tokenA"
header = "Content-Type: application/json"
header = "Accept: application/json, text/event-stream"
header = "MCP-Protocol-Version: $stableProtocolVersion"
header = "Mcp-Method: ${Method.toolsList}"
data = "${requestBody.replaceAll('"', r'\"')}"
write-out = "\\n%{http_code}"
''');
      await curl.stdin.close();
      final output = await utf8.decodeStream(curl.stdout);
      final error = await utf8.decodeStream(curl.stderr);
      final exitCode = await curl.exitCode;

      expect(exitCode, 0, reason: error);
      expect(output, contains('whph_test_identity'));
      expect(output.trimRight(), endsWith('200'));
      expect(output, isNot(contains(_tokenA)));
    });

    test('uses the durable access service for authentication and revocation', () async {
      final directory = await _createApplicationDirectory('whph_mcp_http_');
      final realAccess = McpAccessService(
        store: McpAccessStore(
          applicationDirectoryService: _TestApplicationDirectoryService(directory),
        ),
      );
      addTearDown(realAccess.dispose);
      addTearDown(() => directory.delete(recursive: true));
      final issued = await realAccess.createGrant(
        clientName: 'durable-client',
        scopes: const {_readScope},
      );
      final service = _service(realAccess);
      await service.start(port: 0);
      addTearDown(service.stop);
      final client = await _client(service, issued.token);
      addTearDown(client.close);

      final result = await client.callTool(
        const CallToolRequest(name: 'whph_test_identity', arguments: {}),
      );
      expect(result.structuredContent, {'client': 'durable-client'});

      await realAccess.revokeGrant(issued.grant.id);
      final rejected = await _post(
        service,
        token: issued.token,
        body: _modernRequest('durable-revoked', Method.toolsList),
      );
      expect(rejected.statusCode, HttpStatus.unauthorized);
    });

    test('caps legacy sessions per grant', () async {
      final service = await _startService(
        access,
        maximumLegacySessionsPerGrant: 2,
      );
      addTearDown(service.stop);
      final first = await _client(
        service,
        _tokenA,
        protocol: McpProtocol.legacy,
      );
      final second = await _client(
        service,
        _tokenA,
        protocol: McpProtocol.legacy,
      );
      addTearDown(first.close);
      addTearDown(second.close);

      await first.listTools();
      await second.listTools();
      final limited = await _post(
        service,
        token: _tokenA,
        protocolVersion: latestInitializationProtocolVersion,
        body: _legacyInitializeRequest('limited'),
      );

      expect(limited.statusCode, HttpStatus.tooManyRequests);
    });

    test('expires stale legacy sessions before admitting a fresh session', () async {
      var now = DateTime.utc(2026, 9, 8);
      final service = await _startService(
        access,
        maximumLegacySessionsPerGrant: 1,
        legacySessionIdleTimeout: const Duration(minutes: 1),
        now: () => now,
      );
      addTearDown(service.stop);
      final staleClient = await _client(
        service,
        _tokenA,
        protocol: McpProtocol.legacy,
      );
      addTearDown(staleClient.close);
      await staleClient.listTools();
      final staleSessionId = _transport(staleClient).sessionId!;
      now = now.add(const Duration(minutes: 1));

      final stale = await _post(
        service,
        token: _tokenA,
        sessionId: staleSessionId,
        protocolVersion: latestInitializationProtocolVersion,
        body: jsonEncode({
          'jsonrpc': jsonRpcVersion,
          'id': 'stale',
          'method': Method.ping,
        }),
      );
      final fresh = await _post(
        service,
        token: _tokenA,
        protocolVersion: latestInitializationProtocolVersion,
        body: _legacyInitializeRequest('fresh'),
      );

      expect(stale.statusCode, HttpStatus.notFound);
      expect(fresh.statusCode, HttpStatus.ok);
      expect(fresh.headers['mcp-session-id'], isNotNull);
    });

    test('binds a legacy session to the grant that initialized it', () async {
      final service = await _startService(access);
      final ownerClient = await _client(
        service,
        _tokenA,
        protocol: McpProtocol.legacy,
      );
      addTearDown(service.stop);
      await ownerClient.listTools();
      final sessionId = _transport(ownerClient).sessionId;
      expect(sessionId, isNotNull);

      final stolen = await _post(
        service,
        token: _tokenB,
        sessionId: sessionId,
        protocolVersion: latestInitializationProtocolVersion,
        body: jsonEncode({
          'jsonrpc': jsonRpcVersion,
          'id': 'stolen',
          'method': Method.ping,
        }),
      );

      expect(stolen.statusCode, HttpStatus.notFound);
      expect(stolen.body, isNot(contains('client-a')));
    });

    test('revocation closes a legacy stream and rejects later calls', () async {
      final service = await _startService(access);
      addTearDown(service.stop);
      final httpClient = HttpClient();
      addTearDown(() => httpClient.close(force: true));
      final initialize = await httpClient.postUrl(service.endpoint!);
      initialize.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $_tokenA')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
      initialize.write(jsonEncode({
        'jsonrpc': jsonRpcVersion,
        'id': 'initialize',
        'method': Method.initialize,
        'params': {
          'protocolVersion': latestInitializationProtocolVersion,
          'capabilities': <String, Object?>{},
          'clientInfo': {'name': 'socket-test', 'version': '1.0'},
        },
      }));
      final initialized = await initialize.close();
      final sessionId = initialized.headers.value('mcp-session-id')!;
      await initialized.drain<void>();
      Future<HttpClientResponse> openStream() async {
        final request = await httpClient.getUrl(service.endpoint!);
        request.headers
          ..set(HttpHeaders.authorizationHeader, 'Bearer $_tokenA')
          ..set(HttpHeaders.acceptHeader, 'text/event-stream')
          ..set('mcp-session-id', sessionId)
          ..set('mcp-protocol-version', latestInitializationProtocolVersion);
        return request.close();
      }

      final responses = List.generate(4, (_) => openStream());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final fifth = await openStream().timeout(const Duration(seconds: 1));
      expect(fifth.statusCode, HttpStatus.tooManyRequests);
      expect(fifth.headers.value(HttpHeaders.retryAfterHeader), '60');
      await fifth.drain<void>();

      await access.revoke('a');
      final closedResponses = await Future.wait(responses).timeout(const Duration(seconds: 2));
      expect(closedResponses.map((response) => response.statusCode), everyElement(HttpStatus.ok));
      await Future.wait(closedResponses.map((response) => response.drain<void>())).timeout(const Duration(seconds: 2));
      final rejected = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('revoked', Method.toolsList),
      );

      expect(rejected.statusCode, HttpStatus.unauthorized);
    });

    test('rejects oversized chunked bodies while streaming them', () async {
      final service = await _startService(access, maximumBodyBytes: 64);
      addTearDown(service.stop);
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.postUrl(service.endpoint!);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $_tokenA')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
      request.add(utf8.encode('{"padding":"'));
      request.add(List<int>.filled(80, 65));
      request.add(utf8.encode('"}'));
      expect(request.contentLength, -1);

      final response = await request.close();
      await response.drain<void>();

      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
    });

    test('rate-limits invalid bearer authentication before access lookup', () async {
      final service = await _startService(
        access,
        maximumRequestsPerMinute: 2,
      );
      addTearDown(service.stop);

      final firstValid = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('valid-1', Method.toolsList),
      );
      final secondValid = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('valid-2', Method.toolsList),
      );
      expect(firstValid.statusCode, HttpStatus.ok);
      expect(secondValid.statusCode, HttpStatus.ok);

      final firstInvalid =
          await _post(service, token: 'invalid-token-1', body: _modernRequest('invalid-1', Method.toolsList));
      final secondInvalid =
          await _post(service, token: 'invalid-token-2', body: _modernRequest('invalid-2', Method.toolsList));
      final limitedInvalid =
          await _post(service, token: 'invalid-token-3', body: _modernRequest('invalid-3', Method.toolsList));

      expect(firstInvalid.statusCode, HttpStatus.unauthorized);
      expect(secondInvalid.statusCode, HttpStatus.unauthorized);
      expect(limitedInvalid.statusCode, HttpStatus.tooManyRequests);
      expect(access.authenticationCallCount, 4);
    });

    test('limits anonymous rate and per-grant concurrency with Retry-After', () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final service = await _startService(
        access,
        maximumRequestsPerMinute: 2,
        maximumConcurrentRequestsPerGrant: 1,
        toolFactory: (grant) => _identityTool(
          grant,
          onCall: () async {
            if (!entered.isCompleted) entered.complete();
            await release.future;
          },
        ),
      );
      addTearDown(service.stop);
      final firstAnonymous = await _post(service, body: '{}');
      final secondAnonymous = await _post(service, body: '{}');
      final limitedAnonymous = await _post(service, body: '{}');
      expect(firstAnonymous.statusCode, HttpStatus.unauthorized);
      expect(secondAnonymous.statusCode, HttpStatus.unauthorized);
      expect(limitedAnonymous.statusCode, HttpStatus.tooManyRequests);
      expect(limitedAnonymous.headers['retry-after'], ['60']);
      final limitedOptions = await _request(service, method: 'OPTIONS');
      expect(limitedOptions.statusCode, HttpStatus.tooManyRequests);
      expect(limitedOptions.headers['retry-after'], ['60']);
      final grantRateAccess = _FakeAccessService();
      addTearDown(grantRateAccess.dispose);
      final grantRateService = await _startService(
        grantRateAccess,
        maximumRequestsPerMinute: 2,
      );
      addTearDown(grantRateService.stop);
      final firstGrant = await _post(
        grantRateService,
        token: _tokenA,
        body: _modernRequest('grant-1', Method.toolsList),
      );
      final secondGrant = await _post(
        grantRateService,
        token: _tokenA,
        body: _modernRequest('grant-2', Method.toolsList),
      );
      final limitedGrant = await _post(
        grantRateService,
        token: _tokenA,
        body: _modernRequest('grant-3', Method.toolsList),
      );
      expect(firstGrant.statusCode, HttpStatus.ok);
      expect(secondGrant.statusCode, HttpStatus.ok);
      expect(limitedGrant.statusCode, HttpStatus.tooManyRequests);
      expect(limitedGrant.headers['retry-after'], ['60']);

      final separateAccess = _FakeAccessService();
      addTearDown(separateAccess.dispose);
      final concurrencyService = await _startService(
        separateAccess,
        maximumConcurrentRequestsPerGrant: 1,
        toolFactory: (grant) => _identityTool(
          grant,
          onCall: () async {
            if (!entered.isCompleted) entered.complete();
            await release.future;
          },
        ),
      );
      addTearDown(concurrencyService.stop);
      final client = await _client(concurrencyService, _tokenA);
      addTearDown(client.close);
      final pending = client.callTool(
        const CallToolRequest(name: 'whph_test_identity', arguments: {}),
      );
      await entered.future;
      final limitedConcurrent = await _post(
        concurrencyService,
        token: _tokenA,
        body: _modernRequest('concurrent', Method.toolsList),
      );
      expect(limitedConcurrent.statusCode, HttpStatus.tooManyRequests);
      expect(limitedConcurrent.headers['retry-after'], ['60']);
      release.complete();
      await pending;
    });

    test('fresh authorization isolates cancellation and enforces deadline', () async {
      final entered = StreamController<String>();
      final observed = StreamController<(String, bool)>();
      final release = Completer<void>();
      late McpServerService service;
      service = McpServerService(
        accessService: access,
        restoreBarrier: McpRestoreBarrier(),
        allowEphemeralPort: true,
        serverBuilder: (grant, authorize, runInvocation) {
          final registry = McpToolRegistry(
            tools: [
              _authorizationTool(() async {
                entered.add(grant.id);
                await release.future;
                final authorized = await service.isAuthorized({_readScope});
                observed.add((grant.id, authorized));
                return authorized;
              }),
            ],
            authorize: authorize,
            runInvocation: runInvocation,
          );
          return createMcpServer(
            serverInfo: const Implementation(name: 'whph-test', version: '1.0'),
            tools: registry.discover(grant.scopes),
          );
        },
      );
      await service.start(port: 0);
      final clientA = await _client(
        service,
        _tokenA,
        protocol: McpProtocol.legacy,
      );
      final clientB = await _client(
        service,
        _tokenB,
        protocol: McpProtocol.legacy,
      );
      final abortA = BasicAbortController();
      addTearDown(entered.close);
      addTearDown(observed.close);
      addTearDown(clientA.close);
      addTearDown(clientB.close);
      addTearDown(service.stop);

      final callA = clientA.callTool(
        const CallToolRequest(name: 'whph_test_authorization', arguments: {}),
        options: RequestOptions(signal: abortA.signal),
      );
      final callB = clientB.callTool(
        const CallToolRequest(name: 'whph_test_authorization', arguments: {}),
      );
      final callAAborted = expectLater(callA, throwsA(anything));
      expect(await entered.stream.take(2).toList(), unorderedEquals(['a', 'b']));
      abortA.abort('test cancellation');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      release.complete();
      expect(
        await observed.stream.take(2).toList(),
        unorderedEquals([('a', false), ('b', true)]),
      );
      await callAAborted;
      expect((await callB).structuredContent, {'authorized': true});

      var now = DateTime.utc(2026, 9, 8);
      late McpServerService deadlineService;
      deadlineService = McpServerService(
        accessService: access,
        restoreBarrier: McpRestoreBarrier(),
        allowEphemeralPort: true,
        now: () => now,
        serverBuilder: (grant, authorize, runInvocation) {
          final registry = McpToolRegistry(
            tools: [
              _authorizationTool(() async {
                now = now.add(const Duration(seconds: 121));
                return deadlineService.isAuthorized({_readScope});
              }),
            ],
            authorize: authorize,
            runInvocation: runInvocation,
          );
          return createMcpServer(
            serverInfo: const Implementation(name: 'whph-test', version: '1.0'),
            tools: registry.discover(grant.scopes),
          );
        },
      );
      await deadlineService.start(port: 0);
      final deadlineClient = await _client(deadlineService, _tokenA);
      addTearDown(deadlineClient.close);
      addTearDown(deadlineService.stop);
      final deadlineResult = await deadlineClient.callTool(
        const CallToolRequest(name: 'whph_test_authorization', arguments: {}),
      );
      expect(deadlineResult.structuredContent, {'authorized': false});
    });

    test('cancellation during fresh authentication never invokes the tool', () async {
      var handlerInvoked = false;
      final service = await _startService(
        access,
        toolFactory: (grant) => _identityTool(
          grant,
          onCall: () async => handlerInvoked = true,
        ),
      );
      final client = await _client(
        service,
        _tokenA,
        protocol: McpProtocol.legacy,
      );
      final authenticationEntered = Completer<void>();
      final releaseAuthentication = Completer<void>();
      access.beforeScopedAuthentication = () async {
        if (!authenticationEntered.isCompleted) authenticationEntered.complete();
        await releaseAuthentication.future;
      };
      final abort = BasicAbortController();
      addTearDown(client.close);
      addTearDown(service.stop);

      final call = client.callTool(
        const CallToolRequest(name: 'whph_test_identity', arguments: {}),
        options: RequestOptions(signal: abort.signal),
      );
      final rejected = expectLater(call, throwsA(anything));
      await authenticationEntered.future.timeout(const Duration(seconds: 1));
      abort.abort('cancel during authentication');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      releaseAuthentication.complete();

      await rejected;
      expect(handlerInvoked, isFalse);
    });

    test('normal calls expire at 30 seconds while data calls retain 120 seconds', () async {
      var now = DateTime.utc(2026, 9, 8);
      late McpServerService service;
      service = McpServerService(
        accessService: access,
        restoreBarrier: McpRestoreBarrier(),
        allowEphemeralPort: true,
        now: () => now,
        serverBuilder: (grant, authorize, runInvocation) {
          final registry = McpToolRegistry(
            tools: [
              _authorizationTool(
                () async {
                  now = now.add(const Duration(seconds: 31));
                  return service.isAuthorized({_readScope});
                },
                name: 'whph_test_normal_read',
              ),
              _authorizationTool(
                () async {
                  now = now.add(const Duration(seconds: 31));
                  return service.isAuthorized({_readScope});
                },
                name: 'whph_data_test_transfer',
              ),
            ],
            authorize: authorize,
            runInvocation: runInvocation,
          );
          return createMcpServer(
            serverInfo: const Implementation(name: 'whph-test', version: '1.0'),
            tools: registry.discover(grant.scopes),
          );
        },
      );
      await service.start(port: 0);
      final client = await _client(service, _tokenA);
      addTearDown(client.close);
      addTearDown(service.stop);

      final normal = await client.callTool(
        const CallToolRequest(name: 'whph_test_normal_read', arguments: {}),
      );
      final transfer = await client.callTool(
        const CallToolRequest(name: 'whph_data_test_transfer', arguments: {}),
      );

      expect(normal.structuredContent, {'authorized': false});
      expect(transfer.structuredContent, {'authorized': true});
    });

    test('timeout closes the request socket and releases its grant slot', () async {
      final entered = Completer<void>();
      final releaseHandler = Completer<void>();
      final lateAuthorization = Completer<bool>();
      late McpServerService service;
      service = McpServerService(
        accessService: access,
        restoreBarrier: McpRestoreBarrier(),
        allowEphemeralPort: true,
        maximumConcurrentRequestsPerGrant: 1,
        operationTimeout: const Duration(milliseconds: 100),
        extendedOperationTimeout: const Duration(milliseconds: 500),
        serverBuilder: (grant, authorize, runInvocation) {
          final registry = McpToolRegistry(
            tools: [
              _authorizationTool(() async {
                entered.complete();
                await releaseHandler.future;
                final authorized = await service.isAuthorized({_readScope});
                lateAuthorization.complete(authorized);
                return authorized;
              }),
            ],
            authorize: authorize,
            runInvocation: runInvocation,
          );
          return createMcpServer(
            serverInfo: const Implementation(name: 'whph-test', version: '1.0'),
            tools: registry.discover(grant.scopes),
          );
        },
      );
      await service.start(port: 0);
      addTearDown(service.stop);
      final client = await _client(service, _tokenA);
      addTearDown(client.close);

      final call = client.callTool(
        const CallToolRequest(
          name: 'whph_test_authorization',
          arguments: {},
        ),
      );
      await entered.future.timeout(const Duration(seconds: 1));
      final during = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('during-timeout', Method.toolsList),
      );
      expect(during.statusCode, HttpStatus.tooManyRequests);

      await expectLater(call, throwsA(anything));
      final timedOutButUnsettled = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('timed-out-unsettled', Method.toolsList),
      );
      expect(timedOutButUnsettled.statusCode, HttpStatus.tooManyRequests);
      releaseHandler.complete();
      expect(
        await lateAuthorization.future.timeout(const Duration(seconds: 1)),
        isFalse,
      );
      final after = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('after-timeout', Method.toolsList),
      );
      expect(after.statusCode, HttpStatus.ok);
    });

    test('permanently stuck handler releases the grant slot after the abandon grace', () async {
      final entered = Completer<void>();
      final service = McpServerService(
        accessService: access,
        restoreBarrier: McpRestoreBarrier(),
        allowEphemeralPort: true,
        maximumConcurrentRequestsPerGrant: 1,
        operationTimeout: const Duration(milliseconds: 100),
        operationAbandonGrace: const Duration(milliseconds: 150),
        serverBuilder: (grant, authorize, runInvocation) {
          final registry = McpToolRegistry(
            tools: [
              _identityTool(
                grant,
                onCall: () async {
                  entered.complete();
                  await Completer<void>().future; // Never settles.
                },
              ),
            ],
            authorize: authorize,
            runInvocation: runInvocation,
          );
          return createMcpServer(
            serverInfo: const Implementation(name: 'whph-test', version: '1.0'),
            tools: registry.discover(grant.scopes),
          );
        },
      );
      await service.start(port: 0);
      addTearDown(service.stop);
      final client = await _client(service, _tokenA);
      addTearDown(client.close);

      final call = client.callTool(
        const CallToolRequest(name: 'whph_test_identity', arguments: {}),
      );
      await entered.future.timeout(const Duration(seconds: 1));
      final during = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('during-stuck', Method.toolsList),
      );
      expect(during.statusCode, HttpStatus.tooManyRequests);
      await expectLater(call, throwsA(anything));
      // The abort surfaces on the client before the grace window elapses;
      // wait past timeout + grace so the tail has released the slot even
      // though the handler never settles.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final after = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('after-stuck', Method.toolsList),
      );
      expect(after.statusCode, HttpStatus.ok);
    });

    test('peer disconnect holds admission until its handler settles', () async {
      final entered = Completer<void>();
      final releaseHandler = Completer<void>();
      final handlerSettled = Completer<void>();
      final service = await _startService(
        access,
        maximumConcurrentRequestsPerGrant: 1,
        toolFactory: (grant) => _identityTool(
          grant,
          onCall: () async {
            entered.complete();
            await releaseHandler.future;
            handlerSettled.complete();
          },
        ),
      );
      addTearDown(service.stop);
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        service.boundPort!,
      );
      final body = jsonEncode({
        'jsonrpc': jsonRpcVersion,
        'id': 'disconnect',
        'method': Method.toolsCall,
        'params': {
          'name': 'whph_test_identity',
          'arguments': <String, Object?>{},
          '_meta': {
            McpMetaKey.protocolVersion: stableProtocolVersion,
            McpMetaKey.clientInfo: {'name': 'raw-test', 'version': '1.0'},
            McpMetaKey.clientCapabilities: <String, Object?>{},
          },
        },
      });
      socket.write(
        'POST /mcp HTTP/1.1\r\n'
        'Host: 127.0.0.1:${service.boundPort}\r\n'
        'Authorization: Bearer $_tokenA\r\n'
        'Content-Type: application/json\r\n'
        'Accept: application/json, text/event-stream\r\n'
        'MCP-Protocol-Version: $stableProtocolVersion\r\n'
        'Mcp-Method: ${Method.toolsCall}\r\n'
        'Mcp-Name: whph_test_identity\r\n'
        'Content-Length: ${utf8.encode(body).length}\r\n'
        'Connection: close\r\n\r\n'
        '$body',
      );
      await socket.flush();
      await entered.future.timeout(const Duration(seconds: 1));
      socket.destroy();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final whileUnsettled = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('disconnect-unsettled', Method.toolsList),
      );
      expect(whileUnsettled.statusCode, HttpStatus.tooManyRequests);
      releaseHandler.complete();
      await handlerSettled.future;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final afterSettlement = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('disconnect-settled', Method.toolsList),
      );
      expect(afterSettlement.statusCode, HttpStatus.ok);
    });

    test('restore admits only authenticated operation status calls', () async {
      final barrier = McpRestoreBarrier();
      final service = McpServerService(
        accessService: access,
        restoreBarrier: barrier,
        allowEphemeralPort: true,
        serverBuilder: (grant, authorize, runInvocation) {
          final registry = McpToolRegistry(
            tools: [
              _authorizationTool(
                () async => true,
                name: 'whph_operations_get',
              ),
              _identityTool(grant),
            ],
            authorize: authorize,
            runInvocation: runInvocation,
          );
          return createMcpServer(
            serverInfo: const Implementation(name: 'whph-test', version: '1.0'),
            tools: registry.discover(grant.scopes),
          );
        },
      );
      await service.start(port: 0);
      addTearDown(service.stop);
      final client = await _client(service, _tokenA);
      addTearDown(client.close);
      final restoreEntered = Completer<void>();
      final releaseRestore = Completer<void>();
      final restore = barrier.runExclusive(() async {
        restoreEntered.complete();
        await releaseRestore.future;
      });
      addTearDown(() async {
        if (!releaseRestore.isCompleted) releaseRestore.complete();
        await restore;
      });
      await restoreEntered.future;

      final status = await client.callTool(
        const CallToolRequest(name: 'whph_operations_get', arguments: {}),
      );
      final discovery = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('restore-discovery', Method.toolsList),
      );
      final resource = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('restore-resource', Method.resourcesList),
      );
      final forgedStatusHeader = await _post(
        service,
        token: _tokenA,
        mcpMethod: Method.toolsCall,
        mcpName: 'whph_operations_get',
        body: _modernRequest('restore-forged', Method.toolsList),
      );
      final unauthenticated = await _post(
        service,
        body: _modernRequest('restore-no-auth', Method.toolsList),
      );

      expect(status.structuredContent, {'authorized': true});
      for (final blocked in [discovery, resource, forgedStatusHeader]) {
        expect(blocked.statusCode, HttpStatus.serviceUnavailable);
        final error = JsonRpcError.fromJson(
          jsonDecode(blocked.body) as Map<String, dynamic>,
        );
        expect(error.error.data, {'code': 'busy'});
      }
      expect(unauthenticated.statusCode, HttpStatus.unauthorized);

      await access.revoke('a');
      final revoked = await _post(
        service,
        token: _tokenA,
        body: _modernRequest('restore-revoked', Method.toolsList),
      );
      expect(revoked.statusCode, HttpStatus.unauthorized);
    });

    test('does not retain authorization after a request completes', () async {
      final staleAuthorization = Completer<bool>();
      late McpServerService service;
      service = McpServerService(
        accessService: access,
        restoreBarrier: McpRestoreBarrier(),
        allowEphemeralPort: true,
        serverBuilder: (grant, authorize, runInvocation) {
          final registry = McpToolRegistry(
            tools: [
              _authorizationTool(() async {
                unawaited(Future<void>.delayed(
                  const Duration(milliseconds: 50),
                  () async => staleAuthorization.complete(await service.isAuthorized({_readScope})),
                ));
                return true;
              }),
            ],
            authorize: authorize,
            runInvocation: runInvocation,
          );
          return createMcpServer(
            serverInfo: const Implementation(name: 'whph-test', version: '1.0'),
            tools: registry.discover(grant.scopes),
          );
        },
      );
      await service.start(port: 0);
      final client = await _client(service, _tokenA);
      addTearDown(client.close);
      addTearDown(service.stop);

      final result = await client.callTool(
        const CallToolRequest(name: 'whph_test_authorization', arguments: {}),
      );

      expect(result.structuredContent, {'authorized': true});
      expect(await staleAuthorization.future, isFalse);
    });

    test('reports port collisions and supports awaited stop then restart', () async {
      final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(occupied.close);
      final service = _service(access);
      addTearDown(service.stop);

      await expectLater(
        () => service.start(port: occupied.port),
        throwsA(isA<SocketException>()),
      );
      expect(service.isRunning, isFalse);

      await service.start(port: 0);
      final firstPort = service.boundPort;
      await service.stop();
      expect(service.isRunning, isFalse);
      await service.start(port: 0);
      expect(service.boundPort, greaterThan(0));
      expect(service.boundPort, isNot(firstPort));
    });
  });
}

Future<McpServerService> _startService(
  IMcpAccessService access, {
  int maximumRequestsPerMinute = 120,
  int maximumConcurrentRequestsPerGrant = 4,
  int maximumLegacySessionsPerGrant = 4,
  Duration legacySessionIdleTimeout = const Duration(minutes: 15),
  int maximumBodyBytes = 1024 * 1024,
  DateTime Function()? now,
  McpToolDefinition Function(McpAuthenticatedGrant)? toolFactory,
  IRestoreBarrier? restoreBarrier,
  Duration? operationAbandonGrace,
}) async {
  final service = _service(
    access,
    maximumRequestsPerMinute: maximumRequestsPerMinute,
    maximumConcurrentRequestsPerGrant: maximumConcurrentRequestsPerGrant,
    maximumLegacySessionsPerGrant: maximumLegacySessionsPerGrant,
    legacySessionIdleTimeout: legacySessionIdleTimeout,
    maximumBodyBytes: maximumBodyBytes,
    now: now,
    toolFactory: toolFactory,
    restoreBarrier: restoreBarrier,
    operationAbandonGrace: operationAbandonGrace,
  );
  await service.start(port: 0);
  return service;
}

McpServerService _service(
  IMcpAccessService access, {
  int maximumRequestsPerMinute = 120,
  int maximumConcurrentRequestsPerGrant = 4,
  int maximumLegacySessionsPerGrant = 4,
  Duration legacySessionIdleTimeout = const Duration(minutes: 15),
  int maximumBodyBytes = 1024 * 1024,
  DateTime Function()? now,
  McpToolDefinition Function(McpAuthenticatedGrant)? toolFactory,
  IRestoreBarrier? restoreBarrier,
  Duration? operationAbandonGrace,
}) =>
    McpServerService(
      accessService: access,
      restoreBarrier: restoreBarrier ?? McpRestoreBarrier(),
      maximumRequestsPerMinute: maximumRequestsPerMinute,
      maximumConcurrentRequestsPerGrant: maximumConcurrentRequestsPerGrant,
      maximumLegacySessionsPerGrant: maximumLegacySessionsPerGrant,
      legacySessionIdleTimeout: legacySessionIdleTimeout,
      maximumBodyBytes: maximumBodyBytes,
      now: now,
      operationAbandonGrace: operationAbandonGrace ?? const Duration(seconds: 10),
      allowEphemeralPort: true,
      serverBuilder: (grant, authorize, runInvocation) {
        final registry = McpToolRegistry(
          tools: [
            (toolFactory ?? _identityTool)(grant),
            _writeOnlyTool(),
          ],
          authorize: authorize,
          runInvocation: runInvocation,
        );
        return createMcpServer(
          serverInfo: const Implementation(name: 'whph-test', version: '1.0'),
          tools: registry.discover(grant.scopes),
        );
      },
    );

Future<McpClient> _client(
  McpServerService service,
  String token, {
  McpProtocol protocol = McpProtocol.stable,
}) async {
  final client = McpClient(
    const Implementation(name: 'socket-test', version: '1.0'),
    options: McpClientOptions(protocol: protocol),
  );
  final transport = StreamableHttpClientTransport(
    service.endpoint!,
    opts: StreamableHttpClientTransportOptions(
      requestInit: {
        'headers': {'Authorization': 'Bearer $token'},
      },
    ),
  );
  _clientTransports[client] = transport;
  await client.connect(transport);
  return client;
}

final Map<McpClient, StreamableHttpClientTransport> _clientTransports = {};

StreamableHttpClientTransport _transport(McpClient client) => _clientTransports[client]!;

McpToolDefinition _identityTool(
  McpAuthenticatedGrant grant, {
  Future<void> Function()? onCall,
}) =>
    McpToolDefinition(
      name: 'whph_test_identity',
      description: 'Returns the authenticated test identity.',
      inputSchema: JsonSchema.object(additionalProperties: false),
      outputSchema: JsonSchema.object(
        properties: {'client': JsonSchema.string()},
        required: ['client'],
        additionalProperties: false,
      ),
      annotations: const ToolAnnotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      ),
      requiredScopes: const {_readScope},
      handler: (arguments, extra) async {
        await onCall?.call();
        return McpToolResult.success({'client': grant.clientName});
      },
    );

McpToolDefinition _writeOnlyTool() => McpToolDefinition(
      name: 'whph_test_write',
      description: 'A test-only write operation.',
      inputSchema: JsonSchema.object(additionalProperties: false),
      outputSchema: JsonSchema.object(additionalProperties: false),
      annotations: const ToolAnnotations(
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      ),
      requiredScopes: const {McpScopes.tasksWrite},
      handler: (arguments, extra) => McpToolResult.success({}),
    );

McpToolDefinition _authorizationTool(
  Future<bool> Function() authorize, {
  String name = 'whph_test_authorization',
}) =>
    McpToolDefinition(
      name: name,
      description: 'Checks fresh request authorization.',
      inputSchema: JsonSchema.object(additionalProperties: false),
      outputSchema: JsonSchema.object(
        properties: {'authorized': JsonSchema.boolean()},
        required: ['authorized'],
        additionalProperties: false,
      ),
      annotations: const ToolAnnotations(
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      ),
      requiredScopes: const {_readScope},
      handler: (arguments, extra) async => McpToolResult.success({'authorized': await authorize()}),
    );

String _legacyInitializeRequest(String id) => jsonEncode({
      'jsonrpc': jsonRpcVersion,
      'id': id,
      'method': Method.initialize,
      'params': {
        'protocolVersion': latestInitializationProtocolVersion,
        'capabilities': <String, Object?>{},
        'clientInfo': {'name': 'raw-test', 'version': '1.0'},
      },
    });

String _modernRequest(String id, String method) => jsonEncode({
      'jsonrpc': jsonRpcVersion,
      'id': id,
      'method': method,
      'params': {
        '_meta': {
          McpMetaKey.protocolVersion: stableProtocolVersion,
          McpMetaKey.clientInfo: {'name': 'raw-test', 'version': '1.0'},
          McpMetaKey.clientCapabilities: <String, Object?>{},
        },
      },
    });

Future<_HttpResult> _post(
  McpServerService service, {
  required String body,
  String? token,
  String? host,
  String? origin,
  String? sessionId,
  String protocolVersion = stableProtocolVersion,
  String path = '/mcp',
  String mcpMethod = Method.toolsList,
  String? mcpName,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(service.endpoint!.replace(path: path));
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream')
      ..set('mcp-protocol-version', protocolVersion)
      ..set('mcp-method', mcpMethod);
    if (mcpName != null) request.headers.set('mcp-name', mcpName);
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (host != null) request.headers.set(HttpHeaders.hostHeader, host);
    if (origin != null) request.headers.set('origin', origin);
    if (sessionId != null) request.headers.set('mcp-session-id', sessionId);
    request.write(body);
    final response = await request.close();
    return _HttpResult(
      response.statusCode,
      await utf8.decodeStream(response),
      _headers(response.headers),
    );
  } finally {
    client.close(force: true);
  }
}

Future<_HttpResult> _request(
  McpServerService service, {
  required String method,
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, service.endpoint!);
    final response = await request.close();
    return _HttpResult(
      response.statusCode,
      await utf8.decodeStream(response),
      _headers(response.headers),
    );
  } finally {
    client.close(force: true);
  }
}

Map<String, List<String>> _headers(HttpHeaders source) {
  var headers = const <String, List<String>>{};
  source.forEach((name, values) {
    headers = Map<String, List<String>>.unmodifiable({
      ...headers,
      name: List<String>.unmodifiable(values.map((value) => value.toString())),
    });
  });
  return headers;
}

final class _HttpResult {
  const _HttpResult(this.statusCode, this.body, this.headers);

  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;
}

final class _FakeAccessService implements IMcpAccessService {
  _FakeAccessService()
      : _grants = const {
          _tokenA: ('a', 'client-a'),
          _tokenB: ('b', 'client-b'),
        };

  final StreamController<McpAccessRevocation> _revocations = StreamController.broadcast();
  Map<String, (String, String)> _grants;
  int authenticationCallCount = 0;
  Future<void> Function()? beforeScopedAuthentication;

  @override
  Stream<McpAccessRevocation> get revocations => _revocations.stream;

  @override
  Future<McpAuthenticatedGrant?> authenticate(
    String token, {
    Set<String> requiredScopes = const {},
  }) async {
    authenticationCallCount++;
    if (requiredScopes.isNotEmpty) await beforeScopedAuthentication?.call();
    final record = _grants[token];
    if (record == null || !const {_readScope}.containsAll(requiredScopes)) {
      return null;
    }
    return McpAuthenticatedGrant(
      id: record.$1,
      clientName: record.$2,
      scopes: const {_readScope},
    );
  }

  Future<void> revoke(String grantId) async {
    _grants = Map.unmodifiable({
      for (final entry in _grants.entries)
        if (entry.value.$1 != grantId) entry.key: entry.value,
    });
    _revocations.add(McpAccessRevocation(grantId: grantId));
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> dispose() => _revocations.close();

  @override
  Future<McpIssuedGrant> createGrant({required String clientName, required Set<String> scopes}) =>
      throw UnimplementedError();

  @override
  Future<McpAccessState> readState() => throw UnimplementedError();

  @override
  Future<void> revokeGrant(String grantId) => revoke(grantId);

  @override
  Future<McpIssuedGrant> rotateGrant(String grantId) => throw UnimplementedError();

  @override
  Future<void> setPreferences(McpServerPreferences preferences) => throw UnimplementedError();
}

Future<Directory> _createApplicationDirectory(String prefix) {
  final basePath = Platform.isWindows ? Platform.environment['LOCALAPPDATA']! : Directory.systemTemp.path;
  return Directory(basePath).createTemp(prefix);
}

final class _TestApplicationDirectoryService implements IApplicationDirectoryService {
  const _TestApplicationDirectoryService(this.directory);

  final Directory directory;

  @override
  Future<Directory> getApplicationDirectory() async => directory;
}
