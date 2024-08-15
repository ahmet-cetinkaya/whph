import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usage/commands/start_track_app_usages_command.dart';
import 'package:whph/application/features/app_usage/commands/stop_track_app_usages_command.dart';
import 'package:whph/application/features/app_usage/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/application/features/app_usage/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usage/services/abstraction/i_app_usage_service.dart';
import 'package:whph/application/features/app_usage/services/app_usage_service.dart';
import 'package:whph/application/features/tasks/commands/delete_task_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/topics/commands/delete_topic_command.dart';
import 'package:whph/application/features/topics/services/abstraction/i_topic_repository.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/mapper/abstraction/i_mapper.dart';
import 'package:whph/core/acore/mapper/mapper.dart';

import 'features/topics/commands/save_topic_command.dart';
import 'features/topics/queries/get_list_topics_query.dart';

void registerApplication(IContainer container) {
  container.registerSingleton<IMapper>((_) => CoreMapper());

  Mediator mediator = Mediator(Pipeline());
  container.registerSingleton((_) => mediator);

  registerAppUsagesFeature(container, mediator);
  registerTasksFeature(container, mediator);
  registerTopicsFeature(container, mediator);
}

void registerAppUsagesFeature(IContainer container, Mediator mediator) {
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

void registerTasksFeature(IContainer container, Mediator mediator) {
  mediator.registerHandler<SaveTaskCommand, SaveTaskCommandResponse, SaveTaskCommandHandler>(
    () => SaveTaskCommandHandler(taskService: container.resolve<ITaskRepository>()),
  );
  mediator.registerHandler<DeleteTaskCommand, DeleteTaskCommandResponse, DeleteTaskCommandHandler>(
    () => DeleteTaskCommandHandler(taskRepository: container.resolve<ITaskRepository>()),
  );
  mediator.registerHandler<GetListTasksQuery, GetListTasksQueryResponse, GetListTasksQueryHandler>(
    () => GetListTasksQueryHandler(taskRepository: container.resolve<ITaskRepository>()),
  );
  mediator.registerHandler<GetTaskQuery, GetTaskQueryResponse, GetTaskQueryHandler>(
    () => GetTaskQueryHandler(
        taskRepository: container.resolve<ITaskRepository>(), topicRepository: container.resolve<ITopicRepository>()),
  );
}

void registerTopicsFeature(IContainer container, Mediator mediator) {
  mediator.registerHandler<SaveTopicCommand, SaveTopicCommandResponse, SaveTopicCommandHandler>(
    () => SaveTopicCommandHandler(topicRepository: container.resolve<ITopicRepository>()),
  );
  mediator.registerHandler<DeleteTopicCommand, DeleteTopicCommandResponse, DeleteTopicCommandHandler>(
    () => DeleteTopicCommandHandler(topicRepository: container.resolve<ITopicRepository>()),
  );
  mediator.registerHandler<GetListTopicsQuery, GetListTopicsQueryResponse, GetListTopicsQueryHandler>(
    () => GetListTopicsQueryHandler(topicRepository: container.resolve<ITopicRepository>()),
  );
  mediator.registerHandler<GetListTasksQuery, GetListTasksQueryResponse, GetListTasksQueryHandler>(
    () => GetListTasksQueryHandler(taskRepository: container.resolve<ITaskRepository>()),
  );
}
