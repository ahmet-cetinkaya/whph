import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command.dart';
import 'package:whph/core/application/features/sync/models/paginated_sync_data_dto.dart';
import 'package:whph/main.dart';

class PaginatedSyncController {
  final Mediator _mediator = container.resolve<Mediator>();

  Future<PaginatedSyncCommandResponse> paginatedSync(PaginatedSyncDataDto paginatedSyncData) async {
    final command = PaginatedSyncCommand(paginatedSyncDataDto: paginatedSyncData);
    PaginatedSyncCommandResponse response =
        await _mediator.send<PaginatedSyncCommand, PaginatedSyncCommandResponse>(command);
    return response;
  }
}
