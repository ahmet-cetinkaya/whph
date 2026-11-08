// T27 part 2, SC-009 and Scenarios 5.1 to 5.3 (FR-050, FR-051): a catalog of
// every user-visible edit action on every synced data type. Each action is made
// on device A and must be visible on device B after ONE sync session, with the
// whole synced content of both devices equal afterwards.
//
// The actions write the columns the repositories write (SQL); the actions that
// carry logic of their own run through the real services: time-record buckets
// and set-total, note order normalisation and the import handler.
//
// Not covered here (no headless way to drive the widgets): the screens that
// call these actions. The catalog lists the action behind each screen.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';
import 'package:whph/main.mapper.g.dart' show initializeJsonMapper;

import '../../infrastructure/persistence/sync/local_reset_test_support.dart';
import 'support2/data_ops.dart';
import 'support2/lab.dart';
import 'support2/services.dart';

typedef _Perform = Future<void> Function(LabDevice a);
typedef _Verify = Future<void> Function(LabDevice a, LabDevice b);

class _EditAction {
  final String id;
  final String type;
  final _Perform perform;
  final _Verify verify;

  const _EditAction(this.id, this.type, this.perform, this.verify);
}

final DateTime _hour = DateTime.utc(2026, 3, 2, 10);
const int _bulkCount = 20;
const int _habitRecordStatusComplete = 1;
const int _settingValueTypeString = 0;

String _day(DateTime at) => at.toIso8601String().substring(0, 10);

Future<void> _expectCell(LabDevice b, String table, String id, String column, Object? expected) async =>
    expect(await cellOf(b, table, id, column), expected, reason: '$table.$id.$column');

Future<void> _expectDeleted(LabDevice b, String table, String id) async =>
    expect(await cellOf(b, table, id, 'deleted_date'), isNotNull, reason: '$table.$id is deleted');

Future<void> _expectRow(LabDevice b, String table, String id) async =>
    expect(await findRow(b, table, id), isNotNull, reason: '$table.$id exists');

/// The base items every action edits; synced to B before the catalog runs.
Future<void> _seedBase(LabDevice a) async {
  await addTask(a, 't-edit', 'task to edit');
  await addTask(a, 't-reorder', 'task to reorder');
  await addTask(a, 't-parent', 'task with children');
  await addTask(a, 't-time', 'task with time');
  await addTask(a, 't-tag', 'task to tag');
  await addTask(a, 't-recur', 'recurring root', extra: {'recurrence_type': 1, 'recurrence_interval': 1});
  for (var i = 0; i < _bulkCount; i++) {
    await addTask(a, 'bulk-$i', 'bulk task $i', extra: {'priority': 0});
  }
  await insertRow(a, 'habit_table', {'id': 'h-edit', 'name': 'habit', 'description': 'daily'});
  await insertRow(a, 'habit_table', {'id': 'h-time', 'name': 'habit with time', 'description': ''});
  for (var i = 0; i < 5; i++) {
    await addNote(a, 'n-$i', 'note $i', order: 'order-$i');
  }
  await addNote(a, 'n-edit', 'note to edit', content: 'old body');
  await addTag(a, 'tg-1', 'tag one');
  await addTag(a, 'tg-2', 'tag two');
  await addTag(a, 'tg-3', 'tag three');
  await addAppUsage(a, 'au-1', 'editor.exe');
  await insertRow(a, 'task_status_table', {'id': 'st-1', 'name': 'doing'});
  await insertRow(
      a, 'setting_table', {'id': 'setting-seed', 'key': 'seed', 'value': 'v0', 'value_type': _settingValueTypeString});
}

