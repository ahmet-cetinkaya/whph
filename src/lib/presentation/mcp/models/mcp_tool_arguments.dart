import 'mcp_json.dart';
import 'mcp_tool_error.dart';

final class McpToolArguments {
  McpToolArguments(Map<String, dynamic> values) : _values = McpJson.freezeObject(values);

  final Map<String, dynamic> _values;

  bool contains(String name) => _values.containsKey(name);

  Object? operator [](String name) => _values[name];

  String requireString(String name) => _require<String>(name, 'string');

  String? optionalString(String name) => _optional<String>(name, 'string');

  int? optionalInt(String name) => _optional<int>(name, 'integer');

  num? optionalNumber(String name) => _optional<num>(name, 'number');

  bool? optionalBool(String name) => _optional<bool>(name, 'boolean');

  Map<String, dynamic>? optionalObject(String name) => _optional<Map<String, dynamic>>(name, 'object');

  List<dynamic>? optionalList(String name) => _optional<List<dynamic>>(name, 'array');

  Map<String, dynamic> toJson() => McpJson.copyObject(_values);

  T _require<T>(String name, String type) {
    if (!_values.containsKey(name)) {
      throw McpToolException(
        McpToolError(
          code: McpToolErrorCode.validationError,
          message: 'Argument "$name" is required.',
          details: {'field': name},
        ),
      );
    }
    return _typed<T>(name, type);
  }

  T? _optional<T>(String name, String type) {
    if (!_values.containsKey(name) || _values[name] == null) return null;
    return _typed<T>(name, type);
  }

  T _typed<T>(String name, String type) {
    final value = _values[name];
    if (value is T) return value;
    throw McpToolException(
      McpToolError(
        code: McpToolErrorCode.validationError,
        message: 'Argument "$name" must be a $type.',
        details: {'field': name},
      ),
    );
  }
}
