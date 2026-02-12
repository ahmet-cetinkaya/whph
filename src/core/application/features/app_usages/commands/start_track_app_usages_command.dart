import 'package:mediatr/mediatr.dart';
import 'package:application/features/app_usages/services/abstraction/i_app_usage_service.dart';

class StartTrackAppUsagesCommand implements IRequest<StartTrackAppUsagesCommandResponse> {}

class StartTrackAppUsagesCommandResponse {}

class StartTrackAppUsagesCommandHandler
    implements IRequestHandler<StartTrackAppUsagesCommand, StartTrackAppUsagesCommandResponse> {
  final IAppUsageService _appUsageService;

  StartTrackAppUsagesCommandHandler({required IAppUsageService appUsageService}) : _appUsageService = appUsageService;

  @override
  Future<StartTrackAppUsagesCommandResponse> call(StartTrackAppUsagesCommand request) async {
    await _appUsageService.startTracking();
    return Future.value(StartTrackAppUsagesCommandResponse());
  }
}
