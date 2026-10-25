// T27 part 1, US1: Scenarios 1.1 to 1.9, SC-002 and SC-003. Real Drift
// devices, the application's SyncEngineService, the Drift session host and
// loopback transports with injected cuts.
@Timeout(Duration(minutes: 8))
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_result_category.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'support1/acceptance_fleet.dart';

const String _task = 'task_table';
const String _note = 'note_table';
const int _threeHours = 3;
const int _bulkRows = 400;
const int _faultRuns = 20;
const int _goodItemsPerRun = 6;
const List<int> _cutPoints = [6, 14, 40];
const List<String> _scenarioIds = ['1.1', '1.2', '1.3', '1.4', '1.5', '1.6', '1.7', '1.8', '1.9'];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AcceptanceFleet fleet;
  final passedScenarios = <String>{};

  setUp(() async => fleet = await AcceptanceFleet.open());
  tearDown(() => fleet.close());

  Future<(FleetDevice, FleetDevice)> pairOfDevices({int bAheadHours = 0}) async {
    final a = await fleet.add('A');
    final b = await fleet.add('B', inviter: a, clockAheadHours: bAheadHours);
    return (a, b);
  }

  Future<(FleetDevice, FleetDevice, FleetDevice)> relayChain() async {
    final a = await fleet.add('A');
    final b = await fleet.add('B', inviter: a);
    final c = await fleet.add('C', inviter: b);
    return (a, b, c);
  }

  Future<void> sharedTask(FleetDevice from, List<(String, String)> links, {String title = 'base'}) async {
    await from.insertTask('t1', title);
    await fleet.settleOver(links);
  }

  test('Scenario 1.1 different fields of one task both survive', () async {
    final (a, b) = await pairOfDevices();
    await sharedTask(a, [('A', 'B')]);

    await a.setTaskTitle('t1', 'new title');
    await b.setTaskReminder('t1', 3);
    await fleet.settleOver([('A', 'B')]);

    for (final device in [a, b]) {
      final row = (await device.rowById(_task, 't1'))!;
      expect(row['title'], 'new title', reason: device.name);
      expect(row['planned_date_reminder_time'], 3, reason: device.name);
    }
    await expectIdenticalData([a, b], [_task]);
    passedScenarios.add('1.1');
  });

  test('Scenario 1.2 same field: the later recorded edit wins on both devices', () async {
    final (a, b) = await pairOfDevices();
    await a.database.insertNote('n1', 'note');
    await fleet.settleOver([('A', 'B')]);

    await a.setNoteContent('n1', 'body from A');
    await b.setClockAheadHours(1);
    await b.setNoteContent('n1', 'body from B');
    await fleet.settleOver([('A', 'B')]);

    for (final device in [a, b]) {
      expect((await device.rowById(_note, 'n1'))!['content'], 'body from B', reason: device.name);
    }
    await expectIdenticalData([a, b], [_note]);
    passedScenarios.add('1.2');
  });

  test('Scenario 1.3 causal order beats clocks: the later edit wins although its clock is 3 hours behind', () async {
    final a = await fleet.add('A', clockAheadHours: _threeHours);
    final b = await fleet.add('B', inviter: a);
    await sharedTask(a, [('A', 'B')]);

    await a.setTaskTitle('t1', 'edit on A (fast clock)');
    await fleet.session('A', 'B');
    await b.setTaskTitle('t1', 'edit on B after receiving A');
    await fleet.settleOver([('A', 'B')]);

    for (final device in [a, b]) {
      expect((await device.rowById(_task, 't1'))!['title'], 'edit on B after receiving A', reason: device.name);
    }
    await expectIdenticalData([a, b], [_task]);

    // Positive control: the skew is real. Without receiving A's edit first, B's
    // later real-time edit loses to A's fast clock (FR-004).
    await a.insertTask('t2', 'base');
    await fleet.settleOver([('A', 'B')]);
    await a.setTaskTitle('t2', 'fast clock edit');
    await b.setTaskTitle('t2', 'concurrent edit on B');
    await fleet.settleOver([('A', 'B')]);
    expect((await b.rowById(_task, 't2'))!['title'], 'fast clock edit');
    passedScenarios.add('1.3');
  });

  /// A conflicting pair of edits to one task, relayed or direct; the title on
  /// the device that never meets A directly.
  Future<String> titleOnCAfterConflict({required bool relayed}) async {
    final inner = await AcceptanceFleet.open();
    addTearDown(inner.close);
    final a = await inner.add('A');
    final b = await inner.add('B', inviter: a);
    final c = await inner.add('C', inviter: relayed ? b : a);
    await a.insertTask('t1', 'base');
    final links = relayed ? [('A', 'B'), ('B', 'C')] : [('A', 'B'), ('A', 'C'), ('B', 'C')];
    await inner.settleOver(links);

    await a.setTaskTitle('t1', 'edit on A');
    await c.setClockAheadHours(1);
    await c.setTaskTitle('t1', 'edit on C');
    await inner.settleOver(links);
    await expectIdenticalData([a, b, c], [_task]);
    return (await c.rowById(_task, 't1'))!['title']! as String;
  }

  test('Scenario 1.4 a change relayed through B gives C the result of syncing A to C directly', () async {
    final relayed = await titleOnCAfterConflict(relayed: true);
    final direct = await titleOnCAfterConflict(relayed: false);

    expect(relayed, direct);
    expect(relayed, 'edit on C');
    passedScenarios.add('1.4');
  });

  test('Scenario 1.5 an older edit arriving after a newer one does not override it', () async {
    final (a, b, c) = await relayChain();
    await a.insertTask('t1', 'base');
    await fleet.settleOver([('A', 'B'), ('B', 'C')]);

    await a.setTaskTitle('t1', 'older edit from A');
    await c.setClockAheadHours(1);
    await c.setTaskTitle('t1', 'newer edit from C');
    await fleet.session('C', 'B');
    await fleet.session('A', 'B');
    expect((await b.rowById(_task, 't1'))!['title'], 'newer edit from C', reason: 'B after receiving A last');
    await fleet.settleOver([('A', 'B'), ('B', 'C')]);

    for (final device in [a, b, c]) {
      expect((await device.rowById(_task, 't1'))!['title'], 'newer edit from C', reason: device.name);
    }
    await expectIdenticalData([a, b, c], [_task]);
    passedScenarios.add('1.5');
  });

  test('Scenario 1.6 a deletion made after seeing an edit deletes the task on both devices', () async {
    final (a, b) = await pairOfDevices(bAheadHours: _threeHours);
    await sharedTask(a, [('A', 'B')]);

    await b.setTaskTitle('t1', 'edited on B');
    await fleet.session('B', 'A');
    expect((await a.rowById(_task, 't1'))!['title'], 'edited on B');
    await a.deleteTask('t1');
    await fleet.settleOver([('A', 'B')]);

    for (final device in [a, b]) {
      expect(await device.liveIds(_task), isEmpty, reason: device.name);
    }
    await expectIdenticalData([a, b], [_task]);
    passedScenarios.add('1.6');
  });

  /// A deletes and B edits while offline from each other; [editLater] decides
  /// which action is recorded later. Both devices must agree.
  Future<List<String>> liveTasksAfterConcurrentDeleteAndEdit({required bool editLater}) async {
    final inner = await AcceptanceFleet.open();
    addTearDown(inner.close);
    final a = await inner.add('A');
    final b = await inner.add('B', inviter: a);
    await a.insertTask('t1', 'base');
    await inner.settleOver([('A', 'B')]);

    if (editLater) {
      await a.deleteTask('t1');
      await b.setClockAheadHours(1);
      await b.setTaskTitle('t1', 'edit on B');
    } else {
      await b.setTaskTitle('t1', 'edit on B');
      await a.setClockAheadHours(1);
      await a.deleteTask('t1');
    }
    await inner.settleOver([('A', 'B')]);

    await expectIdenticalData([a, b], [_task]);
    expect(await a.liveIds(_task), await b.liveIds(_task));
    return a.liveIds(_task);
  }

  test('Scenario 1.7 a concurrent delete and edit end the same on both devices by the later action', () async {
    expect(await liveTasksAfterConcurrentDeleteAndEdit(editLater: false), isEmpty, reason: 'delete recorded later');
    expect(await liveTasksAfterConcurrentDeleteAndEdit(editLater: true), ['t1'], reason: 'edit recorded later');
    passedScenarios.add('1.7');
  });

  test('Scenario 1.8 an interrupted session loses nothing and applies every change exactly once', () async {
    final (a, b) = await pairOfDevices();
    await a.database.db.transaction(() async {
      for (var i = 0; i < _bulkRows; i++) {
        await a.database.insertNote('n$i', 'title $i');
      }
    });
    var interruptions = 0;
    for (final cutAfter in _cutPoints) {
      final trace = TransportTrace();
      await fleet.session('B', 'A', faults: TransportFaults(cutAfter: cutAfter), trace: trace);
      if (trace.cut) interruptions++;
    }
    expect(interruptions, greaterThan(0), reason: 'at least one session must have been cut part way');

    await fleet.settleOver([('A', 'B')]);

    expect(await b.liveIds(_note), hasLength(_bulkRows));
    await expectIdenticalData([a, b], [_note]);
    expect(await _sequencesOfOrigin(b, a), await _sequencesOfOrigin(a, a),
        reason: 'every change applied once, none skipped');
    passedScenarios.add('1.8');
  });

  test('Scenario 1.9 a failed item makes the session not fully successful, keeps the rest and is retried', () async {
    final (a, b) = await pairOfDevices();
    await _armPoison(b, 'poison-1', 'trigger1');
    await a.database.insertNote('bad', 'poison-1');
    await a.database.insertNote('good', 'fine');

    final failed = await fleet.session('B', 'A');

    expect(failed.category, SyncResultCategory.someItemsFailed);
    expect(failed.result, isA<SessionPartial>());
    expect(await b.liveIds(_note), ['good'], reason: 'the other change is kept');

    await _disarmPoison(b, 'trigger1');
    final retried = await fleet.session('B', 'A');

    expect(retried.category, isNull);
    expect(await b.liveIds(_note), ['bad', 'good']);
    await expectIdenticalData([a, b], [_note]);
    passedScenarios.add('1.9');
  });

  test('SC-002 every Scenario 1.1 to 1.9 shows the expected result on every device', () {
    expect(passedScenarios, containsAll(_scenarioIds),
        reason: 'run the whole file; each scenario test records its pass');
  });

  test(
      'SC-003 $_faultRuns fault-injection runs: not fully successful, then applied in the first session after the fault',
      () async {
    final (a, b) = await pairOfDevices();
    for (var run = 0; run < _faultRuns; run++) {
      final poisonTitle = 'poison-run-$run';
      final useTask = run.isOdd;
      final table = useTask ? _task : _note;
      await _armPoison(b, poisonTitle, 'poison$run', table: table);
      final poisonPosition = run % _goodItemsPerRun;
      for (var i = 0; i < _goodItemsPerRun; i++) {
        final id = i == poisonPosition ? 'bad-$run' : 'good-$run-$i';
        final title = i == poisonPosition ? poisonTitle : 'fine $run $i';
        await (useTask ? a.insertTask(id, title) : a.database.insertNote(id, title));
      }

      final failed = await fleet.session('B', 'A');
      expect(failed.category, SyncResultCategory.someItemsFailed, reason: 'run $run');
      expect(await b.liveIds(table), isNot(contains('bad-$run')), reason: 'run $run');
      expect(await b.liveIds(table), contains('good-$run-${(poisonPosition + 1) % _goodItemsPerRun}'),
          reason: 'run $run');

      await _disarmPoison(b, 'poison$run', table: table);
      final healed = await fleet.session('B', 'A');
      expect(healed.category, isNull, reason: 'run $run');
      expect(await b.liveIds(table), contains('bad-$run'),
          reason: 'applied in the first session after the fault, run $run');
    }
    await expectIdenticalData([a, b], [_task, _note]);
  });
}

