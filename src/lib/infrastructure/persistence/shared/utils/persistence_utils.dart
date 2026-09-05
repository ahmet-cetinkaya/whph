/// Shared utility functions for persistence layer.
library;

import 'package:whph/core/domain/features/tags/tag.dart';

/// Parses tag type from database index.
///
/// Converts integer type index to TagType enum, with null-safety.
/// Returns [TagType.label] as default if typeIndex is null or out of bounds.
TagType parseTagType(int? typeIndex) {
  if (typeIndex == null) return TagType.label;
  if (typeIndex >= 0 && typeIndex < TagType.values.length) {
    return TagType.values[typeIndex];
  }
  return TagType.label;
}

/// Reads a duration aggregate produced by SQLite's `TOTAL()`.
///
/// Duration sums use `TOTAL()` rather than `SUM()` because `SUM()` returns a
/// 64-bit integer and aborts the whole query with `SQLITE_ERROR` once the sum
/// overflows. `TOTAL()` returns a float instead, so it can never overflow — but
/// that also means the value arrives as a `double` and must not be read as an
/// `int`. Returns 0 for a missing or non-numeric value.
int parseDurationAggregate(Object? value) => value is num ? value.round() : 0;
