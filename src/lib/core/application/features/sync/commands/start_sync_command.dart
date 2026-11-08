import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runtime.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';

/// Starts the LAN server and the periodic sync.
class StartSyncCommand implements IRequest<void> {}

class StartSyncCommandHandler implements IRequestHandler<StartSyncCommand, void> {
  final ISyncRuntime _runtime;
  final IRestoreBarrier _restoreBarrier;

  StartSyncCommandHandler(
    this._runtime, {
    required IRestoreBarrier restoreBarrier,
  }) : _restoreBarrier = restoreBarrier;

  @override
  Future<void> call(StartSyncCommand request) async {
    Logger.debug('Starting sync via command');
    await _restoreBarrier.runShared(_runtime.start);
  }
}
