import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/add_app_usage_tag_rule_command.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_command.dart';
import 'package:whph/application/features/app_usages/commands/delete_app_usage_tag_rule_command.dart';
import 'package:whph/application/features/app_usages/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/app_usages/commands/save_app_usage_command.dart';
import 'package:whph/application/features/app_usages/commands/start_track_app_usages_command.dart';
import 'package:whph/application/features/app_usages/commands/stop_track_app_usages_command.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tag_rules_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/application/features/app_usages/services/app_usage_service.dart';
import 'package:whph/application/features/habits/commands/add_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_command.dart';
import 'package:whph/application/features/habits/commands/delete_habit_record_command.dart';
import 'package:whph/application/features/habits/commands/remove_habit_tag_command.dart';
import 'package:whph/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/features/settings/commands/delete_setting_command.dart';
import 'package:whph/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/application/features/settings/queries/get_list_settings_query.dart';
import 'package:whph/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/application/features/sync/commands/stop_sync_command.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/application/features/sync/services/sync_service.dart';
import 'package:whph/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/remove_tag_tag_command.dart';
import 'package:whph/application/features/tags/commands/save_tag_command.dart';
import 'package:whph/application/features/tags/queries/get_list_tag_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_times_data_query.dart';
import 'package:whph/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/delete_task_command.dart';
import 'package:whph/application/features/tasks/commands/remove_task_tag_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/application/features/tasks/commands/save_task_time_record_command.dart';
import 'package:whph/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tags/commands/delete_tag_command.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/mapper/abstraction/i_mapper.dart';
import 'package:whph/core/acore/mapper/mapper.dart';
import 'package:whph/application/features/habits/queries/get_list_habit_tags_query.dart';

void registerApplication(IContainer container) {
  container.registerSingleton<IMapper>((_) => CoreMapper());

  Mediator mediator = Mediator(Pipeline());
  container.registerSingleton((_) => mediator);

  registerAppUsagesFeature(container, mediator);
  registerHabitsFeature(container, mediator);
  registerTasksFeature(container, mediator);
  registerTagsFeature(container, mediator);
  registerSettingsFeature(container, mediator);
  registerSyncFeature(container, mediator);
}

void registerAppUsagesFeature(IContainer container, Mediator mediator) {
  container.registerSingleton<IAppUsageService>((_) => AppUsageService(
      container.resolve<IAppUsageRepository>(),
      container.resolve<IAppUsageTimeRecordRepository>(),
      container.resolve<IAppUsageTagRuleRepository>(),
      container.resolve<IAppUsageTagRepository>()));

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
    () => GetListByTopAppUsagesQueryHandler(
        appUsageRepository: container.resolve<IAppUsageRepository>(),
        timeRecordRepository: container.resolve<IAppUsageTimeRecordRepository>()),
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
  mediator.registerHandler<GetAppUsageQuery, GetAppUsageQueryResponse, GetAppUsageQueryHandler>(
    () => GetAppUsageQueryHandler(appUsageRepository: container.resolve<IAppUsageRepository>()),
  );
  mediator.registerHandler<SaveAppUsageCommand, SaveAppUsageCommandResponse, SaveAppUsageCommandHandler>(
    () => SaveAppUsageCommandHandler(appUsageRepository: container.resolve<IAppUsageRepository>()),
  );
  mediator.registerHandler<DeleteAppUsageCommand, DeleteAppUsageCommandResponse, DeleteAppUsageCommandHandler>(
    () => DeleteAppUsageCommandHandler(appUsageRepository: container.resolve<IAppUsageRepository>()),
  );
  mediator
      .registerHandler<AddAppUsageTagRuleCommand, AddAppUsageTagRuleCommandResponse, AddAppUsageTagRuleCommandHandler>(
    () => AddAppUsageTagRuleCommandHandler(repository: container.resolve<IAppUsageTagRuleRepository>()),
  );
  mediator.registerHandler<DeleteAppUsageTagRuleCommand, DeleteAppUsageTagRuleCommandResponse,
      DeleteAppUsageTagRuleCommandHandler>(
    () => DeleteAppUsageTagRuleCommandHandler(repository: container.resolve<IAppUsageTagRuleRepository>()),
  );
  mediator.registerHandler<GetListAppUsageTagRulesQuery, GetListAppUsageTagRulesQueryResponse,
      GetListAppUsageTagRulesQueryHandler>(
    () => GetListAppUsageTagRulesQueryHandler(
        appUsageRulesRepository: container.resolve<IAppUsageTagRuleRepository>(),
        tagRepository: container.resolve<ITagRepository>()),
  );
}

