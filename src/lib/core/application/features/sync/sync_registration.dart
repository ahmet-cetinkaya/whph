import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/sync/commands/delete_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/save_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/start_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/stop_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/paginated_sync_command/paginated_sync_command.dart';
import 'package:whph/core/application/features/sync/commands/update_sync_device_ip_command.dart';
import 'package:whph/core/application/features/sync/queries/get_list_syncs_query.dart';
import 'package:whph/core/application/features/sync/queries/get_sync_query.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/network_interface_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_concurrent_connection_service.dart';
import 'package:whph/core/application/features/sync/services/concurrent_connection_service.dart';
import 'package:whph/core/application/features/sync/services/device_handshake_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_validation_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_data_processing_service.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/sync_configuration_service.dart';
import 'package:whph/core/application/features/sync/services/sync_validation_service.dart';
import 'package:whph/core/application/features/sync/services/sync_communication_service.dart';
import 'package:whph/core/application/features/sync/services/sync_data_processing_service.dart';
import 'package:whph/core/application/features/sync/services/sync_pagination_service.dart';
import 'package:whph/core/application/features/sync/services/database_integrity_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
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

  final deviceIdService = container.resolve<IDeviceIdService>();

  // Register network interface service
  container.registerSingleton<INetworkInterfaceService>((_) => NetworkInterfaceService());

  // Register concurrent connection service
  container.registerSingleton<IConcurrentConnectionService>((_) => ConcurrentConnectionService());

  // Register device handshake service
  container.registerSingleton<DeviceHandshakeService>((_) => DeviceHandshakeService());

  // Register sync configuration service
  container.registerSingleton<ISyncConfigurationService>((_) => SyncConfigurationService(
        appUsageRepository: appUsageRepository,
        appUsageTagRepository: appUsageTagRepository,
        appUsageTimeRecordRepository: appUsageTimeRecordRepository,
        appUsageTagRuleRepository: appUsageTagRuleRepository,
        appUsageIgnoreRuleRepository: appUsageIgnoreRuleRepository,
        habitRepository: habitRepository,
        habitRecordRepository: habitRecordRepository,
        habitTagRepository: habitTagRepository,
        tagRepository: tagRepository,
        tagTagRepository: tagTagRepository,
        taskRepository: taskRepository,
        taskTagRepository: taskTagRepository,
        taskTimeRecordRepository: taskTimeRecordRepository,
        settingRepository: settingRepository,
        syncDeviceRepository: syncDeviceRepository,
        noteRepository: noteRepository,
        noteTagRepository: noteTagRepository,
      ));

  // Register sync validation service
  container.registerSingleton<ISyncValidationService>((_) => SyncValidationService(
        deviceIdService: deviceIdService,
      ));

  // Register sync communication service
  container.registerSingleton<ISyncCommunicationService>((_) => SyncCommunicationService());

  // Register sync data processing service
  container.registerSingleton<ISyncDataProcessingService>((_) => SyncDataProcessingService());

  // Register sync pagination service
  container.registerSingleton<ISyncPaginationService>((_) => SyncPaginationService(
        communicationService: container.resolve<ISyncCommunicationService>(),
        configurationService: container.resolve<ISyncConfigurationService>(),
      ));

  // Register database integrity service
  container.registerSingleton<DatabaseIntegrityService>((_) => DatabaseIntegrityService(
        AppDatabase.instance(),
      ));

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
        syncDeviceRepository: syncDeviceRepository,
        configurationService: container.resolve<ISyncConfigurationService>(),
        validationService: container.resolve<ISyncValidationService>(),
        communicationService: container.resolve<ISyncCommunicationService>(),
        dataProcessingService: container.resolve<ISyncDataProcessingService>(),
        paginationService: container.resolve<ISyncPaginationService>(),
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
