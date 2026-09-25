import 'dart:async';

import 'package:mcp_dart/mcp_dart.dart';

import 'mcp_tool_arguments.dart';
import 'mcp_tool_error.dart';
import 'mcp_tool_result.dart';

typedef McpToolHandler = FutureOr<CallToolResult> Function(
  McpToolArguments arguments,
  RequestHandlerExtra extra,
);

final class McpToolDefinition {
  McpToolDefinition({
    required this.name,
    required this.description,
    required JsonObject inputSchema,
    required JsonObject outputSchema,
    required this.annotations,
    required Set<String> requiredScopes,
    Set<String> anyOfScopes = const {},
    required this.handler,
  })  : inputSchema = _strictSchema(inputSchema, 'inputSchema'),
        outputSchema = _strictSchema(outputSchema, 'outputSchema'),
        requiredScopes = Set<String>.unmodifiable(requiredScopes),
        anyOfScopes = Set<String>.unmodifiable(anyOfScopes) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Must be a lowercase tool name');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError.value(description, 'description', 'Must not be empty');
    }
    if (requiredScopes.isEmpty && anyOfScopes.isEmpty) {
      throw ArgumentError.value(
        requiredScopes,
        'requiredScopes',
        'requiredScopes or anyOfScopes must not be empty',
      );
    }
  }

  final String name;
  final String description;
  final JsonObject inputSchema;
  final JsonObject outputSchema;
  final ToolAnnotations annotations;
  final Set<String> requiredScopes;
  final Set<String> anyOfScopes;
  final McpToolHandler handler;

  RegisteredTool registerWith(McpServer server) => server.registerTool(
        name,
        description: description,
        inputSchema: inputSchema,
        outputSchema: outputSchema,
        annotations: annotations,
        callback: _handle,
      );

  Future<CallToolResult> _handle(
    Map<String, dynamic> rawArguments,
    RequestHandlerExtra extra,
  ) async {
    try {
      return await handler(McpToolArguments(rawArguments), extra);
    } on McpToolException catch (exception) {
      return McpToolResult.failure(exception.error);
    } catch (_) {
      return McpToolResult.failure(
        McpToolError(
          code: McpToolErrorCode.operationFailed,
          message: 'The operation failed.',
        ),
      );
    }
  }

  static JsonObject _strictSchema(JsonObject schema, String name) {
    final parsed = JsonSchema.fromJson(schema.toJson());
    if (parsed is! JsonObject || !_hasClosedObjectSchemas(parsed.toJson())) {
      throw ArgumentError.value(
        schema.toJson(),
        name,
        'Every object schema must reject additional properties',
      );
    }
    return parsed;
  }

  static bool _hasClosedObjectSchemas(Object? schema) {
    if (schema is bool) return true;
    if (schema is! Map<String, dynamic>) return false;

    final type = schema['type'];
    final hasObjectShape =
        type == 'object' || type is List && type.contains('object') || _objectKeywords.any(schema.containsKey);
    if (hasObjectShape && schema['additionalProperties'] != false) {
      return false;
    }

    for (final keyword in _schemaMapKeywords) {
      final schemas = schema[keyword];
      if (schemas is Map && schemas.values.any((value) => !_hasClosedObjectSchemas(value))) {
        return false;
      }
    }
    for (final keyword in _schemaListKeywords) {
      final schemas = schema[keyword];
      if (schemas is List && schemas.any((value) => !_hasClosedObjectSchemas(value))) {
        return false;
      }
    }
    return _schemaKeywords.every(
      (keyword) => !schema.containsKey(keyword) || _hasClosedObjectSchemas(schema[keyword]),
    );
  }

  static const _objectKeywords = {
    'properties',
    'patternProperties',
    'required',
    'dependentRequired',
    'dependentSchemas',
    'propertyNames',
    'minProperties',
    'maxProperties',
  };
  static const _schemaMapKeywords = {
    r'$defs',
    'definitions',
    'properties',
    'patternProperties',
    'dependentSchemas',
  };
  static const _schemaListKeywords = {
    'allOf',
    'anyOf',
    'oneOf',
    'prefixItems',
  };
  static const _schemaKeywords = {
    'items',
    'contains',
    'not',
    'if',
    'then',
    'else',
    'propertyNames',
    'unevaluatedItems',
    'unevaluatedProperties',
  };
}
