import 'package:mediatr/mediatr.dart';
import 'package:application/features/sync/services/abstraction/i_sync_service.dart';

class StopSyncCommand implements IRequest<StopSyncCommandResponse> {}

class StopSyncCommandResponse {}

class StopSyncCommandHandler implements IRequestHandler<StopSyncCommand, StopSyncCommandResponse> {
  final ISyncService _syncService;

  StopSyncCommandHandler(this._syncService);

  @override
  Future<StopSyncCommandResponse> call(StopSyncCommand request) {
    _syncService.stopSync();
    return Future.value(StopSyncCommandResponse());
  }
}
