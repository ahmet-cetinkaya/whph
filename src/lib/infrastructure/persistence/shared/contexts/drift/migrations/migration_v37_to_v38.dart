import 'package:drift/drift.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.steps.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_installer.dart';

/// v37 -> v38: sync persistence DDL (D1, D13), legacy pairing marking and the
/// five FK indexes; sets upgrade_phase = 'dedupe' for the T17 job.
Future<void> migrateV37ToV38(
    AppDatabase db, Migrator m, Schema38 schema) async {
  await m.createTable(db.syncStateTable);
  await m.createTable(db.syncInternTable);
  await m.createTable(db.syncRowTable);
  await m.createTable(db.syncClockTable);
  await m.createTable(db.syncMemberTableTable);
  await m.createTable(db.syncOriginTable);
  await m.createTable(db.syncRevocationTable);
  await m.createTable(db.syncEpochGrantTable);
  await m.createTable(db.syncOriginBatchTable);
  await m.createTable(db.syncVectorTable);
  await m.createTable(db.syncPeerStateTableTable);
  await m.createTable(db.syncHeldEnvelopeTable);
  await m.createTable(db.syncHeldCellTable);
  await m.createTable(db.syncSupersededTable);

  await createSyncV38Indexes(m);

  // Legacy pairing marking (FR-061): every existing device row needs repair.
  await m.addColumn(db.syncDeviceTable, db.syncDeviceTable.needsRepair);
  await db.customStatement('UPDATE sync_device_table SET needs_repair = 1');

  // The upgrade job (T17) starts from 'dedupe'.
  await db.customStatement(
      "INSERT INTO sync_state (id, apply_mode, next_seq, hlc, upgrade_phase) "
      "VALUES ('singleton', 0, 1, 0, 'dedupe') "
      "ON CONFLICT(id) DO UPDATE SET upgrade_phase = 'dedupe'");

  await installSyncTriggers(db);
}

/// The v38 indexes (sync clock scans and the PA-1/S5 foreign-key indexes). A
/// fresh install creates them in onCreate as well: without them every sync
/// page scans and sorts the whole clock table (T28).
Future<void> createSyncV38Indexes(Migrator m) async {
  await m.createIndex(Index('sync_clock_origin_seq_key_idx',
      'CREATE INDEX IF NOT EXISTS sync_clock_origin_seq_key_idx ON sync_clock (origin_id, origin_seq, key)'));
  await m.createIndex(Index('sync_clock_cause_idx',
      'CREATE INDEX IF NOT EXISTS sync_clock_cause_idx ON sync_clock (cause_row_id) WHERE cause_row_id IS NOT NULL'));

  // PA-1/S5 FK indexes.
  await m.createIndex(Index('task_tag_task_id_idx',
      'CREATE INDEX IF NOT EXISTS task_tag_task_id_idx ON task_tag_table (task_id)'));
  await m.createIndex(Index('task_time_record_task_id_idx',
      'CREATE INDEX IF NOT EXISTS task_time_record_task_id_idx ON task_time_record_table (task_id)'));
  await m.createIndex(Index('task_parent_task_id_idx',
      'CREATE INDEX IF NOT EXISTS task_parent_task_id_idx ON task_table (parent_task_id)'));
  await m.createIndex(Index('task_recurrence_parent_id_idx',
      'CREATE INDEX IF NOT EXISTS task_recurrence_parent_id_idx ON task_table (recurrence_parent_id)'));
  await m.createIndex(Index('task_status_id_idx',
      'CREATE INDEX IF NOT EXISTS task_status_id_idx ON task_table (status_id)'));
}