/// Makes [receiver] refuse to store a row whose title is [title] (an item that
/// cannot be applied).
Future<void> _armPoison(FleetDevice receiver, String title, String name, {String table = _note}) async {
  await receiver.sql("CREATE TRIGGER ${name}_i BEFORE INSERT ON $table WHEN NEW.title = '$title' "
      "BEGIN SELECT RAISE(ABORT, 'cannot apply'); END");
  await receiver.sql("CREATE TRIGGER ${name}_u BEFORE UPDATE ON $table WHEN NEW.title = '$title' "
      "BEGIN SELECT RAISE(ABORT, 'cannot apply'); END");
}

Future<void> _disarmPoison(FleetDevice receiver, String name, {String table = _note}) async {
  await receiver.sql('DROP TRIGGER ${name}_i');
  await receiver.sql('DROP TRIGGER ${name}_u');
}

/// The sequence numbers [device] holds for changes authored by [author].
Future<List<int>> _sequencesOfOrigin(FleetDevice device, FleetDevice author) async {
  final rows = await device.database.rows(
    'SELECT c.origin_seq FROM sync_clock c JOIN sync_intern o ON o.id = c.origin_id '
    "WHERE o.value = '${author.database.origin}' ORDER BY c.origin_seq",
  );
  return [for (final row in rows) row['origin_seq'] as int];
}
