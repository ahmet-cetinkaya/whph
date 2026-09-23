import 'mcp_json.dart';

enum McpToolErrorCode {
  validationError('validation_error'),
  notFound('not_found'),
  permissionDenied('permission_denied'),
  permissionRequired('permission_required'),
  conflict('conflict'),
  unsupportedPlatform('unsupported_platform'),
  approvalRequired('approval_required'),
  busy('busy'),
  operationFailed('operation_failed');

  const McpToolErrorCode(this.value);

  final String value;
}

final class McpToolError {
  McpToolError({
    required this.code,
    required this.message,
    Map<String, dynamic>? details,
  }) : details = details == null ? null : McpJson.freezeObject(details);

  final McpToolErrorCode code;
  final String message;
  final Map<String, dynamic>? details;

  Map<String, dynamic> toJson() => {
        'code': code.value,
        'message': message,
        if (details != null) 'details': McpJson.copyObject(details!),
      };
}

final class McpToolException implements Exception {
  const McpToolException(this.error);

  final McpToolError error;
}
