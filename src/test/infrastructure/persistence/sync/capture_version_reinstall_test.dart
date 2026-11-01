import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_table_policy.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_generator.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/sync/sync_trigger_installer.dart';

import 'drift_sync_test_support.dart';

const _previousVersion = 'v38-4';
const _staleMarker = 'stale_trigger_text';

void main() {
  late SyncTestDevice device;

  setUp(() async => device = await SyncTestDevice.open('a'));
  tearDown(() async => device.close());

  Future<String> triggerSql(String name) async => (await device.rows(
          "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = '$name'"))
      .single['sql'] as String;

  test('a database stamped with the previous capture version gets the current triggers',
      () async {
    final policy = syncTablePolicies.firstWhere((p) => p.tableName == 'task_tag_table');
    final name = triggerName(policy, 'au');
    await device.sql('DROP TRIGGER $name');
    await device.sql(
        'CREATE TRIGGER $name AFTER UPDATE ON task_tag_table BEGIN SELECT 1 AS $_staleMarker; END');
    await device.sql(
        "UPDATE sync_state SET capture_version = '$_previousVersion' WHERE id = 'singleton'");
    expect(await triggerSql(name), contains(_staleMarker));

    await installSyncTriggers(device.db);

    final reinstalled = await triggerSql(name);
    expect(reinstalled, isNot(contains(_staleMarker)));
    expect(reinstalled, contains('NEW.deleted_date IS NULL'));
    final version = await device.rows(
        "SELECT capture_version AS v FROM sync_state WHERE id = 'singleton'");
    expect(version.single['v'], syncCaptureVersion);
    expect(syncCaptureVersion, isNot(_previousVersion));
  });
}
