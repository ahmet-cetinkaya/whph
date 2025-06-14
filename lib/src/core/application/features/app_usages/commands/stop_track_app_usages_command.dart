import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';

class StopTrackAppUsagesCommand implements IRequest<StopTrackAppUsagesCommandResponse> {}

class StopTrackAppUsagesCommandResponse {}

class StopTrackAppUsagesCommandHandler
    implements IRequestHandler<StopTrackAppUsagesCommand, StopTrackAppUsagesCommandResponse> {
  final IAppUsageService _appUsageService;

  StopTrackAppUsagesCommandHandler(this._appUsageService);

  @override
  Future<StopTrackAppUsagesCommandResponse> call(StopTrackAppUsagesCommand request) {
    _appUsageService.stopTracking();
    return Future.value(StopTrackAppUsagesCommandResponse());
  }
}
