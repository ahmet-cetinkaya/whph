/// Shared helpers for the T12 engine tests: deterministic devices, clocks
/// and synced-content comparison.
library;

import 'dart:math';

import 'package:test/test.dart';
import 'package:whph_sync_core/whph_sync_core.dart';

import 'session_engine_switch.dart';

export 'session_engine_switch.dart';

const day = Duration.millisecondsPerDay;

/// Base wall time of every test clock (2026-01-01T00:00:00Z).
const baseWall = 1767225600000;

/// A settable wall clock.
final class TestClock {
  TestClock([this.nowMs = baseWall]);

  int nowMs;

  int call() => nowMs;

  void advance(int ms) => nowMs += ms;
}

Future<void> noDelay(Duration _) async {}

/// Engine config without real timers.
SyncEngineConfig testConfig({
  int window = 4,
  int maxBatchChanges = SyncLimits.maxBatchChanges,
  int protocolVersion = syncProtocolVersion,
  int minCompatible = minCompatibleProtocolVersion,
}) =>
    SyncEngineConfig(
      window: window,
      maxBatchChanges: maxBatchChanges,
      protocolVersion: protocolVersion,
      minCompatible: minCompatible,
      delay: noDelay,
    );

/// Creates a device with seeded ids and its own [TestClock].
Future<SyncDevice> newDevice(
  String name, {
  required int seed,
  TestClock? clock,
  SyncEngineConfig? config,
  SyncLedger? ledger,
}) {
  final c = clock ?? TestClock();
  return SyncDevice.create(
    name: name,
    clock: c.call,
    ids: SyncIdSource(Random(seed)),
    config: config ?? testConfig(),
    ledger: ledger,
  );
}

/// Pairs [devices] into one group through the first one.
Future<void> pairAll(List<SyncDevice> devices) async {
  for (final d in devices.skip(1)) {
    await SyncDevice.pair(inviter: devices.first, joiner: d);
  }
}

/// Runs sessions over every pair until a round changes nothing (all
/// complete). Returns the number of rounds.
Future<int> syncUntilQuiet(List<SyncDevice> devices, {int maxRounds = 8}) async {
  for (var round = 1; round <= maxRounds; round++) {
    final before = [for (final d in devices) fingerprint(d.store, security: true)];
    for (var i = 0; i < devices.length; i++) {
      for (var j = i + 1; j < devices.length; j++) {
        final r = await runSessionPair(devices[i], devices[j]);
        expect(r.initiator.exchanged, isTrue, reason: 'round $round ${devices[i].name}->${devices[j].name}: $r');
        expect(r.responder.exchanged, isTrue, reason: 'round $round ${devices[i].name}->${devices[j].name}: $r');
      }
    }
    final after = [for (final d in devices) fingerprint(d.store, security: true)];
    if (_listEq(before, after) && after.toSet().length == 1) return round;
  }
  return maxRounds + 1;
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Synced content (FR-001): every user-table cell's winning `(value, hlc,
/// node)`, keyed and sorted. Security tables excluded unless [security].
Map<String, String> content(SyncStore store, {bool security = false}) {
  final out = <String, String>{};
  for (final c in store.cells) {
    if (!security && SecurityTables.contains(c.key.table)) continue;
    out[c.key.toString()] = '${_value(c.value)}@${c.clock}/${c.node}${c.cause == null ? '' : ' cause=${c.cause}'}';
  }
  return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}

String _value(Object? v) => v is List<int> ? 'bytes${v.length}' : '$v';

/// A string fingerprint of [content] plus effective existence of every row.
String fingerprint(SyncStore store, {bool security = false}) {
  final c = content(store, security: security);
  final rows = <String>{};
  for (final cell in store.cells) {
    if (!security && SecurityTables.contains(cell.key.table)) continue;
    rows.add('${cell.key.table}/${cell.key.pk}=${store.isRowAlive(cell.key.table, cell.key.pk)}');
  }
  return [...c.entries.map((e) => '${e.key}:${e.value}'), ...(rows.toList()..sort())].join('\n');
}

/// Live user rows of [table].
Set<String> aliveRows(SyncStore store, String table) => {
      for (final pk in store.rowsOf(table))
        if (store.isRowAlive(table, pk)) pk
    };

CellKey cellKey(String pk, String col, {String table = 'task'}) => CellKey(table, pk, col);

RowRef row(String pk, {String table = 'task'}) => RowRef(table, pk);

/// Creates row [pk] with a title (and alive existence cell).
void createRow(SyncDevice d, String pk, String title, {String table = 'task'}) {
  d
    ..write(CellKey(table, pk, CellKey.existenceCol), null)
    ..write(CellKey(table, pk, 'title'), title);
}

Matcher isComplete = predicate<SessionResult>((r) => r.isComplete, 'complete session');
