import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_reset_database_service.dart';

class ResetDatabaseCommand implements IRequest<ResetDatabaseCommandResponse> {}

class ResetDatabaseCommandResponse {}

class ResetDatabaseCommandHandler implements IRequestHandler<ResetDatabaseCommand, ResetDatabaseCommandResponse> {
  final IResetDatabaseService _resetDatabaseService;

  ResetDatabaseCommandHandler({required IResetDatabaseService resetDatabaseService})
      : _resetDatabaseService = resetDatabaseService;

  @override
  Future<ResetDatabaseCommandResponse> call(ResetDatabaseCommand request) async {
    await _resetDatabaseService.resetDatabase();
    return ResetDatabaseCommandResponse();
  }
}
