// T23 acceptance 6: the periodic scheduler triggers sessions and "sync now"
// triggers one immediately (FR-008, PB-3).
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_run_report.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runner.dart';
import 'package:whph/core/application/features/sync/services/sync_scheduler.dart';

const Duration _interval = Duration(minutes: 5);

class _RecordingRunner implements ISyncRunner {
  int allRuns = 0;
  final List<String> peerRuns = [];
  Completer<void>? hold;

  @override
  Future<SyncRunReport> syncAll() async {
    allRuns++;
    await hold?.future;
    return const SyncRunReport();
  }

  @override
  Future<SyncRunReport> syncPeer(String memberId) async {
    peerRuns.add(memberId);
    return const SyncRunReport();
  }
}

void main() {
  test('a started scheduler runs the engine every interval, and not before', () {
    fakeAsync((async) {
      final runner = _RecordingRunner();
      final scheduler = SyncScheduler(runner, interval: _interval)..start();

      async.elapse(_interval - const Duration(seconds: 1));
      expect(runner.allRuns, 0);
      async.elapse(const Duration(seconds: 1));
      expect(runner.allRuns, 1);
      async.elapse(_interval * 2);
      expect(runner.allRuns, 3);
      scheduler.stop();
    });
  });

  test('a scheduler that is not started or was stopped runs nothing', () {
    fakeAsync((async) {
      final runner = _RecordingRunner();
      final scheduler = SyncScheduler(runner, interval: _interval);

      async.elapse(_interval * 3);
      expect(runner.allRuns, 0);

      scheduler.start();
      expect(scheduler.isStarted, isTrue);
      scheduler.stop();
      expect(scheduler.isStarted, isFalse);
      async.elapse(_interval * 3);
      expect(runner.allRuns, 0);
    });
  });

  test('sync now runs a session at once, for all peers or for one', () async {
    final runner = _RecordingRunner();
    final scheduler = SyncScheduler(runner, interval: _interval);

    await scheduler.syncNow();
    await scheduler.syncNow(memberId: 'peer-1');

    expect(runner.allRuns, 1, reason: 'no waiting for the interval');
    expect(runner.peerRuns, ['peer-1']);
  });

  test('a run that is still going when the next one is due is not started twice', () {
    fakeAsync((async) {
      final runner = _RecordingRunner()..hold = Completer<void>();
      final scheduler = SyncScheduler(runner, interval: _interval)..start();

      async.elapse(_interval * 3);
      expect(runner.allRuns, 1);

      runner.hold!.complete();
      async.flushMicrotasks();
      async.elapse(_interval);
      expect(runner.allRuns, 2);
      scheduler.stop();
    });
  });
}
