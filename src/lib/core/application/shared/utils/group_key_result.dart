/// Result of reverse-mapping a board/group column key back to a concrete
/// task field value.
///
/// Use [GroupKeyResult.recognized] for "no value" outcomes (e.g. the "None"
/// column), and [GroupKeyResult.unrecognized] when the column key is not a
/// known group for the current sort field.
sealed class GroupKeyResult<T> {
  const GroupKeyResult();

  /// The key was recognized; [value] may still be null for "no value" groups
  /// (e.g. the "None" column for an optional field).
  const factory GroupKeyResult.recognized(T value) = Recognized<T>;

  /// The key was not recognized as a valid group for the current sort field.
  /// Callers should not mutate task state for unrecognized keys.
  const factory GroupKeyResult.unrecognized() = Unrecognized<T>;
}

/// Successful recognition of a group key. [value] may be null for "no value"
/// groups (e.g. the "None" column for an optional field).
class Recognized<T> extends GroupKeyResult<T> {
  final T value;
  const Recognized(this.value);
}

/// The key was not a known group for the current sort field.
class Unrecognized<T> extends GroupKeyResult<T> {
  const Unrecognized();
}
