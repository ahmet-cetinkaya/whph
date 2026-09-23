abstract final class McpJson {
  static Map<String, dynamic> freezeObject(Map<String, dynamic> value) => Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key, _freeze(item))),
      );

  static Map<String, dynamic> copyObject(Map<String, dynamic> value) =>
      value.map((key, item) => MapEntry(key, _copy(item)));

  static Object? _freeze(Object? value) => switch (value) {
        null || String() || num() || bool() => value,
        List<dynamic>() => List<dynamic>.unmodifiable(value.map(_freeze)),
        Map<String, dynamic>() => freezeObject(value),
        _ => throw ArgumentError.value(value, 'value', 'Must contain JSON data'),
      };

  static Object? _copy(Object? value) => switch (value) {
        null || String() || num() || bool() => value,
        List<dynamic>() => value.map(_copy).toList(),
        Map<String, dynamic>() => copyObject(value),
        _ => throw ArgumentError.value(value, 'value', 'Must contain JSON data'),
      };
}
