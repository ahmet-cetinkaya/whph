import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_server_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';
import 'package:whph/presentation/mcp/mcp_tool_registry.dart';

const _mcpPath = '/mcp';
const _defaultMaximumBodyBytes = 1024 * 1024;
const _defaultMaximumRequestsPerMinute = 120;
const _defaultMaximumConcurrentRequestsPerGrant = 4;
const _requestReadTimeout = Duration(seconds: 30);
const _defaultOperationTimeout = Duration(seconds: 30);
const _defaultExtendedOperationTimeout = Duration(seconds: 120);
const _rateWindow = Duration(minutes: 1);
/// Maximum time the request tail waits for a stuck operation (an approval,
/// a stream, or an abandoned client) before releasing the grant slot so a
/// single hung invocation can never wedge the whole grant at the concurrency
/// limit (permanent 429).
const _defaultOperationAbandonGrace = Duration(seconds: 10);

typedef McpAuthenticatedServerBuilder = McpServer Function(
  McpAuthenticatedGrant grant,
  McpToolAuthorizer authorize,
  McpOperationRunner runInvocation,
);

typedef McpOperationRunner = Future<CallToolResult> Function(
  Future<CallToolResult> Function() invocation,
);

final class McpServerService implements IMcpServerService, IMcpRequestContext {
  McpServerService({
    required IMcpAccessService accessService,
    required McpAuthenticatedServerBuilder serverBuilder,
    required IRestoreBarrier restoreBarrier,
    int maximumRequestsPerMinute = _defaultMaximumRequestsPerMinute,
    int maximumConcurrentRequestsPerGrant =
        _defaultMaximumConcurrentRequestsPerGrant,
    int maximumBodyBytes = _defaultMaximumBodyBytes,
    bool allowEphemeralPort = false,
    DateTime Function()? now,
    Duration operationTimeout = _defaultOperationTimeout,
    Duration extendedOperationTimeout = _defaultExtendedOperationTimeout,
    Duration operationAbandonGrace = _defaultOperationAbandonGrace,
  })  : _accessService = accessService,
        _serverBuilder = serverBuilder,
        _restoreBarrier = restoreBarrier,
        _maximumRequestsPerMinute = maximumRequestsPerMinute,
        _maximumConcurrentRequestsPerGrant = maximumConcurrentRequestsPerGrant,
        _maximumBodyBytes = maximumBodyBytes,
        _allowEphemeralPort = allowEphemeralPort,
        _now = now ?? DateTime.now,
        _operationTimeout = operationTimeout,
        _extendedOperationTimeout = extendedOperationTimeout,
        _operationAbandonGrace = operationAbandonGrace {
    if (maximumRequestsPerMinute < 1 ||
        maximumConcurrentRequestsPerGrant < 1 ||
        maximumBodyBytes < 1 ||
        operationTimeout <= Duration.zero ||
        extendedOperationTimeout <= Duration.zero ||
        operationAbandonGrace <= Duration.zero) {
      throw ArgumentError('MCP server limits must be positive');
    }
  }

  final IMcpAccessService _accessService;
  final McpAuthenticatedServerBuilder _serverBuilder;
  final IRestoreBarrier _restoreBarrier;
  final int _maximumRequestsPerMinute;
  final int _maximumConcurrentRequestsPerGrant;
  final int _maximumBodyBytes;
  final bool _allowEphemeralPort;
  final DateTime Function() _now;
  final Duration _operationTimeout;
  final Duration _extendedOperationTimeout;
  final Duration _operationAbandonGrace;
  final Random _random = Random.secure();

  HttpServer? _httpServer;
  StreamSubscription<HttpRequest>? _requestSubscription;
  StreamSubscription<McpAccessRevocation>? _revocationSubscription;
  Map<String, _BoundTransport> _sessions = const {};
  Set<_BoundTransport> _transports = const {};
  Map<String, List<DateTime>> _rateWindows = const {};
  Map<String, int> _activeRequests = const {};
  Map<_RequestAuthorization, AbortSignal> _requestSignals = const {};
  Map<_RequestAuthorization, Set<_BoundTransport>> _requestTransports =
      const {};
  Map<_RequestAuthorization, _OperationState> _operationStates = const {};
  bool _isStarting = false;