void registerHabitsFeature(IContainer container, Mediator mediator) {
  mediator.registerHandler<SaveHabitCommand, SaveHabitCommandResponse, SaveHabitCommandHandler>(
    () => SaveHabitCommandHandler(habitRepository: container.resolve<IHabitRepository>()),
  );
  mediator.registerHandler<DeleteHabitCommand, DeleteHabitCommandResponse, DeleteHabitCommandHandler>(
    () => DeleteHabitCommandHandler(habitRepository: container.resolve<IHabitRepository>()),
  );
  mediator.registerHandler<GetListHabitsQuery, GetListHabitsQueryResponse, GetListHabitsQueryHandler>(
    () => GetListHabitsQueryHandler(
        habitRepository: container.resolve<IHabitRepository>(),
        habitTagRepository: container.resolve<IHabitTagsRepository>(),
        tagRepository: container.resolve<ITagRepository>()),
  );
  mediator.registerHandler<GetHabitQuery, GetHabitQueryResponse, GetHabitQueryHandler>(
    () => GetHabitQueryHandler(
        habitRepository: container.resolve<IHabitRepository>(),
        habitRecordRepository: container.resolve<IHabitRecordRepository>()),
  );

  mediator.registerHandler<AddHabitRecordCommand, AddHabitRecordCommandResponse, AddHabitRecordCommandHandler>(
    () => AddHabitRecordCommandHandler(habitRecordRepository: container.resolve<IHabitRecordRepository>()),
  );
  mediator.registerHandler<DeleteHabitRecordCommand, DeleteHabitRecordCommandResponse, DeleteHabitRecordCommandHandler>(
    () => DeleteHabitRecordCommandHandler(habitRecordRepository: container.resolve<IHabitRecordRepository>()),
  );
  mediator.registerHandler<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse, GetListHabitRecordsQueryHandler>(
    () => GetListHabitRecordsQueryHandler(habitRecordRepository: container.resolve<IHabitRecordRepository>()),
  );
  mediator.registerHandler<GetListHabitTagsQuery, GetListHabitTagsQueryResponse, GetListHabitTagsQueryHandler>(
    () => GetListHabitTagsQueryHandler(
      tagRepository: container.resolve<ITagRepository>(),
      habitTagRepository: container.resolve<IHabitTagsRepository>(),
    ),
  );
  mediator.registerHandler<AddHabitTagCommand, AddHabitTagCommandResponse, AddHabitTagCommandHandler>(
    () => AddHabitTagCommandHandler(habitTagRepository: container.resolve<IHabitTagsRepository>()),
  );
  mediator.registerHandler<RemoveHabitTagCommand, RemoveHabitTagCommandResponse, RemoveHabitTagCommandHandler>(
    () => RemoveHabitTagCommandHandler(habitTagRepository: container.resolve<IHabitTagsRepository>()),
  );
}

