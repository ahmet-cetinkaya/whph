# Step 5: Sync Integration

Every user table that should reach other devices must be registered with the
sync engine. Registration is **required**, not optional: an unregistered table
silently never syncs. Background and design:
[SYNC.md](../SYNC.md).

## 1. Decide the sync level

| Level | Use for | Captured cells |
| ----- | ------- | -------------- |
| Field level | Editable entities (tasks, notes, tags) | One per synced column, plus `~` |
| Row level | Append-style records, join tables, rules | One `*` cell, plus `~` |

Rows must carry `id`, `created_date`, `modified_date` and `deleted_date`. These
four are never synced as cells. Deletes must be soft (`deleted_date`), because
the deletion becomes the `~` existence cell.

## 2. Register the table

**Location**:
`src/lib/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart`

```dart
const SyncTablePolicy(
  tableName: 'your_entity_table',
  tblId: 14, // example: use the next free id below 100; never reuse or renumber
  rowLevel: false,
  columns: {'title': 2, 'notes': 3}, // fixed col ids, 2 and up
),
```

`tblId` and `colId` are baked into generated trigger SQL. Changing one is a
migration decision, not a refactor. Ids 100 and above are reserved for the
security tables.

## 3. Install the triggers

Bump the schema version and make the migration (and `onCreate`) install triggers
for the new table through the existing trigger installer. Do not hand-write
trigger SQL.

## 4. Writes that need care

- **Cascading deletes:** a command that soft-deletes children must set the
  cascade cause for the transaction so child tombstones revive with the parent.
  See the existing delete commands for tasks, habits, notes and tags.
- **Records two devices can create independently** (for example one per day):
  use a deterministic UUIDv5 id from
  `core/application/shared/utils/sync_identity.dart`.
- **Time-like records:** write only your own per-device bucket and sum all live
  buckets for totals ([SYNC.md](../SYNC.md#time-records-and-set-total-semantics)).
- Never write a synced table while `sync_state.apply_mode` is non-zero outside
  the sync layer; that mode disables change capture.

## 5. Tests

Add the table to the convergence tests in `packages/whph_sync_core` and the
trigger and merge tests under `src/test`, then run:

```sh
cd src && fvm flutter test test/infrastructure/persistence/ test/core/application/features/sync/
```

Export and import need no sync-specific code; exports exclude all sync tables
and keys.