  @override
  bool get isRunning => _httpServer != null;

  @override
  int? get boundPort => _httpServer?.port;

  @override
  Uri? get endpoint {
    final port = boundPort;
    return port == null
        ? null
        : Uri(
            scheme: 'http',
            host: InternetAddress.loopbackIPv4.address,
            port: port,
            path: _mcpPath);
  }

  @override
  Future<void> start({required int port}) async {
    if (isRunning || _isStarting) {
      throw StateError('MCP server is already running or starting');
    }
    if (port < 0 || port > 65535 || port == 0 && !_allowEphemeralPort) {
      throw ArgumentError.value(
        port,
        'port',
        'Must be between 1 and 65535; port 0 is test-only',
      );
    }

    _isStarting = true;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _httpServer = server;
      _revocationSubscription = _accessService.revocations.listen(
        (event) => unawaited(_closeGrantTransports(event.grantId)),
      );
      _requestSubscription =
          server.listen((request) => unawaited(_handleRequest(request)));
    } finally {
      _isStarting = false;
    }
  }

  @override
  Future<void> stop() async {
    final server = _httpServer;
    _httpServer = null;
    await _requestSubscription?.cancel();
    _requestSubscription = null;
    await server?.close(force: true);
    await _revocationSubscription?.cancel();
    _revocationSubscription = null;

    final transports = _transports.toList(growable: false);
    _sessions = const {};
    _transports = const {};
    _activeRequests = const {};
    _requestSignals = const {};
    _requestTransports = const {};
    final operationStates = _operationStates.values.toList(growable: false);
    _operationStates = const {};
    for (final state in operationStates) {
      if (!state.settled.isCompleted) state.settled.complete();
    }
    _rateWindows = const {};
    await Future.wait(transports.map((bound) => bound.transport.close()));
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (!_isAllowedEndpoint(request)) {
        await _respond(request, HttpStatus.forbidden, 'Forbidden');
        return;
      }
      _setCorsHeaders(request);
      if (request.method == 'OPTIONS') {
        if (!_takeRateSlot(_anonymousRateKey(request))) {
          await _respondRateLimited(request);
          return;
        }
        await _respond(request, HttpStatus.noContent, '');
        return;
      }
      final authenticated = await _authenticate(request);
      if (authenticated == null) {
        if (!_takeRateSlot(_anonymousRateKey(request))) {
          await _respondRateLimited(request);
          return;
        }
        await _respond(request, HttpStatus.unauthorized, 'Unauthorized');
        return;
      }
      if (!_takeRateSlot('grant:${authenticated.grant.id}')) {
        await _respondRateLimited(request);
        return;
      }
      if (!_sessionBelongsToGrant(request, authenticated.grant.id)) {
        await _respond(request, HttpStatus.notFound, 'Session not found');
        return;
      }
      if (!_acquireGrantSlot(authenticated.grant.id)) {
        await _respondRateLimited(request);
        return;
      }

      _RequestAuthorization? authorization;
      Future<void>? operation;
      try {
        final parsedBody =
            request.method == 'POST' ? await _readBody(request) : null;
        if (_restoreBarrier.isRestoreActive &&
            !_isRestoreStatusRequest(parsedBody)) {
          await _respondRestoreBusy(request, parsedBody);
          return;
        }
        final timeout = _timeoutFor(parsedBody);
        authorization = _RequestAuthorization(
          authenticated.grant,
          authenticated.token,
          _now().add(timeout),
        );
        final runningOperation = runZoned(
          () => _routeAuthenticatedRequest(
            request,
            authenticated.grant,
            parsedBody,
          ),
          zoneValues: {_authorizationZoneKey: authorization},
        );
        operation = runningOperation;
        if (request.method == 'GET') {
          await runningOperation;
        } else {
          await runningOperation.timeout(timeout);
        }
      } on TimeoutException {
        await _abortRequest(authorization, request);
        await operation?.timeout(
          _operationAbandonGrace,
          onTimeout: () {},
        );
      } finally {
        await _waitForOperations(authorization).timeout(
          _operationAbandonGrace,
          onTimeout: () {},
        );
        _clearRequestContext(authorization);
        _releaseGrantSlot(authenticated.grant.id);
      }
    } on _BodyTooLargeException {
      await _closeResponse(request, HttpStatus.requestEntityTooLarge);
    } on FormatException {
      await _respondJsonRpcError(request, HttpStatus.badRequest, 'Parse error');
    } on TimeoutException {
      await _closeResponse(request, HttpStatus.requestTimeout);
    } catch (_) {
      await _closeResponse(request, HttpStatus.internalServerError);
    }
  }

  bool _isAllowedEndpoint(HttpRequest request) {
    if (request.uri.path != _mcpPath || request.uri.hasQuery) return false;
    final port = boundPort;
    if (port == null) return false;
    final host = request.headers.value(HttpHeaders.hostHeader)?.toLowerCase();
    if (host != '127.0.0.1:$port' && host != 'localhost:$port') return false;
    final origin = request.headers.value('origin');
    return origin == null ||
        origin == 'http://127.0.0.1:$port' ||
        origin == 'http://localhost:$port';
  }

  void _setCorsHeaders(HttpRequest request) {
    final origin = request.headers.value('origin');
    if (origin == null) return;
    request.response.headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, origin)
      ..set(HttpHeaders.accessControlAllowCredentialsHeader, 'true')
      ..set(HttpHeaders.accessControlAllowMethodsHeader,
          'GET, POST, DELETE, OPTIONS')
      ..set(
        HttpHeaders.accessControlAllowHeadersHeader,
        'Authorization, Content-Type, Accept, MCP-Protocol-Version, Mcp-Method, Mcp-Name, MCP-Session-Id, Last-Event-ID',
      )
      ..set(HttpHeaders.varyHeader, 'Origin');
  }

  Future<_PresentedAuthorization?> _authenticate(HttpRequest request) async {
    final authorization =
        request.headers.value(HttpHeaders.authorizationHeader);
    if (authorization == null || authorization.contains(',')) return null;
    final match = RegExp(r'^Bearer ([^\s]+)$', caseSensitive: false)
        .firstMatch(authorization);
    if (match == null) return null;
    final token = match.group(1)!;
    final grant = await _accessService.authenticate(token);
    return grant == null ? null : _PresentedAuthorization(grant, token);
  }

  Future<void> _routeAuthenticatedRequest(
    HttpRequest request,
    McpAuthenticatedGrant grant,
    Object? parsedBody,
  ) async {
    final sessionId = request.headers.value('mcp-session-id');
    if (_isStatelessRequest(request, parsedBody)) {
      await _handleStateless(request, grant, parsedBody);
      return;
    }
    if (sessionId != null) {
      final existing = _sessions[sessionId];
      if (existing == null) {
        await _respondJsonRpcError(
            request, HttpStatus.notFound, 'Session not found');
        return;
      }
      _associateRequestTransport(existing);
      await existing.transport.handleRequest(request, parsedBody);
      await request.response.done;
      return;
    }
    if (request.method == 'POST' && _isInitialize(parsedBody)) {
      await _handleInitialize(request, grant, parsedBody);
      return;
    }
    await _respondJsonRpcError(
      request,
      HttpStatus.badRequest,
      'A valid session is required',
    );
  }

  Future<Object?> _readBody(HttpRequest request) async {
    final declaredLength = request.contentLength;
    if (declaredLength > _maximumBodyBytes)
      throw const _BodyTooLargeException();
    var chunks = const <List<int>>[];
    var byteCount = 0;
    await for (final chunk in request.timeout(_requestReadTimeout)) {
      byteCount += chunk.length;
      if (byteCount > _maximumBodyBytes) {
        throw const _BodyTooLargeException();
      }
      chunks = [...chunks, List<int>.unmodifiable(chunk)];
    }
    try {
      return jsonDecode(utf8.decode(chunks.expand((chunk) => chunk).toList()));
    } catch (_) {
      throw const FormatException('Invalid JSON');
    }
  }

  Future<void> _handleStateless(
    HttpRequest request,
    McpAuthenticatedGrant grant,
    Object? parsedBody,
  ) async {
    final bound = _createTransport(grant, isStateless: true);
    _addTransport(bound);
    try {
      if (request.method == 'POST') {
        await bound.server.connect(bound.transport);
      }
      await bound.transport.handleRequest(request, parsedBody);
      await request.response.done;
    } finally {
      _removeTransport(bound);
      await bound.transport.close();
    }
  }

  Future<void> _handleInitialize(
    HttpRequest request,
    McpAuthenticatedGrant grant,
    Object? parsedBody,
  ) async {
    late _BoundTransport bound;
    bound = _createTransport(
      grant,
      isStateless: false,
      onSessionInitialized: (sessionId) {
        _sessions = {..._sessions, sessionId: bound};
      },
    );
    _addTransport(bound);
    await bound.server.connect(bound.transport);
    final sdkOnClose = bound.server.server.onclose;
    bound.server.server.onclose = () {
      try {
        sdkOnClose?.call();
      } finally {
        _removeTransport(bound);
      }
    };
    await bound.transport.handleRequest(request, parsedBody);
    await request.response.done;
  }

  _BoundTransport _createTransport(
    McpAuthenticatedGrant grant, {
    required bool isStateless,
    void Function(String)? onSessionInitialized,
  }) {
    late StreamableHTTPServerTransport transport;
    transport = StreamableHTTPServerTransport(
      options: StreamableHTTPServerTransportOptions(
        sessionIdGenerator: isStateless ? () => null : _newSessionId,
        onsessioninitialized: onSessionInitialized,
        enableDnsRebindingProtection: true,
        allowedHosts: const {'127.0.0.1', 'localhost'},
        allowedOrigins: _allowedOrigins(),
        strictProtocolVersionHeaderValidation: true,
        rejectBatchJsonRpcPayloads: true,
      ),
    );
    final server = _serverBuilder(
      grant,
      _authorizeTool,
      (invocation) => runOperation(invocation),
    );
    final bound = _BoundTransport(grant.id, transport, server);
    transport.onclose = () => _removeTransport(bound);
    return bound;
  }

  Future<bool> _authorizeTool(
    RequestHandlerExtra extra,
    Set<String> requiredScopes,
  ) async {
    final authorization = Zone.current[_authorizationZoneKey];
    if (authorization is! _RequestAuthorization) {
      return false;
    }
    _requestSignals = Map.unmodifiable({
      ..._requestSignals,
      authorization: extra.signal,
    });
    return isAuthorized(requiredScopes);
  }

  @override
  Future<T> runOperation<T>(Future<T> Function() operation) async {
    final authorization = Zone.current[_authorizationZoneKey];
    if (authorization is! _RequestAuthorization) {
      throw StateError('MCP operation has no active request context');
    }
    final current = _operationStates[authorization];
    final state = current == null
        ? _OperationState(1, Completer<void>())
        : _OperationState(current.activeCount + 1, current.settled);
    _operationStates = Map.unmodifiable({
      ..._operationStates,
      authorization: state,
    });
    try {
      return await operation();
    } finally {
      _finishOperation(authorization);
    }
  }

  @override
  Future<bool> isAuthorized(Set<String> requiredScopes) async =>
      await currentGrant(requiredScopes: requiredScopes) != null;

  @override
  Future<McpAuthenticatedGrant?> currentGrant({
    Set<String> requiredScopes = const {},
  }) async {
    final authorization = Zone.current[_authorizationZoneKey];
    final signal = authorization is _RequestAuthorization
        ? _requestSignals[authorization]
        : null;
    if (authorization is! _RequestAuthorization ||
        signal == null ||
        !authorization.deadline.isAfter(_now()) ||
        signal.aborted) {
      return null;
    }
    final current = await _accessService.authenticate(
      authorization.token,
      requiredScopes: requiredScopes,
    );
    final currentAuthorization = Zone.current[_authorizationZoneKey];
    final currentSignal = _requestSignals[authorization];
    if (!identical(currentAuthorization, authorization) ||
        !identical(currentSignal, signal) ||
        !authorization.deadline.isAfter(_now()) ||
        signal.aborted) {
      return null;
    }
    return current != null && current.id == authorization.grant.id
        ? current
        : null;
  }

  bool _sessionBelongsToGrant(HttpRequest request, String grantId) {
    final sessionId = request.headers.value('mcp-session-id');
    final bound = sessionId == null ? null : _sessions[sessionId];
    return bound == null || bound.grantId == grantId;
  }

  bool _isStatelessRequest(HttpRequest request, Object? body) {
    final header = request.headers.value('mcp-protocol-version')?.trim();
    if (header != null && header.isNotEmpty) {
      return isStatelessProtocolVersion(header) ||
          !McpProtocol.stable.supportedVersions.contains(header);
    }
    if (body is! Map) return false;
    final params = body['params'];
    final meta = params is Map ? params['_meta'] : null;
    final version = meta is Map ? meta[McpMetaKey.protocolVersion] : null;
    return version is String && isStatelessProtocolVersion(version);
  }

  bool _isInitialize(Object? body) =>
      body is Map && body['method'] == Method.initialize;

  bool _isRestoreStatusRequest(Object? body) {
    final message = _parseJsonRpcMessage(body);
    return message is JsonRpcCallToolRequest &&
        message.callParams.name == 'whph_operations_get';
  }

  JsonRpcMessage? _parseJsonRpcMessage(Object? body) {
    if (body is! Map) return null;
    return JsonRpcMessage.fromJson(Map<String, dynamic>.from(body));
  }

  Duration _timeoutFor(Object? body) {
    if (body is! Map || body['method'] != Method.toolsCall) {
      return _operationTimeout;
    }
    final params = body['params'];
    final name = params is Map ? params['name'] : null;
    return name is String &&
            (name.startsWith('whph_data_') || name.startsWith('whph_sync_'))
        ? _extendedOperationTimeout
        : _operationTimeout;
  }

  Set<String> _allowedOrigins() {
    final port = boundPort!;
    return {'http://127.0.0.1:$port', 'http://localhost:$port'};
  }

  String _newSessionId() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  bool _takeRateSlot(String key) {
    final now = _now().toUtc();
    final cutoff = now.subtract(_rateWindow);
    final current = _rateWindows[key] ?? const [];
    final retained = current.where((time) => time.isAfter(cutoff)).toList();
    if (retained.length >= _maximumRequestsPerMinute) {
      _rateWindows = {..._rateWindows, key: List.unmodifiable(retained)};
      return false;
    }
    _rateWindows = {
      ..._rateWindows,
      key: List.unmodifiable([...retained, now]),
    };
    return true;
  }

  bool _acquireGrantSlot(String grantId) {
    final active = _activeRequests[grantId] ?? 0;
    if (active >= _maximumConcurrentRequestsPerGrant) return false;
    _activeRequests = {..._activeRequests, grantId: active + 1};
    return true;
  }

  void _releaseGrantSlot(String grantId) {
    final active = _activeRequests[grantId] ?? 0;
    if (active <= 1) {
      _activeRequests = Map.unmodifiable({
        for (final entry in _activeRequests.entries)
          if (entry.key != grantId) entry.key: entry.value,
      });
    } else {
      _activeRequests = Map.unmodifiable({
        ..._activeRequests,
        grantId: active - 1,
      });
    }
  }

  void _addTransport(_BoundTransport bound) {
    _transports = Set.unmodifiable({..._transports, bound});
    _associateRequestTransport(bound);
  }

  void _associateRequestTransport(_BoundTransport bound) {
    final authorization = Zone.current[_authorizationZoneKey];
    if (authorization is! _RequestAuthorization) return;
    final current = _requestTransports[authorization] ?? const {};
    _requestTransports = Map.unmodifiable({
      ..._requestTransports,
      authorization: Set.unmodifiable({...current, bound}),
    });
  }

  void _removeTransport(_BoundTransport bound) {
    _transports = Set.unmodifiable(_transports.where((item) => item != bound));
    _sessions = Map.unmodifiable(Map.fromEntries(
      _sessions.entries.where((entry) => entry.value != bound),
    ));
  }

  Future<void> _closeGrantTransports(String grantId) async {
    final matching =
        _transports.where((bound) => bound.grantId == grantId).toList();
    for (final bound in matching) {
      _removeTransport(bound);
      await bound.transport.close();
    }
  }

  Future<void> _abortRequest(
    _RequestAuthorization? authorization,
    HttpRequest request,
  ) async {
    final transports = authorization == null
        ? const <_BoundTransport>[]
        : _requestTransports[authorization]?.toList(growable: false) ??
            const <_BoundTransport>[];
    for (final bound in transports) {
      _removeTransport(bound);
      await bound.transport.close();
    }
    await _closeResponse(request, HttpStatus.requestTimeout);
  }

  void _clearRequestContext(_RequestAuthorization? authorization) {
    if (authorization == null) return;
    _requestSignals = Map.unmodifiable({
      for (final entry in _requestSignals.entries)
        if (entry.key != authorization) entry.key: entry.value,
    });
    _requestTransports = Map.unmodifiable({
      for (final entry in _requestTransports.entries)
        if (entry.key != authorization) entry.key: entry.value,
    });
    _operationStates = Map.unmodifiable({
      for (final entry in _operationStates.entries)
        if (entry.key != authorization) entry.key: entry.value,
    });
  }

  Future<void> _waitForOperations(
    _RequestAuthorization? authorization,
  ) async {
    if (authorization == null) return;
    final state = _operationStates[authorization];
    if (state != null && state.activeCount > 0) await state.settled.future;
  }

  void _finishOperation(_RequestAuthorization authorization) {
    final current = _operationStates[authorization];
    if (current == null) return;
    final remaining = current.activeCount - 1;
    if (remaining == 0) {
      _operationStates = Map.unmodifiable({
        ..._operationStates,
        authorization: _OperationState(0, current.settled),
      });
      if (!current.settled.isCompleted) current.settled.complete();
      return;
    }
    _operationStates = Map.unmodifiable({
      ..._operationStates,
      authorization: _OperationState(remaining, current.settled),
    });
  }

  String _anonymousRateKey(HttpRequest request) {
    final address = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    return 'anonymous:$address';
  }

  Future<void> _respondRateLimited(HttpRequest request) async {
    request.response.headers.set(HttpHeaders.retryAfterHeader, '60');
    await _respond(request, HttpStatus.tooManyRequests, 'Too Many Requests');
  }

  Future<void> _respondJsonRpcError(
    HttpRequest request,
    int status,
    String message,
  ) =>
      _respond(
        request,
        status,
        jsonEncode({
          'jsonrpc': jsonRpcVersion,
          'id': null,
          'error': {
            'code': ErrorCode.connectionClosed.value,
            'message': message
          },
        }),
        contentType: ContentType.json,
      );

  Future<void> _respondRestoreBusy(
    HttpRequest request,
    Object? body,
  ) async {
    final message = _parseJsonRpcMessage(body);
    final id = message is JsonRpcRequest ? message.id : null;
    await _respond(
      request,
      HttpStatus.serviceUnavailable,
      jsonEncode(
        JsonRpcError(
          id: id,
          error: const JsonRpcErrorData(
            code: -32603,
            message: 'Restore in progress',
            data: {'code': 'busy'},
          ),
        ).toJson(),
      ),
      contentType: ContentType.json,
    );
  }

  Future<void> _respond(
    HttpRequest request,
    int status,
    String body, {
    ContentType? contentType,
  }) async {
    request.response.statusCode = status;
    if (status == HttpStatus.unauthorized) {
      request.response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
    }
    if (contentType != null) request.response.headers.contentType = contentType;
    if (body.isNotEmpty) request.response.write(body);
    await request.response.close();
  }

  Future<void> _closeResponse(HttpRequest request, int status) async {
    try {
      request.response.statusCode = status;
      await request.response.close();
    } catch (_) {}
  }
}

final class _PresentedAuthorization {
  const _PresentedAuthorization(this.grant, this.token);

  final McpAuthenticatedGrant grant;
  final String token;
}

final class _OperationState {
  const _OperationState(this.activeCount, this.settled);

  final int activeCount;
  final Completer<void> settled;
}

final class _RequestAuthorization {
  const _RequestAuthorization(this.grant, this.token, this.deadline);

  final McpAuthenticatedGrant grant;
  final String token;
  final DateTime deadline;
}

final class _BoundTransport {
  const _BoundTransport(this.grantId, this.transport, this.server);

  final String grantId;
  final StreamableHTTPServerTransport transport;
  final McpServer server;
}

final class _BodyTooLargeException implements Exception {
  const _BodyTooLargeException();
}

final Object _authorizationZoneKey = Object();
