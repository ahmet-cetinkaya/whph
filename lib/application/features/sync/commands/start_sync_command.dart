import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_service.dart';

class StartSyncCommand implements IRequest<StartSyncCommandResponse> {}

class StartSyncCommandResponse {}

class StartSyncCommandHandler implements IRequestHandler<StartSyncCommand, StartSyncCommandResponse> {
  final ISyncService _syncService;

  StartSyncCommandHandler(this._syncService);

  @override
  Future<StartSyncCommandResponse> call(StartSyncCommand request) {
    _syncService.startSync();
    return Future.value(StartSyncCommandResponse());
  }
}
