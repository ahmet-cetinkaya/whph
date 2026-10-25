import 'package:acore/acore.dart' as acore;

abstract class IRepository<T extends acore.BaseEntity<TId>, TId>
    extends acore.IRepository<T, TId> {
  Future<void> hardDeleteSoftDeleted(DateTime beforeDate);
  Future<void> truncate();

  /// Updates multiple entities in a single batch operation.
  /// This is more efficient than calling update() multiple times.
  Future<void> updateMultiple(List<T> items);

  /// D5: insert-or-revive for deterministic-id creations. A soft-deleted row
  /// with the same id is revived (`deleted_date = NULL`) and its synced
  /// columns refreshed, so the capture trigger writes a `~` revival cell.
  Future<void> upsertRevive(T item);
}
