part of 'sync_tools.dart';

int _pageIndex(String? cursor) {
  if (cursor == null) return 0;
  final value = int.tryParse(cursor);
  if (value != null && value >= 0) return value;
  throw McpToolException(McpToolError(code: McpToolErrorCode.validationError, message: 'Cursor is invalid.'));
}

DateTime _revision(McpToolArguments arguments, String field) {
  final value = DateTime.tryParse(arguments.requireString(field));
  if (value != null) return value;
  throw McpToolException(
      McpToolError(code: McpToolErrorCode.validationError, message: '$field must be an ISO-8601 timestamp.'));
}

FieldUpdate<String> _ipUpdate(McpToolArguments arguments, String field) {
  if (!arguments.contains(field)) return const PreserveField();
  final value = arguments.requireString(field);
  if (isPairableIpAddress(value)) return ReplaceField(value);
  throw McpToolException(McpToolError(
      code: McpToolErrorCode.validationError, message: '$field must be a private or loopback IPv4 address.'));
}

SyncPeer _peer(Map<String, dynamic>? value) {
  if (value == null) {
    throw McpToolException(
        McpToolError(code: McpToolErrorCode.validationError, message: 'Argument "peer" is required.'));
  }
  final args = McpToolArguments(value);
  final ip = args.requireString('ipAddress');
  final port = args.optionalInt('port');
  if (!isPairableIpAddress(ip) || port == null || port < 1 || port > 65535) {
    throw McpToolException(
        McpToolError(code: McpToolErrorCode.validationError, message: 'Peer address or port is invalid.'));
  }
  return SyncPeer(
      deviceId: args.requireString('deviceId'), name: args.requireString('name'), ipAddress: ip, port: port);
}

Map<String, dynamic> _deviceJson(SyncDevice device, SyncStatus status) => {
      'id': device.id,
      if (device.name != null) 'name': device.name,
      'fromIp': device.fromIp,
      'toIp': device.toIp,
      'fromDeviceId': device.fromDeviceId,
      'toDeviceId': device.toDeviceId,
      if (device.lastSyncDate != null) 'lastSyncDate': device.lastSyncDate!.toUtc().toIso8601String(),
      'revision': (device.modifiedDate ?? device.createdDate).toUtc().toIso8601String(),
      'syncState': status.state.name,
    };
Map<String, dynamic> _statusJson(SyncStatus status) => {
      'state': status.state.name,
      if (status.currentDeviceId != null) 'currentDeviceId': status.currentDeviceId,
      if (status.lastSyncTime != null) 'lastSyncTime': status.lastSyncTime!.toUtc().toIso8601String(),
      'isManual': status.isManual,
      if (status.errorMessage != null) 'error': status.errorMessage,
    };
Map<String, dynamic> _operationJson(McpOperation operation, SyncPeer peer) => {
      'operationId': operation.id,
      'status': operation.status.name,
      'requiresApproval': true,
      'expiresAt': operation.approvalExpiresAt.toUtc().toIso8601String(),
      'peerSummary': '${peer.name} (${peer.ipAddress}:${peer.port})',
    };

Future<void> _requireAuthorized(IMcpRequestContext context, RequestHandlerExtra extra, Set<String> scopes) async {
  extra.signal.throwIfAborted();
  if (await context.isAuthorized(scopes)) return;
  throw McpToolException(McpToolError(
      code: McpToolErrorCode.permissionDenied, message: 'The connection authorization changed before commit.'));
}

CallToolResult _validation(String field, String message) => McpToolResult.failure(
    McpToolError(code: McpToolErrorCode.validationError, message: message, details: {'field': field}));
CallToolResult _failure(McpToolErrorCode code, String message) =>
    McpToolResult.failure(McpToolError(code: code, message: message));