void registerTasksFeature(IContainer container, Mediator mediator) {
  mediator.registerHandler<SaveTaskCommand, SaveTaskCommandResponse, SaveTaskCommandHandler>(
    () => SaveTaskCommandHandler(
        taskService: container.resolve<ITaskRepository>(), taskTagRepository: container.resolve<ITaskTagRepository>()),
  );
  mediator.registerHandler<DeleteTaskCommand, DeleteTaskCommandResponse, DeleteTaskCommandHandler>(
    () => DeleteTaskCommandHandler(taskRepository: container.resolve<ITaskRepository>()),
  );
  mediator.registerHandler<GetListTasksQuery, GetListTasksQueryResponse, GetListTasksQueryHandler>(
    () => GetListTasksQueryHandler(
      taskRepository: container.resolve<ITaskRepository>(),
      taskTagRepository: container.resolve<ITaskTagRepository>(),
      tagRepository: container.resolve<ITagRepository>(),
    ),
  );
  mediator.registerHandler<GetTaskQuery, GetTaskQueryResponse, GetTaskQueryHandler>(
    () => GetTaskQueryHandler(
        taskRepository: container.resolve<ITaskRepository>(),
        taskTimeRecordRepository: container.resolve<ITaskTimeRecordRepository>()),
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
  mediator
      .registerHandler<SaveTaskTimeRecordCommand, SaveTaskTimeRecordCommandResponse, SaveTaskTimeRecordCommandHandler>(
    () => SaveTaskTimeRecordCommandHandler(taskTimeRecordRepository: container.resolve<ITaskTimeRecordRepository>()),
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
  mediator.registerHandler<GetTagTimesDataQuery, GetTagTimesDataQueryResponse, GetTagTimesDataQueryHandler>(
    () => GetTagTimesDataQueryHandler(
      appUsageTimeRecordRepository: container.resolve<IAppUsageTimeRecordRepository>(),
      appUsageTagRepository: container.resolve<IAppUsageTagRepository>(),
      taskRepository: container.resolve<ITaskRepository>(),
      taskTagRepository: container.resolve<ITaskTagRepository>(),
      taskTimeRecordRepository: container.resolve<ITaskTimeRecordRepository>(),
    ),
  );
  mediator.registerHandler<GetTopTagsByTimeQuery, GetTopTagsByTimeQueryResponse, GetTopTagsByTimeQueryHandler>(
    () => GetTopTagsByTimeQueryHandler(
      appUsageTagRepository: container.resolve<IAppUsageTagRepository>(),
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

void registerSyncFeature(IContainer container, Mediator mediator) {
  container.registerSingleton<ISyncService>((_) => SyncService(mediator));

  mediator.registerHandler<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse, SaveSyncDeviceCommandHandler>(
    () => SaveSyncDeviceCommandHandler(syncDeviceRepository: container.resolve<ISyncDeviceRepository>()),
  );
  mediator.registerHandler<DeleteSyncDeviceCommand, DeleteSyncDeviceCommandResponse, DeleteSyncDeviceCommandHandler>(
    () => DeleteSyncDeviceCommandHandler(syncDeviceRepository: container.resolve<ISyncDeviceRepository>()),
  );
  mediator.registerHandler<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse, GetListSyncDevicesQueryHandler>(
    () => GetListSyncDevicesQueryHandler(syncDeviceRepository: container.resolve<ISyncDeviceRepository>()),
  );
  mediator.registerHandler<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?, GetSyncDeviceQueryHandler>(
    () => GetSyncDeviceQueryHandler(
      syncDeviceRepository: container.resolve<ISyncDeviceRepository>(),
    ),
  );
  mediator.registerHandler<SyncCommand, SyncCommandResponse, SyncCommandHandler>(
    () => SyncCommandHandler(
      appUsageRepository: container.resolve<IAppUsageRepository>(),
      appUsageTagRepository: container.resolve<IAppUsageTagRepository>(),
      appUsageTagRuleRepository: container.resolve<IAppUsageTagRuleRepository>(),
      appUsageTimeRecordRepository: container.resolve<IAppUsageTimeRecordRepository>(),
      habitRecordRepository: container.resolve<IHabitRecordRepository>(),
      habitRepository: container.resolve<IHabitRepository>(),
      habitTagRepository: container.resolve<IHabitTagsRepository>(),
      settingRepository: container.resolve<ISettingRepository>(),
      syncDeviceRepository: container.resolve<ISyncDeviceRepository>(),
      tagRepository: container.resolve<ITagRepository>(),
      tagTagRepository: container.resolve<ITagTagRepository>(),
      taskRepository: container.resolve<ITaskRepository>(),
      taskTagRepository: container.resolve<ITaskTagRepository>(),
      taskTimeRecordRepository: container.resolve<ITaskTimeRecordRepository>(),
    ),
  );
  mediator.registerHandler<StartSyncCommand, void, StartSyncCommandHandler>(
    () => StartSyncCommandHandler(container.resolve<ISyncService>()),
  );
  mediator.registerHandler<StopSyncCommand, StopSyncCommandResponse, StopSyncCommandHandler>(
    () => StopSyncCommandHandler(container.resolve<ISyncService>()),
  );
}
