import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/application/shared/services/abstraction/i_restore_barrier.dart';

class StartSyncCommand implements IRequest<void> {}

class StartSyncCommandHandler implements IRequestHandler<StartSyncCommand, void> {
  final ISyncService _syncService;
  final IRestoreBarrier _restoreBarrier;

  StartSyncCommandHandler(
    this._syncService, {
    required IRestoreBarrier restoreBarrier,
  }) : _restoreBarrier = restoreBarrier;

  @override
  Future<void> call(StartSyncCommand request) async {
    Logger.debug('Starting sync service via command');
    await _restoreBarrier.runShared(_syncService.startSync);
  }
}
