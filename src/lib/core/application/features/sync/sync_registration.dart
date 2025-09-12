import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/stop_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/update_sync_device_ip_command.dart';
import 'package:whph/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/device_id_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_concurrent_connection_service.dart';
import 'package:whph/core/application/features/sync/services/concurrent_connection_service.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';

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
  INoteRepository noteRepository,
  INoteTagRepository noteTagRepository,
) {
  // ISyncService is registered in infrastructure_container.dart with platform-specific implementations
  final syncService = container.resolve<ISyncService>();

  // IApplicationDirectoryService is registered in infrastructure_container.dart with platform-specific implementations
  final applicationDirectoryService = container.resolve<IApplicationDirectoryService>();

  // Register device ID service with dependency injection
  container.registerSingleton<IDeviceIdService>((_) => DeviceIdService(
        applicationDirectoryService: applicationDirectoryService,
      ));
  final deviceIdService = container.resolve<IDeviceIdService>();

  // Register network interface service
  container.registerSingleton<INetworkInterfaceService>((_) => NetworkInterfaceService());

  // Register concurrent connection service
  container.registerSingleton<IConcurrentConnectionService>((_) => ConcurrentConnectionService());
  
  // Register device handshake service
  container.registerSingleton<DeviceHandshakeService>((_) => DeviceHandshakeService());

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
    ..registerHandler<PaginatedSyncCommand, PaginatedSyncCommandResponse, PaginatedSyncCommandHandler>(
      () => PaginatedSyncCommandHandler(
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
        noteRepository: noteRepository,
        noteTagRepository: noteTagRepository,
        deviceIdService: deviceIdService,
      ),
    )
    ..registerHandler<StartSyncCommand, void, StartSyncCommandHandler>(
      () => StartSyncCommandHandler(syncService),
    )
    ..registerHandler<StopSyncCommand, StopSyncCommandResponse, StopSyncCommandHandler>(
      () => StopSyncCommandHandler(syncService),
    )
    ..registerHandler<UpdateSyncDeviceIpCommand, UpdateSyncDeviceIpCommandResponse, UpdateSyncDeviceIpCommandHandler>(
      () => UpdateSyncDeviceIpCommandHandler(syncDeviceRepository: syncDeviceRepository),
    );
}
