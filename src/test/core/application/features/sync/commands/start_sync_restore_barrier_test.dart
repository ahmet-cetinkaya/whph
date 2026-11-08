import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runtime.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';
import 'package:whph/core/application/shared/services/mcp_restore_barrier.dart';

void main() {
  test('start command holds admission for the complete asynchronous start', () async {
    final barrier = McpRestoreBarrier();
    final runtime = _BlockingRuntime();
    final handler = StartSyncCommandHandler(
      runtime,
      restoreBarrier: barrier,
    );

    final start = handler.call(StartSyncCommand());
    await runtime.entered.future;
    final restoreEntered = Completer<void>();
    final restore = barrier.runExclusive(() async {
      restoreEntered.complete();
    });

    expect(restoreEntered.isCompleted, isFalse);
    await expectLater(
      () => handler.call(StartSyncCommand()),
      throwsA(isA<RestoreBusyException>()),
    );
    runtime.release.complete();
    await start;
    await restore;
    expect(restoreEntered.isCompleted, isTrue);
    expect(runtime.startCount, 1);
  });
}

class _BlockingRuntime implements ISyncRuntime {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();
  var startCount = 0;

  @override
  Future<void> start() async {
    startCount++;
    entered.complete();
    await release.future;
  }

  @override
  Future<void> stop() async {}
}
