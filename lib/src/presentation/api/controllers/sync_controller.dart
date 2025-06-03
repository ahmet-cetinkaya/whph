import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/sync/commands/sync_command.dart';
import 'package:whph/src/core/application/features/sync/models/sync_data_dto.dart';
import 'package:whph/main.dart';

class SyncController {
  final Mediator _mediator = container.resolve<Mediator>();

  Future<SyncCommandResponse> sync(SyncDataDto syncData) async {
    final command = SyncCommand(syncDataDto: syncData);
    SyncCommandResponse response = await _mediator.send<SyncCommand, SyncCommandResponse>(command);
    return response;
  }
}
