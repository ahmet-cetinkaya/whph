// T27 part 1, US3: Scenarios 3.1 to 3.4 and SC-007 (runtime duplicates after
// syncing, and identity violations after upgrading the duplicate fixtures).
// Application commands and services on real Drift devices, the sync engine for
// every session; the upgrade runs the production SyncUpgradeJob over the
// synthetic v37 fixtures.
@Timeout(Duration(minutes: 8))
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/infrastructure/persistence/features/sync/services/sync_upgrade_job.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import '../../fixtures/sync/fixture_builder.dart' show duplicatesFixture, duplicatesShuffledFixture;
import 'support1/acceptance_fleet.dart';
import 'support1/identity_harness.dart';
import 'support1/upgrade_fixture.dart';

const String _habitRecords = 'habit_record_table';
const String _task = 'task_table';
const int _secondsPerDay = 24 * 60 * 60;
const int _seriesFirstPlanned = 1772359200; // 2026-03-01T10:00:00Z
const String _seriesId = 'series';
const String _nextOccurrenceDay = '2026-03-02';
const String _workTimeKey = 'WORK_TIME';
const String _workTimeNewestValue = '50';
const String _todoStatusId = 'task-status-builtin-todo';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AcceptanceFleet fleet;

  setUp(() async => fleet = await AcceptanceFleet.open());
  tearDown(() => fleet.close());

  Future<(FleetDevice, FleetDevice, DeviceServices, DeviceServices)> pairOfDevices({int bAheadHours = 0}) async {
    final a = await fleet.add('A');
    final b = await fleet.add('B', inviter: a, clockAheadHours: bAheadHours);
    return (a, b, DeviceServices(a), DeviceServices(b));
  }

  Future<List<Map<String, Object?>>> liveRows(FleetDevice device, String table, String where) =>
      device.database.rows('SELECT * FROM $table WHERE deleted_date IS NULL AND ($where)');

  test('Scenario 3.1 a habit day marked done on A and skipped on B ends as one record with the later status', () async {
    final (a, b, servicesA, servicesB) = await pairOfDevices(bAheadHours: 1);
    await servicesA.insertHabit('h1');
    await fleet.settleOver([('A', 'B')]);
    final day = DateTime.utc(2026, 3, 1, 12);

    await servicesA.recordHabit('h1', day, HabitRecordStatus.complete);
    await servicesB.recordHabit('h1', day, HabitRecordStatus.skipped);
    final skippedStatus = (await liveRows(b, _habitRecords, '1=1')).single['status'];
    expect(skippedStatus, isNot((await liveRows(a, _habitRecords, '1=1')).single['status']), reason: 'edits conflict');
    await fleet.settleOver([('A', 'B')]);

    for (final device in [a, b]) {
      final records = await liveRows(device, _habitRecords, "habit_id = 'h1'");
      expect(records, hasLength(1), reason: device.name);
      expect(records.single['status'], skippedStatus, reason: '${device.name}: the later edit (B) decides');
    }
    await expectIdenticalData([a, b], [_habitRecords]);
    await expectNoIdentityViolations(a.database.db, device: 'A');
    await expectNoIdentityViolations(b.database.db, device: 'B');
  });

  Future<void> createDailySeries(FleetDevice device) => device.sql(
        'INSERT INTO task_table (id, created_date, title, planned_date, recurrence_type, recurrence_interval, '
        "recurrence_start_date) VALUES ('$_seriesId', 1, 'Daily series', $_seriesFirstPlanned, 1, 1, $_seriesFirstPlanned)",
      );

  test('Scenario 3.2 two devices each generating the next occurrence leave exactly one for that date', () async {
    final (a, b, servicesA, servicesB) = await pairOfDevices();
    await createDailySeries(a);
    await fleet.settleOver([('A', 'B')]);

    final occurrenceOnA = await servicesA.completeRecurringTask(_seriesId, _seriesFirstPlanned + 60);
    final occurrenceOnB = await servicesB.completeRecurringTask(_seriesId, _seriesFirstPlanned + 120);
    final expectedId = syncIdentityId(identityKindRecurringTask, [_seriesId, _nextOccurrenceDay]);
    expect([occurrenceOnA, occurrenceOnB], [expectedId, expectedId], reason: 'both devices derive the same identity');
    await fleet.settleOver([('A', 'B')]);

    for (final device in [a, b]) {
      final occurrences = await liveRows(device, _task, "recurrence_parent_id = '$_seriesId'");
      expect(occurrences, hasLength(1), reason: device.name);
      expect(occurrences.single['id'], expectedId, reason: device.name);
      expect(
          (occurrences.single['planned_date']! as int) ~/ _secondsPerDay, (_seriesFirstPlanned ~/ _secondsPerDay) + 1,
          reason: '${device.name}: planned on the next calendar day');
    }
    await expectIdenticalData([a, b], [_task]);
    await expectNoIdentityViolations(a.database.db, device: 'A');
  });

  group('upgrade of databases seeded with duplicates', () {
    late UpgradeFixtures fixtures;
    late List<DuplicateGroup> groups;

    setUpAll(() async {
      fixtures = await UpgradeFixtures.build(duplicatesFixture);
      groups = fixtures.groups;
    });

    tearDownAll(() => fixtures.close());

    test('Scenario 3.3 two settings with the same key become one with the most recent value', () async {
      final db = await fixtures.openUpgraded();
      final keys = [for (final g in groups.where((g) => g.rule == 'setting_key')) g.key];
      expect(keys, contains(_workTimeKey));
      for (final key in keys) {
        expect(await selectCount(db, 'SELECT COUNT(*) FROM setting_table WHERE key = ?', [key]), greaterThan(1),
            reason: 'fixture holds duplicates of $key before the upgrade');
      }

      expect(await SyncUpgradeJob(db).runChunks(), isTrue);

      for (final key in keys) {
        expect(await selectCount(db, 'SELECT COUNT(*) FROM setting_table WHERE key = ?', [key]), 1, reason: key);
      }
      final workTime = await selectRows(db, 'SELECT value FROM setting_table WHERE key = ?', [_workTimeKey]);
      expect(workTime.single['value'], _workTimeNewestValue, reason: 'the most recently edited value survives');
    });

    test('Scenario 3.4 merged duplicate occurrences keep every tag and every time record', () async {
      final db = await fixtures.openUpgraded();
      final occurrenceGroups = groups.where((g) => g.rule == 'recurring_occurrence').toList();
      final tagsToKeep = <String, Set<String>>{};
      final timeRecordsToKeep = <String, List<String>>{};
      for (final group in occurrenceGroups) {
        tagsToKeep[group.key] = {
          for (final linkId in group.liveDependentIds('task_tag_table'))
            (await selectRows(db, 'SELECT tag_id FROM task_tag_table WHERE id = ?', [linkId])).single['tag_id']!
                as String,
        };
        timeRecordsToKeep[group.key] = group.liveDependentIds('task_time_record_table');
      }
      expect(tagsToKeep.values.any((tags) => tags.isNotEmpty), isTrue);
      expect(timeRecordsToKeep.values.any((ids) => ids.isNotEmpty), isTrue);

      expect(await SyncUpgradeJob(db).runChunks(), isTrue);

      for (final group in occurrenceGroups) {
        final root = group.key.split('|').first;
        final day = group.key.split('|').last;
        final survivors = await selectRows(
            db,
            'SELECT id FROM task_table WHERE deleted_date IS NULL AND COALESCE(recurrence_parent_id, id) = ? '
            "AND date(planned_date, 'unixepoch') = ?",
            [root, day]);
        expect(survivors, hasLength(1), reason: group.key);
        final survivor = survivors.single['id']! as String;
        final tags = {
          for (final row in await selectRows(
              db, 'SELECT tag_id FROM task_tag_table WHERE task_id = ? AND deleted_date IS NULL', [survivor]))
            row['tag_id']! as String,
        };
        expect(tags, containsAll(tagsToKeep[group.key]!), reason: 'tags of ${group.key}');
        for (final recordId in timeRecordsToKeep[group.key]!) {
          final record =
              await selectRows(db, 'SELECT task_id, deleted_date FROM task_time_record_table WHERE id = ?', [recordId]);
          expect(record, hasLength(1), reason: 'time record $recordId');
          expect(record.single['task_id'], survivor, reason: 'time record $recordId');
          expect(record.single['deleted_date'], isNull, reason: 'time record $recordId');
        }
      }
    });

    for (final fixtureName in [duplicatesFixture, duplicatesShuffledFixture]) {
      test('SC-007 after upgrading $fixtureName no identity rule is violated and no link, time record or child is lost',
          () async {
        final source = fixtureName == duplicatesFixture ? fixtures : await UpgradeFixtures.build(fixtureName);
        addTearDown(() async {
          if (source != fixtures) await source.close();
        });
        final db = await source.openUpgraded();
        final before = await identityViolations(db);
        expect(before.values.fold(0, (sum, count) => sum + count), greaterThan(0),
            reason: 'the fixture has duplicates');
        final occurrenceKeyOf = {
          for (final g in source.groups.where((g) => g.rule == 'recurring_occurrence'))
            for (final id in g.ids) id: g.key,
        };
        final linksExpected = await _distinctLiveLinks(db, ownerIdentity: (id) => occurrenceKeyOf[id] ?? id);
        final orphansBefore = await _orphanedChildren(db);
        final timeRecordsBefore =
            await selectCount(db, 'SELECT COUNT(*) FROM task_time_record_table WHERE deleted_date IS NULL');
        final loserIds = {for (final g in source.groups.where((g) => g.rule == 'recurring_occurrence')) ...g.ids};
        final childrenBefore = {
          for (final row in await selectRows(
              db, 'SELECT id FROM task_table WHERE deleted_date IS NULL AND parent_task_id IS NOT NULL'))
            row['id']! as String,
        }.difference(loserIds);

        expect(await SyncUpgradeJob(db).runChunks(), isTrue);

        await expectNoIdentityViolations(db, device: fixtureName);
        expect(await _liveLinkCounts(db), linksExpected, reason: 'one live link per tag per item, none lost');
        expect(await selectCount(db, 'SELECT COUNT(*) FROM task_time_record_table WHERE deleted_date IS NULL'),
            timeRecordsBefore,
            reason: 'time records are moved, not dropped');
        final childrenAfter = {
          for (final row in await selectRows(
              db, 'SELECT id FROM task_table WHERE deleted_date IS NULL AND parent_task_id IS NOT NULL'))
            row['id']! as String,
        };
        expect(childrenAfter, containsAll(childrenBefore), reason: 'child items are kept');
        expect(await _orphanedChildren(db), lessThanOrEqualTo(orphansBefore),
            reason: 'no child is orphaned by the merge');
      });
    }
  });

  test('SC-007 after syncing identity-rule items created on two devices, no rule is violated and each exists once',
      () async {
    final (a, b, servicesA, servicesB) = await pairOfDevices(bAheadHours: 1);
    await servicesA.insertHabit('h1');
    await servicesA.insertTag('tagA');
    await servicesA.insertTag('tagB');
    await a.insertTask('t1', 'task');
    await createDailySeries(a);
    await fleet.settleOver([('A', 'B')]);
    final day = DateTime.utc(2026, 3, 1, 12);

    for (final (device, services, value) in [(a, servicesA, 'value from A'), (b, servicesB, 'value from B')]) {
      await services.recordHabit('h1', day, HabitRecordStatus.complete);
      await services.saveSetting('THEME', value);
      await services.tagTask('t1', 'tagA');
      await services.tagHabit('h1', 'tagA');
      await services.linkTags('tagA', 'tagB');
      await services.insertBuiltInTodoStatus();
      await services.completeRecurringTask(_seriesId, _seriesFirstPlanned + 60);
      expect(await liveRows(device, 'setting_table', "key = 'THEME'"), hasLength(1), reason: device.name);
    }
    await fleet.settleOver([('A', 'B')]);

    for (final device in [a, b]) {
      final db = device.database.db;
      await expectNoIdentityViolations(db, device: device.name);
      for (final (table, where) in [
        (_habitRecords, "habit_id = 'h1'"),
        ('setting_table', "key = 'THEME'"),
        ('task_tag_table', "task_id = 't1'"),
        ('habit_tag_table', "habit_id = 'h1'"),
        ('tag_tag_table', "primary_tag_id = 'tagA'"),
        ('task_status_table', "id = '$_todoStatusId'"),
        (_task, "recurrence_parent_id = '$_seriesId'"),
      ]) {
        expect(await liveRows(device, table, where), hasLength(1), reason: '${device.name}: $table');
      }
      expect(await liveRows(device, 'sync_member_table', '1=1'), hasLength(2),
          reason: '${device.name}: one entry per device');
    }
    await expectIdenticalData([
      a,
      b
    ], [
      _habitRecords,
      'setting_table',
      'task_tag_table',
      'habit_tag_table',
      'tag_tag_table',
      'task_status_table',
      _task
    ]);
  });
}

