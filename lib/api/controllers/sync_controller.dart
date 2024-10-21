import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/models/sync_data_dto.dart';
import 'package:whph/main.dart';

class SyncController {
  final Mediator _mediator = container.resolve<Mediator>();

  Future<SyncCommandResponse> sync(SyncDataDto syncData) async {
    var command = SyncCommand(syncDataDto: syncData);
    SyncCommandResponse response = await _mediator.send<SyncCommand, SyncCommandResponse>(command);
    return response;
  }
}
