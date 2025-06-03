import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/src/core/application/features/settings/commands/export_data_command.dart';
import 'package:whph/src/core/application/features/settings/commands/import_data_command.dart';
import 'package:whph/src/core/application/features/settings/services/import_data_migration_service.dart';
import 'package:whph/corePackages/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/src/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/src/core/application/features/settings/commands/delete_setting_command.dart';
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/src/core/application/features/settings/queries/get_list_settings_query.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_import_data_migration_service.dart';

void registerSettingsFeature(
  IContainer container,
  Mediator mediator,
  ISettingRepository settingRepository,
  IAppUsageIgnoreRuleRepository appUsageIgnoreRuleRepository,
  IAppUsageRepository appUsageRepository,
  IAppUsageTagRepository appUsageTagRepository,
  IAppUsageTagRuleRepository appUsageTagRuleRepository,
  IAppUsageTimeRecordRepository appUsageTimeRecordRepository,
  IHabitRecordRepository habitRecordRepository,
  IHabitRepository habitRepository,
  IHabitTagsRepository habitTagRepository,
  ISyncDeviceRepository syncDeviceRepository,
  ITagRepository tagRepository,
  ITagTagRepository tagTagRepository,
  ITaskRepository taskRepository,
  ITaskTagRepository taskTagRepository,
  ITaskTimeRecordRepository taskTimeRecordRepository,
  INoteRepository noteRepository,
  INoteTagRepository noteTagRepository,
) {
  // Register the import data migration service
  container.registerSingleton<IImportDataMigrationService>((_) => ImportDataMigrationService());

  mediator
    ..registerHandler<SaveSettingCommand, SaveSettingCommandResponse, SaveSettingCommandHandler>(
      () => SaveSettingCommandHandler(settingRepository: settingRepository),
    )
    ..registerHandler<DeleteSettingCommand, DeleteSettingCommandResponse, DeleteSettingCommandHandler>(
      () => DeleteSettingCommandHandler(settingRepository: settingRepository),
    )
    ..registerHandler<GetSettingQuery, GetSettingQueryResponse, GetSettingQueryHandler>(
      () => GetSettingQueryHandler(settingRepository: settingRepository),
    )
    ..registerHandler<GetListSettingsQuery, GetListSettingsQueryResponse, GetListSettingsQueryHandler>(
      () => GetListSettingsQueryHandler(settingRepository: settingRepository),
    )
    ..registerHandler<ExportDataCommand, ExportDataCommandResponse, ExportDataCommandHandler>(
      () => ExportDataCommandHandler(
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
      ),
    )
    ..registerHandler<ImportDataCommand, ImportDataCommandResponse, ImportDataCommandHandler>(
      () => ImportDataCommandHandler(
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
        migrationService: container.resolve<IImportDataMigrationService>(),
      ),
    );
}
