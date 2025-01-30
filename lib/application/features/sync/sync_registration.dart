import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/application/features/sync/commands/stop_sync_command.dart';
import 'package:whph/application/features/sync/commands/sync_command.dart';
import 'package:whph/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/application/features/sync/services/device_id_service.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/application/features/sync/services/sync_service.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';

void registerSyncFeature(
  IContainer container,
  Mediator mediator,
  IAppUsageIgnoreRuleRepository appUsageIgnoreRuleRepository,
  IAppUsageRepository appUsageRepository,
  IAppUsageTagRepository appUsageTagRepository,
  IAppUsageTagRuleRepository appUsageTagRuleRepository,
  IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
  IHabitRecordRepository habitRecordRepository,
  IHabitRepository habitRepository,
  IHabitTagsRepository habitTagRepository,
  ISettingRepository settingRepository,
  ISyncDeviceRepository syncDeviceRepository,
  ITagRepository tagRepository,
  ITagTagRepository tagTagRepository,
  ITaskRepository taskRepository,
  ITaskTagRepository taskTagRepository,
  ITaskTimeRecordRepository taskTimeRecordRepository,
) {
  container.registerSingleton<ISyncService>((_) => SyncService(mediator));
  final syncService = container.resolve<ISyncService>();

  container.registerSingleton<IDeviceIdService>((_) => DeviceIdService());
  final deviceIdService = container.resolve<IDeviceIdService>();

  mediator
    ..registerHandler<SaveSyncDeviceCommand, SaveSyncDeviceCommandResponse, SaveSyncDeviceCommandHandler>(
      () => SaveSyncDeviceCommandHandler(syncDeviceRepository: syncDeviceRepository),
    )
    ..registerHandler<DeleteSyncDeviceCommand, DeleteSyncDeviceCommandResponse, DeleteSyncDeviceCommandHandler>(
      () => DeleteSyncDeviceCommandHandler(syncDeviceRepository: syncDeviceRepository),
    )
    ..registerHandler<GetListSyncDevicesQuery, GetListSyncDevicesQueryResponse, GetListSyncDevicesQueryHandler>(
      () => GetListSyncDevicesQueryHandler(syncDeviceRepository: syncDeviceRepository),
    )
    ..registerHandler<GetSyncDeviceQuery, GetSyncDeviceQueryResponse?, GetSyncDeviceQueryHandler>(
      () => GetSyncDeviceQueryHandler(syncDeviceRepository: syncDeviceRepository),
    )
    ..registerHandler<SyncCommand, SyncCommandResponse, SyncCommandHandler>(
      () => SyncCommandHandler(
        appUsageIgnoreRuleRepository: appUsageIgnoreRuleRepository,
        appUsageRepository: appUsageRepository,
        appUsageTagRepository: appUsageTagRepository,
        appUsageTagRuleRepository: appUsageTagRuleRepository,
        appUsageTimeRecordRepository: appUsageTimeRecordRepository,
        habitRecordRepository: habitRecordRepository,
        habitRepository: habitRepository,
        habitTagRepository: habitTagRepository,
        settingRepository: settingRepository,
        syncDeviceRepository: syncDeviceRepository,
        tagRepository: tagRepository,
        tagTagRepository: tagTagRepository,
        taskRepository: taskRepository,
        taskTagRepository: taskTagRepository,
        taskTimeRecordRepository: taskTimeRecordRepository,
        deviceIdService: deviceIdService,
      ),
    )
    ..registerHandler<StartSyncCommand, void, StartSyncCommandHandler>(
      () => StartSyncCommandHandler(syncService),
    )
    ..registerHandler<StopSyncCommand, StopSyncCommandResponse, StopSyncCommandHandler>(
      () => StopSyncCommandHandler(syncService),
    );
}
