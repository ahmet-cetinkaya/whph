import 'package:flutter_test/flutter_test.dart';

import 'drift_sync_test_support.dart';

/// A fresh install builds its schema in onCreate, not through the v37->v38
/// migration. Without these indexes every sync page scanned and sorted the
/// whole clock table (T28: first sync grew ~n^1.4).
const _requiredIndexes = {
  'sync_clock_origin_seq_key_idx',
  'sync_clock_cause_idx',
  'task_tag_task_id_idx',
  'task_time_record_task_id_idx',
  'task_parent_task_id_idx',
  'task_recurrence_parent_id_idx',
  'task_status_id_idx',
};

void main() {
  test('a freshly created database has the v38 sync and foreign-key indexes',
      () async {
    final device = await SyncTestDevice.open('a');
    addTearDown(device.close);

    final rows = await device
        .rows("SELECT name FROM sqlite_master WHERE type = 'index'");
    final present = rows.map((row) => row['name']).toSet();

    expect(present.containsAll(_requiredIndexes), isTrue,
        reason: 'missing: ${_requiredIndexes.difference(present)}');
  });
}
