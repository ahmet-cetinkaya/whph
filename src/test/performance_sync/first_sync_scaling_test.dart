// T28 regression: the first sync must scale about linearly with the number of
// cells. A per-cell query that scans or sorts a growing table made it ~n^1.4
// (n=4000 took 155 s). Quadrupling the notes must not take more than ~5x the time.
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration/sync_acceptance/support2/lab.dart';
import '../integration/sync_acceptance/support2/lan_support.dart';

const int _smallNotes = 1000;
const int _largeNotes = 4000;
// Linear growth is 4x; the quadratic-ish scan made ~6.9x (1000 -> 4000).
const double _maxGrowthFactor = 5;
const int _bytesProbeNotes = 300;
const int _maxBytesPerNote = 4096;

Future<({Duration elapsed, int bytes})> _firstSyncOf(int notes) async {
  final lab = await Lab.create();
  try {
    final a = await lab.add('A');
    final b = await lab.add('B', pairWith: a);
    await a.appDatabase.transaction(() async {
      for (var index = 0; index < notes; index++) {
        await a.appDatabase.customStatement(
            "INSERT INTO note_table (id, created_date, title, content) VALUES ('scale-$index', 1700000000, 'n $index', 'body')");
      }
    });
    final recorder = RecordingHost(b);
    final server = await startLanServer(recorder);
    final stopwatch = Stopwatch()..start();
    final result = await syncOverLan(a, b, server.port!);
    final responder = await recorder.resultAfter(0);
    final elapsed = stopwatch.elapsed;
    expect(result.isComplete, isTrue);
    final received = await b.appDatabase
        .customSelect('SELECT COUNT(*) c FROM note_table')
        .getSingle();
    expect(received.data['c'], notes);
    return (
      elapsed: elapsed,
      bytes: result.stats.bytesSent + responder.stats.bytesSent
    );
  } finally {
    await lab.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('first sync time grows about linearly with the cell count', () async {
    final small = (await _firstSyncOf(_smallNotes)).elapsed;
    final large = (await _firstSyncOf(_largeNotes)).elapsed;
    // ignore: avoid_print
    print('SCALING $_smallNotes notes: $small, $_largeNotes notes: $large');
    expect(
        large.inMicroseconds / small.inMicroseconds, lessThan(_maxGrowthFactor),
        reason: '$small -> $large');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('a first sync ships each manifest once per batch, not once per cell',
      () async {
    final run = await _firstSyncOf(_bytesProbeNotes);
    // ignore: avoid_print
    print('BYTES $_bytesProbeNotes notes: ${run.bytes}');
    // Per-cell manifest copies made this ~130 KB per note.
    expect(run.bytes / _bytesProbeNotes, lessThan(_maxBytesPerNote));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
