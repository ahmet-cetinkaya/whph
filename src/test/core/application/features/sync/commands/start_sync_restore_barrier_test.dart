import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data.dart';
import 'package:whph/core/application/features/sync/models/sync_status.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';

void main() {
  test('start command holds admission for the complete asynchronous start', () async {
    final barrier = McpRestoreBarrier();
    final syncService = _BlockingSyncService();
    final handler = StartSyncCommandHandler(
      syncService,
      restoreBarrier: barrier,
    );

    final start = handler.call(StartSyncCommand());
    await syncService.entered.future;
    final restoreEntered = Completer<void>();
    final restore = barrier.runExclusive(() async {
      restoreEntered.complete();
    });

    expect(restoreEntered.isCompleted, isFalse);
    await expectLater(
      () => handler.call(StartSyncCommand()),
      throwsA(isA<RestoreBusyException>()),
    );
    syncService.release.complete();
    await start;
    await restore;
    expect(restoreEntered.isCompleted, isTrue);
    expect(syncService.startCount, 1);
  });
}

class _BlockingSyncService implements ISyncService {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
  var startCount = 0;

  @override
  Future<void> startSync() async {
    startCount++;
    entered.complete();
    await release.future;
  }

  @override
  SyncStatus get currentSyncStatus => const SyncStatus(state: SyncState.idle);

  @override
  Stream<bool> get onSyncComplete => const Stream<bool>.empty();

  @override
  Stream<SyncProgress> get progressStream => const Stream<SyncProgress>.empty();

  @override
  Stream<SyncStatus> get syncStatusStream => const Stream<SyncStatus>.empty();

  @override
  void dispose() {}

  @override
  Future<void> runPaginatedSync({bool isManual = false}) async {}

  @override
  Future<void> runSync({bool isManual = false}) async {}

  @override
  void stopSync() {}

  @override
  void updateSyncStatus(SyncStatus status) {}
}
