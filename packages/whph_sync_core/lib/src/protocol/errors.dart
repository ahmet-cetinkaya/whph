/// Typed rejections of received sync data (FR-015).
///
/// Every decoder in this package either returns a fully validated value or
/// throws one of these; it never returns partially decoded state. The same
/// types are thrown by the encoders for content a receiver would reject, so a
/// sender never emits a frame its peer must refuse.
library;

/// Base type of every rejection of wire or canonical bytes.
sealed class SyncDecodeException implements Exception {
  const SyncDecodeException(this.message);

  /// Human-readable reason. Never contains field values or key material.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A frame is larger than the D8 frame limit.
final class FrameTooLargeException extends SyncDecodeException {
  FrameTooLargeException(this.size, this.limit) : super('frame of $size bytes exceeds $limit');

  final int size;
  final int limit;
}

/// A change value (or envelope ciphertext) is larger than the D8 value limit.
final class ValueTooLargeException extends SyncDecodeException {
  ValueTooLargeException(this.size, this.limit) : super('value of $size bytes exceeds $limit');

  final int size;
  final int limit;
}

/// A batch or manifest holds more items than the D8 batch limit.
final class BatchTooLargeException extends SyncDecodeException {
  BatchTooLargeException(this.count, this.limit) : super('$count items exceed $limit');

  final int count;
  final int limit;
}

/// The bytes do not form a valid structure (bad tag, bad length, invalid
/// UTF-8, out-of-range number, unsorted or duplicate keys, trailing bytes...).
final class MalformedMessageException extends SyncDecodeException {
  const MalformedMessageException(super.message);
}

/// The bytes end before the structure is complete.
final class TruncatedMessageException extends SyncDecodeException {
  const TruncatedMessageException(super.message);
}

/// A change batch includes a change whose origin seq is not covered by the
/// declared `(from, to]` range of its origin (D15, T10 acc. 6). The whole
/// batch is rejected.
final class BatchRangeViolationException extends SyncDecodeException {
  const BatchRangeViolationException(super.message);
}

/// The frame uses a wire-format version this build does not understand.
final class UnsupportedWireFormatException extends SyncDecodeException {
  UnsupportedWireFormatException(this.version) : super('unsupported wire format version $version');

  final int version;
}

/// The frame carries a message type this build does not know, e.g. from a
/// compatible newer peer that ignored the negotiated version. The frame is
/// complete, so a session may skip it or abort; nothing was decoded.
final class UnknownMessageTypeException extends SyncDecodeException {
  UnknownMessageTypeException(this.messageType) : super('unknown message type $messageType');

  final int messageType;
}
