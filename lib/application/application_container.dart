import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/application/features/app_usages/commands/stop_track_app_usages_command.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/app_usages/services/app_usage_service.dart';
import 'package:whph/application/features/settings/commands/delete_setting_command.dart';
import 'package:whph/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/application/features/settings/queries/get_list_settings_query.dart';
import 'package:whph/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/delete_task_command.dart';
import 'package:whph/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/mapper/abstraction/i_mapper.dart';
import 'package:whph/core/acore/mapper/mapper.dart';

void registerApplication(IContainer container) {
  container.registerSingleton<IMapper>((_) => CoreMapper());

  Mediator mediator = Mediator(Pipeline());
  container.registerSingleton((_) => mediator);

  registerAppUsagesFeature(container, mediator);
  registerTasksFeature(container, mediator);
  registerTagsFeature(container, mediator);
  registerSettingsFeature(container, mediator);
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

  mediator.registerHandler<AddAppUsageTagCommand, AddAppUsageTagCommandResponse, AddAppUsageTagCommandHandler>(
    () => AddAppUsageTagCommandHandler(appUsageTagRepository: container.resolve<IAppUsageTagRepository>()),
  );
  mediator.registerHandler<RemoveAppUsageTagCommand, RemoveAppUsageTagCommandResponse, RemoveAppUsageTagCommandHandler>(
    () => RemoveAppUsageTagCommandHandler(appUsageTagRepository: container.resolve<IAppUsageTagRepository>()),
  );
  mediator.registerHandler<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse, GetListAppUsageTagsQueryHandler>(
    () => GetListAppUsageTagsQueryHandler(
      tagRepository: container.resolve<ITagRepository>(),
      appUsageTagRepository: container.resolve<IAppUsageTagRepository>(),
    ),
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
    () => GetTaskQueryHandler(taskRepository: container.resolve<ITaskRepository>()),
  );

  mediator.registerHandler<AddTaskTagCommand, AddTaskTagCommandResponse, AddTaskTagCommandHandler>(
    () => AddTaskTagCommandHandler(taskTagRepository: container.resolve<ITaskTagRepository>()),
  );
  mediator.registerHandler<RemoveTaskTagCommand, RemoveTaskTagCommandResponse, RemoveTaskTagCommandHandler>(
    () => RemoveTaskTagCommandHandler(taskTagRepository: container.resolve<ITaskTagRepository>()),
  );
  mediator.registerHandler<GetListTaskTagsQuery, GetListTaskTagsQueryResponse, GetListTaskTagsQueryHandler>(
    () => GetListTaskTagsQueryHandler(
      tagRepository: container.resolve<ITagRepository>(),
      taskTagRepository: container.resolve<ITaskTagRepository>(),
    ),
  );
}

void registerTagsFeature(IContainer container, Mediator mediator) {
  mediator.registerHandler<SaveTagCommand, SaveTagCommandResponse, SaveTagCommandHandler>(
    () => SaveTagCommandHandler(tagRepository: container.resolve<ITagRepository>()),
  );
  mediator.registerHandler<DeleteTagCommand, DeleteTagCommandResponse, DeleteTagCommandHandler>(
    () => DeleteTagCommandHandler(tagRepository: container.resolve<ITagRepository>()),
  );
  mediator.registerHandler<GetListTagsQuery, GetListTagsQueryResponse, GetListTagsQueryHandler>(
    () => GetListTagsQueryHandler(tagRepository: container.resolve<ITagRepository>()),
  );
  mediator.registerHandler<GetTagQuery, GetTagQueryResponse, GetTagQueryHandler>(
    () => GetTagQueryHandler(tagRepository: container.resolve<ITagRepository>()),
  );

  mediator.registerHandler<AddTagTagCommand, AddTagTagCommandResponse, AddTagTagCommandHandler>(
    () => AddTagTagCommandHandler(tagTagRepository: container.resolve<ITagTagRepository>()),
  );
  mediator.registerHandler<RemoveTagTagCommand, RemoveTagTagCommandResponse, RemoveTagTagCommandHandler>(
    () => RemoveTagTagCommandHandler(tagTagRepository: container.resolve<ITagTagRepository>()),
  );
  mediator.registerHandler<GetListTagTagsQuery, GetListTagTagsQueryResponse, GetListTagTagsQueryHandler>(
    () => GetListTagTagsQueryHandler(
      tagRepository: container.resolve<ITagRepository>(),
      tagTagRepository: container.resolve<ITagTagRepository>(),
    ),
  );
}

void registerSettingsFeature(IContainer container, Mediator mediator) {
  mediator.registerHandler<SaveSettingCommand, SaveSettingCommandResponse, SaveSettingCommandHandler>(
    () => SaveSettingCommandHandler(settingRepository: container.resolve<ISettingRepository>()),
  );
  mediator.registerHandler<DeleteSettingCommand, DeleteSettingCommandResponse, DeleteSettingCommandHandler>(
    () => DeleteSettingCommandHandler(settingRepository: container.resolve<ISettingRepository>()),
  );
  mediator.registerHandler<GetSettingQuery, GetSettingQueryResponse, GetSettingQueryHandler>(
    () => GetSettingQueryHandler(settingRepository: container.resolve<ISettingRepository>()),
  );
  mediator.registerHandler<GetListSettingsQuery, GetListSettingsQueryResponse, GetListSettingsQueryHandler>(
    () => GetListSettingsQueryHandler(settingRepository: container.resolve<ISettingRepository>()),
  );
}
