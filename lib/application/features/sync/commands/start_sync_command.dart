import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_service.dart';

class StartSyncCommand implements IRequest<void> {}

class StartSyncCommandHandler implements IRequestHandler<StartSyncCommand, void> {
  final ISyncService _syncService;

  StartSyncCommandHandler(this._syncService);

  @override
  Future<void> call(StartSyncCommand request) async {
    print('DEBUG: Starting sync service via command');
    _syncService.startSync();
    return;
  }
}
