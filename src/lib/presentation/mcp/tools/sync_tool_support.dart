part of 'sync_tools.dart';

const _revisionLength = 16;

int _pageIndex(String? cursor) {
  if (cursor == null) return 0;
  final value = int.tryParse(cursor);
  if (value != null && value >= 0) return value;
  throw McpToolException(McpToolError(code: McpToolErrorCode.validationError, message: 'Cursor is invalid.'));
}

/// Identifies the editable state of a member (name and addresses), so an
/// update made after the member changed, locally or by a remote apply, is
/// rejected.
String _revisionOf(String name, List<String> addresses) =>
    sha256.convert(utf8.encode(jsonEncode([name, addresses]))).toString().substring(0, _revisionLength);

bool isPairableIpAddress(String value) {
  final address = InternetAddress.tryParse(value);
  if (address == null || address.type != InternetAddressType.IPv4) return false;
  final octets = value.split('.').map(int.parse).toList(growable: false);
  return octets.first == 10 ||
      octets.first == 127 ||
      (octets.first == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets.first == 192 && octets[1] == 168) ||
      (octets.first == 169 && octets[1] == 254);
}

List<String> _addressesOf(McpToolArguments arguments) {
  final values = arguments.optionalList('addresses') ?? const [];
  final addresses = values.whereType<String>().toList(growable: false);
  if (addresses.length == values.length && addresses.every(isPairableIpAddress)) return addresses;
  throw McpToolException(
    McpToolError(
      code: McpToolErrorCode.validationError,
      message: 'addresses must be private or loopback IPv4 addresses.',
      details: {'field': 'addresses'},
    ),
  );
}

({String address, int port}) _peerAddress(Map<String, dynamic>? value) {
  if (value == null) {
    throw McpToolException(
      McpToolError(code: McpToolErrorCode.validationError, message: 'Argument "peer" is required.'),
    );
  }
  final arguments = McpToolArguments(value);
  final address = arguments.requireString('ipAddress');
  final port = arguments.optionalInt('port') ?? syncLanPort;
  if (!isPairableIpAddress(address) || port < 1 || port > 65535) {
    throw McpToolException(
      McpToolError(code: McpToolErrorCode.validationError, message: 'Peer address or port is invalid.'),
    );
  }
  return (address: address, port: port);
}

Map<String, dynamic> _memberJson(SyncMemberSummary member, List<String> addresses) => {
  'id': member.memberId,
  'name': member.name,
  if (member.platform != null) 'platform': member.platform,
  'addresses': addresses,
  'status': member.lastResult?.code ?? 'ok',
  'itemsCannotBeApplied': member.itemsCannotBeApplied,
  'needsRepairing': member.isLegacy,
  'isThisDevice': member.isThisDevice,
  if (member.lastSuccessfulSync != null) 'lastSuccessfulSync': member.lastSuccessfulSync!.toUtc().toIso8601String(),
  'revision': _revisionOf(member.name, addresses),
};

Future<void> _requireAuthorized(IMcpRequestContext context, RequestHandlerExtra extra, Set<String> scopes) async {
  extra.signal.throwIfAborted();
  if (await context.isAuthorized(scopes)) return;
  throw McpToolException(
    McpToolError(
      code: McpToolErrorCode.permissionDenied,
      message: 'The connection authorization changed before commit.',
    ),
  );
}

CallToolResult _validation(String field, String message) => McpToolResult.failure(
  McpToolError(code: McpToolErrorCode.validationError, message: message, details: {'field': field}),
);
CallToolResult _failure(McpToolErrorCode code, String message) =>
    McpToolResult.failure(McpToolError(code: code, message: message));
