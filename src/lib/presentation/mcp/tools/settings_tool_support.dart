part of 'settings_tools.dart';

PublicSettingKey _requirePublicKey(String value) {
  final key = PublicSettingKey.fromPublicName(value);
  if (key != null) return key;
  throw McpToolException(McpToolError(
    code: McpToolErrorCode.validationError,
    message: 'The setting key is not user-facing or supported.',
    details: {'field': 'key'},
  ));
}

DateTime? _optionalRevision(McpToolArguments arguments) {
  final value = arguments.optionalString('expectedRevision');
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return parsed;
  throw McpToolException(McpToolError(
    code: McpToolErrorCode.validationError,
    message: 'Argument "expectedRevision" must be an ISO-8601 timestamp.',
    details: {'field': 'expectedRevision'},
  ));
}

Map<String, dynamic> _settingJson(PublicSettingRecord setting) => {
      'key': setting.key.publicName,
      'value': setting.value,
      'valueType': setting.key.valueType,
      if (setting.revision != null) 'revision': setting.revision!.toUtc().toIso8601String(),
    };

Future<void> _requireCurrentAuthorization(
  IMcpRequestContext context,
  RequestHandlerExtra extra,
  Set<String> scopes,
) async {
  extra.signal.throwIfAborted();
  if (await context.isAuthorized(scopes)) return;
  throw McpToolException(McpToolError(
    code: McpToolErrorCode.permissionDenied,
    message: 'The connection authorization changed before commit.',
  ));
}

CallToolResult _failure(McpToolErrorCode code, String message) =>
    McpToolResult.failure(McpToolError(code: code, message: message));
