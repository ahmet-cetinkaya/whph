import 'package:mcp_dart/mcp_dart.dart';

import 'models/mcp_tool_definition.dart';

McpServer createMcpServer({
  required Implementation serverInfo,
  Iterable<McpToolDefinition> tools = const [],
}) {
  final server = McpServer(
    serverInfo,
    options: const McpServerOptions(protocol: McpProtocol.stable),
  );
  for (final tool in tools) {
    tool.registerWith(server);
  }
  return server;
}
