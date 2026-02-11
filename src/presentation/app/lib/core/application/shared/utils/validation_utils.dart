/// Utility functions for validation.
library;

/// Validates if a string is a valid ID (NanoID or similar).
///
/// Supports alphanumeric characters, hyphens, underscores, and tildes.
///
/// Returns `true` if the string matches the pattern, `false` otherwise.
bool isValidId(String input) {
  if (input.isEmpty) return false;

  // NanoID and alphanumeric-safe pattern
  final idRegex = RegExp(r'^[a-zA-Z0-9\-_~]+$');

  return idRegex.hasMatch(input);
}

/// Sanitizes and validates string IDs (NanoID or similar) for safe use in SQL queries.
///
/// Returns the sanitized ID if valid, or throws [ArgumentError] if invalid.
String sanitizeAndValidateId(String input) {
  final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9\-_~]'), '');

  if (!isValidId(sanitized)) {
    throw ArgumentError('Invalid ID format: $input');
  }

  return sanitized;
}
