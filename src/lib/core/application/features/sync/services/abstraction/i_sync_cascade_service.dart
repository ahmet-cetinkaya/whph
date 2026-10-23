/// D5b: scopes a cascading delete so the capture triggers stamp every child
/// tombstone with the deleted root item as its cause. Nested scopes keep the
/// outermost (root) cause.
abstract class ISyncCascadeService {
  /// Runs [operation] with `cascade_cause` set to (`causeTable`, `causePk`).
  Future<T> withCause<T>(
      String causeTable, String causePk, Future<T> Function() operation);
}
