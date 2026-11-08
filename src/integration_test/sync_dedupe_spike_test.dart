// S5 spike (plan T7, acceptance 6): on-device timing of the dedupe/re-key and clock bootstrap prototype on the
// synthetic `large_usage` fixture. Test-only spike code; prints `[S5]`-prefixed numbers.
//
//   cd src && fvm flutter test integration_test/sync_dedupe_spike_test.dart -d <device>
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/drift/app_database/generated/schema_v37.dart';
import '../test/fixtures/sync/fixture_builder.dart' show buildFixture, defaultFixtureSeed, largeUsageFixture;
import '../test/infrastructure/persistence/sync/dedupe_spike.dart';

void _log(String message) {
  // ignore: avoid_print
  print('[S5] $message');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('S5 dedupe/bootstrap chunk timings on large_usage', (tester) async {
    await tester.runAsync(() async {
      final directory = await Directory.systemTemp.createTemp('whph_s5_');
      try {
        final build = await buildFixture(largeUsageFixture, seed: defaultFixtureSeed, out: directory);
        _log('platform=${Platform.operatingSystem} rows=${build.totalRows} build_ms=${build.elapsed.inMilliseconds}');
        for (final groupsPerChunk in const [1, 250]) {
          final copy = await build.database.copy('${build.database.path}.run$groupsPerChunk');
          final db = DatabaseAtV37(NativeDatabase(copy, setup: (raw) {
            raw.execute('PRAGMA journal_mode=WAL');
            raw.execute('PRAGMA busy_timeout=5000');
          }));
          try {
            await SpikeSyncSchema.install(db, memberId: 'spike-member-a', originId: '0123456789abcdef0123456789abcdef');
            final timings = <ChunkTiming>[];
            final job = DedupeSpikeJob(db, nowMs: 1790000000000, groupsPerChunk: groupsPerChunk, onChunk: timings.add);
            final sw = Stopwatch()..start();
            final result = await job.run();
            sw.stop();
            _log('groupsPerChunk=$groupsPerChunk total_ms=${sw.elapsedMilliseconds} chunks=${result.chunks}\n'
                '${ChunkTimingSummary(timings).describe()}');
          } finally {
            await db.close();
          }
        }
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}