List<_EditAction> _catalog() {
  final taskTagId = joinId(identityKindTaskTag, 't-tag', 'tg-1');
  final noteTagId = joinId(identityKindNoteTag, 'n-edit', 'tg-1');
  final habitTagId = joinId(identityKindHabitTag, 'h-edit', 'tg-2');
  final appUsageTagId = joinId(identityKindAppUsageTag, 'au-1', 'tg-3');
  final tagLinkId = joinId(identityKindTagTag, 'tg-1', 'tg-2');
  final habitRecordId = syncIdentityId(identityKindHabitRecord, ['h-edit', _day(_hour)]);
  final settingId = syncIdentityId(identityKindSetting, ['theme']);
  return [
    // -- tasks (with tags, time records and statuses)
    _EditAction('task.create', 'task', (a) => addTask(a, 't-new', 'new task'),
        (a, b) => _expectCell(b, 'task_table', 't-new', 'title', 'new task')),
    _EditAction(
        'task.edit_fields',
        'task',
        (a) => updateRow(a, 'task_table', 't-edit', {
              'title': 'edited title',
              'description': 'edited description',
              'priority': 2,
              'planned_date': 1800000000,
              'deadline_date': 1800086400,
              'estimated_time': 45,
            }), (a, b) async {
      await _expectCell(b, 'task_table', 't-edit', 'title', 'edited title');
      await _expectCell(b, 'task_table', 't-edit', 'description', 'edited description');
      await _expectCell(b, 'task_table', 't-edit', 'priority', 2);
      await _expectCell(b, 'task_table', 't-edit', 'planned_date', 1800000000);
      await _expectCell(b, 'task_table', 't-edit', 'estimated_time', 45);
    }),
    _EditAction('task.complete', 'task', (a) => updateRow(a, 'task_table', 't-edit', {'completed_at': 1800000100}),
        (a, b) => _expectCell(b, 'task_table', 't-edit', 'completed_at', 1800000100)),
    _EditAction('task.change_status', 'task', (a) => updateRow(a, 'task_table', 't-edit', {'status_id': 'st-1'}),
        (a, b) => _expectCell(b, 'task_table', 't-edit', 'status_id', 'st-1')),
    _EditAction('task.reorder', 'task', (a) => updateRow(a, 'task_table', 't-reorder', {'order': 'AAA'}),
        (a, b) => _expectCell(b, 'task_table', 't-reorder', 'order', 'AAA')),
    _EditAction(
        'task.add_subtask',
        'task',
        (a) => addTask(a, 't-child', 'subtask', extra: {'parent_task_id': 't-parent'}),
        (a, b) => _expectCell(b, 'task_table', 't-child', 'parent_task_id', 't-parent')),
    _EditAction('task.delete', 'task', (a) => softDeleteRow(a, 'task_table', 't-child'),
        (a, b) => _expectDeleted(b, 'task_table', 't-child')),
    _EditAction('task.bulk_edit', 'task', (a) => a.db.sql("UPDATE task_table SET priority = 3 WHERE id LIKE 'bulk-%'"),
        (a, b) async {
      final changed = await b.db.count("SELECT COUNT(*) FROM task_table WHERE id LIKE 'bulk-%' AND priority = 3");
      expect(changed, _bulkCount);
    }),
    _EditAction('task.recurring_generation', 'task', (a) async {
      for (final day in ['2026-03-03', '2026-03-04', '2026-03-05']) {
        await addTask(a, syncIdentityId(identityKindRecurringTask, ['t-recur', day]), 'recurring root',
            extra: {'recurrence_parent_id': 't-recur', 'planned_date': 1800000000});
      }
    }, (a, b) async {
      final occurrences = await b.db.count("SELECT COUNT(*) FROM task_table WHERE recurrence_parent_id = 't-recur'");
      expect(occurrences, 3);
    }),
    _EditAction(
        'task_tag.add',
        'task tag',
        (a) => insertRow(a, 'task_tag_table', {'id': taskTagId, 'task_id': 't-tag', 'tag_id': 'tg-1'}),
        (a, b) => _expectRow(b, 'task_tag_table', taskTagId)),
    _EditAction('task_tag.remove', 'task tag', (a) => softDeleteRow(a, 'task_tag_table', taskTagId),
        (a, b) => _expectDeleted(b, 'task_tag_table', taskTagId)),
    _EditAction('task_time.add', 'task time record', (a) => addTaskTime(a, 't-time', _hour, 600), (a, b) async {
      expect(await totalDuration(b, 'task_time_record_table', 'task_id', 't-time'), 600);
      const hourOf = "SELECT created_date AS hour FROM task_time_record_table WHERE task_id = 't-time'";
      expect(await b.db.rows(hourOf), await a.db.rows(hourOf), reason: 'the hour bucket travels with the record');
    }),
    _EditAction('task_time.set_total', 'task time record', (a) => setTaskTimeTotal(a, 't-time', _hour, 1500),
        (a, b) async {
      expect(await totalDuration(b, 'task_time_record_table', 'task_id', 't-time'), 1500);
    }),
    _EditAction(
        'task_status.create',
        'task status',
        (a) => insertRow(a, 'task_status_table', {'id': 'st-2', 'name': 'review'}),
        (a, b) => _expectCell(b, 'task_status_table', 'st-2', 'name', 'review')),
    _EditAction(
        'task_status.edit',
        'task status',
        (a) => updateRow(a, 'task_status_table', 'st-2', {'name': 'in review', 'color': 'ff0000'}),
        (a, b) => _expectCell(b, 'task_status_table', 'st-2', 'name', 'in review')),
    // -- habits (with records, tags and time records)
    _EditAction(
        'habit.create',
        'habit',
        (a) => insertRow(a, 'habit_table', {'id': 'h-new', 'name': 'new habit', 'description': ''}),
        (a, b) => _expectCell(b, 'habit_table', 'h-new', 'name', 'new habit')),
    _EditAction(
        'habit.edit',
        'habit',
        (a) => updateRow(a, 'habit_table', 'h-edit', {
              'name': 'renamed habit',
              'has_goal': 1,
              'daily_target': 3,
              'has_reminder': 1,
              'reminder_time': '08:00'
            }), (a, b) async {
      await _expectCell(b, 'habit_table', 'h-edit', 'name', 'renamed habit');
      await _expectCell(b, 'habit_table', 'h-edit', 'daily_target', 3);
      await _expectCell(b, 'habit_table', 'h-edit', 'reminder_time', '08:00');
    }),
    _EditAction('habit.archive', 'habit', (a) => updateRow(a, 'habit_table', 'h-edit', {'archived_date': 1800000200}),
        (a, b) => _expectCell(b, 'habit_table', 'h-edit', 'archived_date', 1800000200)),
    _EditAction('habit.reorder', 'habit', (a) => updateRow(a, 'habit_table', 'h-edit', {'order': 'BBB'}),
        (a, b) => _expectCell(b, 'habit_table', 'h-edit', 'order', 'BBB')),
    _EditAction(
        'habit_record.add',
        'habit record',
        (a) => insertRow(a, 'habit_record_table', {
              'id': habitRecordId,
              'habit_id': 'h-edit',
              'occurred_at': _hour.millisecondsSinceEpoch ~/ 1000,
              'status': _habitRecordStatusComplete
            }),
        (a, b) => _expectRow(b, 'habit_record_table', habitRecordId)),
    _EditAction('habit_record.remove', 'habit record', (a) => softDeleteRow(a, 'habit_record_table', habitRecordId),
        (a, b) => _expectDeleted(b, 'habit_record_table', habitRecordId)),
    _EditAction(
        'habit_tag.add',
        'habit tag',
        (a) => insertRow(a, 'habit_tag_table', {'id': habitTagId, 'habit_id': 'h-edit', 'tag_id': 'tg-2'}),
        (a, b) => _expectRow(b, 'habit_tag_table', habitTagId)),
    _EditAction('habit_time.add', 'habit time record', (a) => addHabitTime(a, 'h-time', _hour, 900), (a, b) async {
      expect(await totalDuration(b, 'habit_time_record_table', 'habit_id', 'h-time'), 900);
    }),
    _EditAction('habit_time.set_total', 'habit time record', (a) => setHabitTimeTotal(a, 'h-time', _hour, 2400),
        (a, b) async {
      expect(await totalDuration(b, 'habit_time_record_table', 'habit_id', 'h-time'), 2400);
    }),
    _EditAction('habit.delete', 'habit', (a) => softDeleteRow(a, 'habit_table', 'h-new'),
        (a, b) => _expectDeleted(b, 'habit_table', 'h-new')),
    // -- notes (with tags and order)
    _EditAction('note.create', 'note', (a) => addNote(a, 'n-new', 'new note', content: 'new body'),
        (a, b) => _expectCell(b, 'note_table', 'n-new', 'content', 'new body')),
    _EditAction(
        'note.edit',
        'note',
        (a) => updateRow(a, 'note_table', 'n-edit', {'title': 'edited note', 'content': 'new body'}),
        (a, b) => _expectCell(b, 'note_table', 'n-edit', 'content', 'new body')),
    _EditAction('note.reorder', 'note', (a) async {
      // Scenario 5.1: drag the last note to the top, then the order screen renumbers all.
      await updateRow(a, 'note_table', 'n-4', {'order': 'order-'});
      await normalizeNoteOrders(a);
    }, (a, b) async {
      Future<String> order(String id) async => '${await cellOf(b, 'note_table', id, 'order')}';
      final orders = [
        await order('n-4'),
        await order('n-0'),
        await order('n-1'),
        await order('n-2'),
        await order('n-3')
      ];
      expect(orders, [...orders]..sort(), reason: 'B shows the same order as A (Scenario 5.1)');
      expect(orders.toSet(), hasLength(5));
      expect(orders.first, await cellOf(a, 'note_table', 'n-4', 'order'));
    }),
    _EditAction(
        'note_tag.add',
        'note tag',
        (a) => insertRow(a, 'note_tag_table', {'id': noteTagId, 'note_id': 'n-edit', 'tag_id': 'tg-1'}),
        (a, b) => _expectRow(b, 'note_tag_table', noteTagId)),
    _EditAction('note.bulk_edit', 'note',
        (a) => a.db.sql("UPDATE note_table SET content = 'bulk body' WHERE id LIKE 'n-%' AND id != 'n-edit'"),
        (a, b) async {
      final changed = await b.db.count("SELECT COUNT(*) FROM note_table WHERE content = 'bulk body'");
      expect(changed, greaterThanOrEqualTo(5));
    }),
    _EditAction('note.delete', 'note', (a) => softDeleteRow(a, 'note_table', 'n-new'),
        (a, b) => _expectDeleted(b, 'note_table', 'n-new')),
    // -- tags (with tag-to-tag links)
    _EditAction('tag.create', 'tag', (a) => addTag(a, 'tg-new', 'new tag'),
        (a, b) => _expectCell(b, 'tag_table', 'tg-new', 'name', 'new tag')),
    _EditAction('tag.edit', 'tag',
        (a) => updateRow(a, 'tag_table', 'tg-1', {'name': 'renamed tag', 'color': 'abcdef', 'is_archived': 1}),
        (a, b) async {
      await _expectCell(b, 'tag_table', 'tg-1', 'name', 'renamed tag');
      await _expectCell(b, 'tag_table', 'tg-1', 'is_archived', 1);
    }),
    _EditAction(
        'tag_tag.link',
        'tag link',
        (a) => insertRow(a, 'tag_tag_table', {'id': tagLinkId, 'primary_tag_id': 'tg-1', 'secondary_tag_id': 'tg-2'}),
        (a, b) => _expectRow(b, 'tag_tag_table', tagLinkId)),
    _EditAction('tag_tag.unlink', 'tag link', (a) => softDeleteRow(a, 'tag_tag_table', tagLinkId),
        (a, b) => _expectDeleted(b, 'tag_tag_table', tagLinkId)),
    // -- app usages (with tags, time records, tag rules and ignore rules)
    _EditAction('app_usage.tracked', 'app usage', (a) async {
      await addAppUsage(a, 'au-tracked', 'browser.exe');
      await addAppUsageTime(a, 'aut-1', 'au-tracked', _hour, 300);
    }, (a, b) async {
      await _expectCell(b, 'app_usage_table', 'au-tracked', 'name', 'browser.exe');
      expect(await totalDuration(b, 'app_usage_time_record_table', 'app_usage_id', 'au-tracked'), 300);
    }),
    _EditAction('app_usage.time_add', 'app usage time record',
        (a) => addAppUsageTime(a, 'aut-2', 'au-tracked', _hour.add(const Duration(hours: 1)), 200), (a, b) async {
      expect(await totalDuration(b, 'app_usage_time_record_table', 'app_usage_id', 'au-tracked'), 500);
    }),
    _EditAction(
        'app_usage.edit',
        'app usage',
        (a) => updateRow(a, 'app_usage_table', 'au-1', {'display_name': 'Editor', 'color': '00ff00'}),
        (a, b) => _expectCell(b, 'app_usage_table', 'au-1', 'display_name', 'Editor')),
    _EditAction(
        'app_usage_tag.add',
        'app usage tag',
        (a) => insertRow(a, 'app_usage_tag_table', {'id': appUsageTagId, 'app_usage_id': 'au-1', 'tag_id': 'tg-3'}),
        (a, b) => _expectRow(b, 'app_usage_tag_table', appUsageTagId)),
    _EditAction(
        'app_usage_tag_rule.add',
        'tag rule',
        (a) => insertRow(a, 'app_usage_tag_rule_table', {'id': 'rule-1', 'pattern': '*.exe', 'tag_id': 'tg-3'}),
        (a, b) => _expectCell(b, 'app_usage_tag_rule_table', 'rule-1', 'pattern', '*.exe')),
    _EditAction('app_usage_tag_rule.remove', 'tag rule', (a) => softDeleteRow(a, 'app_usage_tag_rule_table', 'rule-1'),
        (a, b) => _expectDeleted(b, 'app_usage_tag_rule_table', 'rule-1')),
    _EditAction(
        'app_usage_ignore_rule.add',
        'ignore rule',
        (a) => insertRow(a, 'app_usage_ignore_rule_table', {'id': 'ignore-1', 'pattern': 'private*'}),
        (a, b) => _expectCell(b, 'app_usage_ignore_rule_table', 'ignore-1', 'pattern', 'private*')),
    // -- settings
    _EditAction(
        'setting.set',
        'setting',
        (a) => insertRow(a, 'setting_table',
            {'id': settingId, 'key': 'theme', 'value': 'dark', 'value_type': _settingValueTypeString}),
        (a, b) => _expectCell(b, 'setting_table', settingId, 'value', 'dark')),
    _EditAction('setting.change', 'setting', (a) => updateRow(a, 'setting_table', settingId, {'value': 'light'}),
        (a, b) => _expectCell(b, 'setting_table', settingId, 'value', 'light')),
    // -- imports (FR-051)
    _EditAction(
        'import.merge',
        'import',
        (a) => importExport(
            a, exportOfNotes({'imported-1': 'IMPORTED ONE', 'imported-2': 'IMPORTED TWO'}), ImportStrategy.merge),
        (a, b) async {
      await _expectCell(b, 'note_table', 'imported-1', 'title', 'IMPORTED ONE');
      await _expectCell(b, 'note_table', 'imported-2', 'title', 'IMPORTED TWO');
    }),
  ];
}

