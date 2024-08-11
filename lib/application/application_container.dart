import 'package:whph/application/features/app_usage/commands/start_track_app_usages_command.dart';
import 'package:whph/application/features/app_usage/commands/stop_track_app_usages_command.dart';
import 'package:whph/application/features/app_usage/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/application/features/app_usage/services/abstraction/i_app_usage_service.dart';
import 'package:whph/application/features/app_usage/services/app_usage_service.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/mapper/abstraction/mapper.dart';
import 'package:whph/core/acore/mapper/mapper.dart';
import 'package:whph/application/features/app_usage/services/abstraction/i_app_usage_repository.dart';
import 'package:mediatr/mediatr.dart';

void registerApplication(IContainer container) {
  container.registerSingleton<IMapper>((_) => CoreMapper());

  Mediator mediator = Mediator(Pipeline());
  container.registerSingleton((_) => mediator);

  registerAppUsageFeature(container, mediator);
}

void registerAppUsageFeature(IContainer container, Mediator mediator) {
  container.registerSingleton<IAppUsageService>((_) => AppUsageService(container.resolve<IAppUsageRepository>()));

  mediator.registerHandler<StartTrackAppUsagesCommand, StartTrackAppUsagesCommandResponse,
      StartTrackAppUsagesCommandHandler>(
    () => StartTrackAppUsagesCommandHandler(appUsageService: container.resolve<IAppUsageService>()),
  );
  mediator
      .registerHandler<StopTrackAppUsagesCommand, StopTrackAppUsagesCommandResponse, StopTrackAppUsagesCommandHandler>(
    () => StopTrackAppUsagesCommandHandler(container.resolve<IAppUsageService>()),
  );
  mediator.registerHandler<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse,
      GetListByTopAppUsagesQueryHandler>(
    () => GetListByTopAppUsagesQueryHandler(appUsageRepository: container.resolve<IAppUsageRepository>()),
  );
}
