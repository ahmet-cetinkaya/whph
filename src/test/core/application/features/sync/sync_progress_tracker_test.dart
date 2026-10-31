import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/sync_progress_tracker.dart';

void main() {
  late SyncProgressTracker tracker;
  late List<SyncStatus> statuses;

  setUp(() {
    tracker = SyncProgressTracker();
    statuses = [];
    tracker.changes.listen(statuses.add);
  });

  test('begin names the peer and has no share yet', () async {
    tracker.begin('m1');
    await Future<void>.delayed(Duration.zero);

    expect(tracker.current.isSyncing, isTrue);
    expect(tracker.current.currentDeviceId, 'm1');
    expect(tracker.current.progress, isNull);
  });

  test('report maps processed over total to a share between 0 and 1', () async {
    tracker.begin('m1');
    tracker.report('m1', 1, 4);
    tracker.report('m1', 9, 4);
    await Future<void>.delayed(Duration.zero);

    expect(statuses.map((status) => status.progress), [null, 0.25, 1.0]);
  });

  test('report without a known total keeps the bar indeterminate', () async {
    tracker.begin('m1');
    tracker.report('m1', 0, 0);
    await Future<void>.delayed(Duration.zero);

    expect(tracker.current.progress, isNull);
  });

  test('end goes idle for the running peer only', () {
    tracker.begin('m1');

    tracker.end('m2');
    expect(tracker.current.isSyncing, isTrue);

    tracker.end('m1');
    expect(tracker.current.isIdle, isTrue);
  });

  test('copyWith keeps the share and replaces it when given', () {
    const status = SyncStatus(state: SyncState.syncing, progress: 0.5);

    expect(status.copyWith(isManual: true).progress, 0.5);
    expect(status.copyWith(progress: 0.75).progress, 0.75);
  });
}
