import 'package:mcp_dart/mcp_dart.dart';

import 'mcp_json.dart';
import 'mcp_tool_error.dart';

abstract final class McpToolResult {
  static CallToolResult success(Map<String, dynamic> value) =>
      CallToolResult.fromStructuredContent(McpJson.copyObject(value));

  static CallToolResult failure(McpToolError error) => CallToolResult(
        content: [TextContent(text: error.message)],
        isError: true,
        structuredContent: {'error': error.toJson()},
      );
}
