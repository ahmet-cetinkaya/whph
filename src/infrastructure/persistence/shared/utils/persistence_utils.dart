/// Shared utility functions for persistence layer.
library;

import 'package:domain/features/tags/tag.dart';

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
