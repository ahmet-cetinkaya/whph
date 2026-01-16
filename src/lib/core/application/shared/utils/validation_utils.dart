/// Utility functions for validation.
library;

/// Validates if a string is a valid UUID v4 format.
///
/// UUID v4 format: 8-4-4-4-12 hexadecimal digits
/// Example: 550e8400-e29b-41d4-a716-446655440000
///
/// Returns `true` if the string matches UUID v4 format, `false` otherwise.
bool isValidUuid(String input) {
  if (input.isEmpty) return false;

  // UUID v4 regex pattern
  // Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  // where x is any hex digit and y is 8, 9, a, or b
  final uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  return uuidRegex.hasMatch(input);
}

/// Sanitizes and validates UUID strings for safe use in SQL queries.
///
/// This function provides both sanitization (removing invalid characters)
/// and validation (ensuring proper UUID format).
///
/// Returns the sanitized UUID if valid, or throws [ArgumentError] if invalid.
///
/// Throws [ArgumentError] if the input is not a valid UUID.
String sanitizeAndValidateUuid(String input) {
  final sanitized = input.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');

  if (!isValidUuid(sanitized)) {
    throw ArgumentError('Invalid UUID format: $input');
  }

  return sanitized;
}