const Map<String, (String, String)> _linkColumns = {
  'task_tag_table': ('task_id', 'tag_id'),
  'habit_tag_table': ('habit_id', 'tag_id'),
  'note_tag_table': ('note_id', 'tag_id'),
  'app_usage_tag_table': ('app_usage_id', 'tag_id'),
  'tag_tag_table': ('primary_tag_id', 'secondary_tag_id'),
};

/// Per link table, how many distinct (owner identity, tag) pairs the live
/// links hold; [ownerIdentity] maps an owner id to the item it will merge into.
Future<Map<String, int>> _distinctLiveLinks(AppDatabase db, {required String Function(String) ownerIdentity}) async {
  final counts = <String, int>{};
  for (final entry in _linkColumns.entries) {
    final (owner, tag) = entry.value;
    final rows = await selectRows(db, 'SELECT $owner AS o, $tag AS t FROM ${entry.key} WHERE deleted_date IS NULL');
    counts[entry.key] = {for (final row in rows) '${ownerIdentity(row['o']! as String)}|${row['t']}'}.length;
  }
  return counts;
}

Future<Map<String, int>> _liveLinkCounts(AppDatabase db) async => {
      for (final table in _linkColumns.keys)
        table: await selectCount(db, 'SELECT COUNT(*) FROM $table WHERE deleted_date IS NULL'),
    };

Future<int> _orphanedChildren(AppDatabase db) => selectCount(
    db,
    'SELECT COUNT(*) FROM task_table c WHERE c.deleted_date IS NULL AND c.parent_task_id IS NOT NULL '
    'AND NOT EXISTS (SELECT 1 FROM task_table p WHERE p.id = c.parent_task_id AND p.deleted_date IS NULL)');