void main() {
  late Lab lab;
  late LabDevice a;
  late LabDevice b;

  setUpAll(() async {
    initializeJsonMapper();
    lab = await Lab.create();
    a = await lab.add('A');
    b = await lab.add('B', pairWith: a);
    await _seedBase(a);
    expect((await lab.session(a, b)).bothComplete, isTrue);
    expect(await contentOf(b), await contentOf(a));
  });

  tearDownAll(() => lab.close());

  group('SC-009: every user-visible edit action on every FR-050 type reaches B in one session', () {
    final catalog = _catalog();
    for (final action in catalog) {
      test('SC-009 ${action.type}: ${action.id} is visible on B after one session', () async {
        await action.perform(a);
        final pair = await lab.session(a, b);

        expect(pair.bothComplete, isTrue, reason: '$pair');
        await action.verify(a, b);
        expect(await contentOf(b), await contentOf(a), reason: await contentDiff(a, b));
      });
    }

    test('SC-009: the catalog covers every FR-050 data type', () {
      final covered = _catalog().map((action) => action.id.split('.').first.split('_').first).toSet();
      expect(covered, containsAll(['task', 'habit', 'note', 'tag', 'app', 'setting', 'import']));
      expect(
          _catalog().map((action) => action.type).toSet(),
          containsAll([
            'task',
            'task tag',
            'task time record',
            'task status',
            'habit',
            'habit record',
            'habit tag',
            'habit time record',
            'note',
            'note tag',
            'tag',
            'tag link',
            'app usage',
            'app usage tag',
            'app usage time record',
            'tag rule',
            'ignore rule',
            'setting',
            'import',
          ]));
    });
  });

  group('Scenario 5.1 and 5.2: the order of notes and the logged habit time reach B', () {
    test('Scenario 5.1: notes reordered on A show the same order on B', () async {
      for (var i = 0; i < 5; i++) {
        await addNote(a, 'ord-$i', 'ordered $i', order: 'ord-${(9 - i)}');
      }
      expect((await lab.session(a, b)).bothComplete, isTrue);
      await updateRow(a, 'note_table', 'ord-0', {'order': 'ord-0'});
      await normalizeNoteOrders(a);

      expect((await lab.session(a, b)).bothComplete, isTrue);

      Future<List<Object?>> orderOn(LabDevice device) async => [
            for (final row in await device.db
                .rows("SELECT id FROM note_table WHERE id LIKE 'ord-%' AND deleted_date IS NULL ORDER BY \"order\""))
              row['id']
          ];
      expect(await orderOn(b), await orderOn(a));
      expect((await orderOn(b)).first, 'ord-0');
    });

    test('Scenario 5.2: time logged on a habit on A is the habit time on B', () async {
      await insertRow(a, 'habit_table', {'id': 'h-log', 'name': 'logged habit', 'description': ''});
      await addHabitTime(a, 'h-log', _hour, 1200);
      await addHabitTime(a, 'h-log', _hour.add(const Duration(hours: 2)), 300);

      expect((await lab.session(a, b)).bothComplete, isTrue);

      expect(await totalDuration(b, 'habit_time_record_table', 'habit_id', 'h-log'), 1500);
      expect(await contentOf(b), await contentOf(a));
    });
  });

  group('Scenario 5.3 / FR-005: a received change is not counted as a new local edit', () {
    test('Scenario 5.3: B keeps the remote origin and HLC, its next_seq stays, no own-origin cell appears', () async {
      final ownOrigin = await b.origin();
      await addNote(a, 'n-remote', 'received on B');
      final seqBefore = await b.db.count('SELECT next_seq FROM sync_state');
      final ownCellsBefore = await b.db.count(
          "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = '$ownOrigin'");

      expect((await lab.session(a, b)).bothComplete, isTrue);

      expect(await findRow(b, 'note_table', 'n-remote'), isNotNull);
      expect(await b.db.count('SELECT next_seq FROM sync_state'), seqBefore, reason: 'no own seq was spent');
      final ownCellsAfter = await b.db.count(
          "SELECT COUNT(*) FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id WHERE o.value = '$ownOrigin'");
      expect(ownCellsAfter, ownCellsBefore, reason: 'no own-origin cell for the received row');
      final remote = await b.db
          .rows("SELECT o.value AS origin, c.hlc AS hlc FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id "
              "JOIN sync_row r ON r.id = c.key / 256 WHERE r.pk = 'n-remote'");
      final origins = remote.map((row) => row['origin']).toSet();
      expect(origins, {await a.origin()});
      final sourceHlcs = (await a.db.rows(
              "SELECT c.hlc AS hlc FROM sync_clock c JOIN sync_row r ON r.id = c.key / 256 WHERE r.pk = 'n-remote'"))
          .map((row) => row['hlc'])
          .toSet();
      expect(remote.map((row) => row['hlc']).toSet(), sourceHlcs, reason: 'the HLC is the one A stamped');
    });
  });

  group('FR-050: paired-device entries', () {
    test('SC-009 paired device: a device paired with A is a member on B after one session', () async {
      final c = await lab.add('C', pairWith: a);
      expect(b.security.membership.members.keys, isNot(contains(c.memberId)));

      expect((await lab.session(a, b)).bothComplete, isTrue);

      expect(b.security.membership.members.keys, contains(c.memberId));
      expect((await b.security.service.currentView()).activeMembers.map((m) => m.memberId), contains(c.memberId));
      expect(Directory(lab.scratch.path).existsSync(), isTrue);
    });
  });
}
