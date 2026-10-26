import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_runtime.dart';

class StopSyncCommand implements IRequest<StopSyncCommandResponse> {}

class StopSyncCommandResponse {}

class StopSyncCommandHandler implements IRequestHandler<StopSyncCommand, StopSyncCommandResponse> {
  final ISyncRuntime _runtime;

  StopSyncCommandHandler(this._runtime);

  @override
  Future<StopSyncCommandResponse> call(StopSyncCommand request) async {
    await _runtime.stop();
    return StopSyncCommandResponse();
  }
}
