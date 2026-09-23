import 'dart:async';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:whph/core/application/features/mcp/services/abstraction/i_mcp_access_service.dart';

import 'models/mcp_tool_arguments.dart';
import 'models/mcp_tool_definition.dart';
import 'models/mcp_tool_error.dart';
import 'models/mcp_tool_result.dart';

typedef McpToolAuthorizer = FutureOr<bool> Function(
  RequestHandlerExtra extra,
  Set<String> requiredScopes,
);

final class McpToolRegistry {
  McpToolRegistry({
    required Iterable<McpToolDefinition> tools,
    required McpToolAuthorizer authorize,
    required Future<CallToolResult> Function(
      Future<CallToolResult> Function() invocation,
    ) runInvocation,
  })  : _authorize = authorize,
        _runInvocation = runInvocation,
        _toolsByName = _indexTools(tools);

  final McpToolAuthorizer _authorize;
  final Future<CallToolResult> Function(
    Future<CallToolResult> Function() invocation,
  ) _runInvocation;
  final Map<String, McpToolDefinition> _toolsByName;

  List<McpToolDefinition> discover(Set<String> grantedScopes) =>
      List<McpToolDefinition>.unmodifiable(
        _toolsByName.values
            .where(
              (tool) =>
                  grantedScopes.containsAll(tool.requiredScopes) &&
                  (tool.anyOfScopes.isEmpty ||
                      grantedScopes.any(tool.anyOfScopes.contains)),
            )
            .map(_guard),
      );

  Future<CallToolResult> invoke(
    String name,
    McpToolArguments arguments,
    RequestHandlerExtra extra,
  ) async {
    final tool = _toolsByName[name];
    if (tool == null) return _permissionDenied();

    try {
      return await _invokeAuthorized(tool, arguments, extra);
    } on McpToolException catch (exception) {
      return McpToolResult.failure(exception.error);
    }
  }

  McpToolDefinition _guard(McpToolDefinition tool) => McpToolDefinition(
        name: tool.name,
        description: tool.description,
        inputSchema: tool.inputSchema,
        outputSchema: tool.outputSchema,
        annotations: tool.annotations,
        requiredScopes: tool.requiredScopes,
        anyOfScopes: tool.anyOfScopes,
        handler: (arguments, extra) =>
            _invokeAuthorized(tool, arguments, extra),
      );

  Future<CallToolResult> _invokeAuthorized(
    McpToolDefinition tool,
    McpToolArguments arguments,
    RequestHandlerExtra extra,
  ) async {
    if (!await _isAuthorized(tool, extra)) {
      return _permissionDenied();
    }
    return _runInvocation(() async => await tool.handler(arguments, extra));
  }

  Future<bool> _isAuthorized(
    McpToolDefinition tool,
    RequestHandlerExtra extra,
  ) async {
    if (tool.anyOfScopes.isEmpty) {
      return _authorize(extra, tool.requiredScopes);
    }
    for (final candidate in tool.anyOfScopes) {
      final scopes = Set<String>.unmodifiable({
        ...tool.requiredScopes,
        candidate,
      });
      if (await _authorize(extra, scopes)) return true;
    }
    return false;
  }

  static Map<String, McpToolDefinition> _indexTools(
    Iterable<McpToolDefinition> tools,
  ) {
    final definitions = List<McpToolDefinition>.unmodifiable(tools);
    final invalidScopes = definitions
        .expand((tool) => {...tool.requiredScopes, ...tool.anyOfScopes})
        .where((scope) => !McpScopes.all.contains(scope))
        .toSet();
    if (invalidScopes.isNotEmpty) {
      throw ArgumentError.value(
        invalidScopes,
        'tools',
        'Tool scopes must be canonical MCP scopes',
      );
    }
    final names = definitions.map((tool) => tool.name).toList(growable: false);
    if (names.toSet().length != names.length) {
      throw ArgumentError.value(names, 'tools', 'Tool names must be unique');
    }
    return Map<String, McpToolDefinition>.unmodifiable({
      for (final tool in definitions) tool.name: tool,
    });
  }

  static CallToolResult _permissionDenied() => McpToolResult.failure(
        McpToolError(
          code: McpToolErrorCode.permissionDenied,
          message: 'The connection is not permitted to use this tool.',
        ),
      );
}
