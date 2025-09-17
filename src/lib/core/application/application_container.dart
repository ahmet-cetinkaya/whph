import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/app_usages_registration.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/application/features/demo/services/abstraction/i_demo_data_service.dart';
import 'package:whph/core/application/features/demo/services/demo_data_service.dart';
import 'package:whph/core/application/features/habits/habits_registration.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/notes/notes_registration.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/core/application/features/settings/settings_registration.dart';
import 'package:whph/core/application/features/sync/sync_registration.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/core/application/features/tags/tags_registration.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/core/application/features/tasks/tasks_registration.dart';
import 'package:whph/core/application/features/widget/widget_registration.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_directory_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_logger_service.dart';
import 'package:whph/core/application/shared/services/logger_service.dart';
import 'package:whph/core/application/shared/services/abstraction/i_log_export_service.dart';
import 'package:whph/core/application/shared/services/log_export_service.dart';

void registerApplication(IContainer container) {
  container.registerSingleton<IMapper>((_) => CoreMapper());

  Mediator mediator = Mediator(Pipeline());
  container.registerSingleton((_) => mediator);

  // Register Logger Service
  container.registerSingleton<ILoggerService>((_) => LoggerService(
        applicationDirectoryService: container.resolve<IApplicationDirectoryService>(),
        mediator: mediator,
        initialLogger: container.resolve<ILogger>(),
      ));

  // Register Log Export Service
  container.registerSingleton<ILogExportService>((_) => LogExportService());

  // Common Dependencies
  final appUsageIgnoreRuleRepository = container.resolve<IAppUsageIgnoreRuleRepository>();
  final appUsageRepository = container.resolve<IAppUsageRepository>();
  final appUsageService = container.resolve<IAppUsageService>();
  final appUsageTagRepository = container.resolve<IAppUsageTagRepository>();
  final habitRecordRepository = container.resolve<IHabitRecordRepository>();
  final habitRepository = container.resolve<IHabitRepository>();
  final habitTimeRecordRepository = container.resolve<IHabitTimeRecordRepository>();
  final habitTagRepository = container.resolve<IHabitTagsRepository>();
  final noteRepository = container.resolve<INoteRepository>();
  final noteTagRepository = container.resolve<INoteTagRepository>();
  final settingRepository = container.resolve<ISettingRepository>();
  final syncDeviceRepository = container.resolve<ISyncDeviceRepository>();
  final tagRepository = container.resolve<ITagRepository>();
  final appUsageTagRuleRepository = container.resolve<IAppUsageTagRuleRepository>();
  final tagTagRepository = container.resolve<ITagTagRepository>();
  final taskRepository = container.resolve<ITaskRepository>();
  final taskTagRepository = container.resolve<ITaskTagRepository>();
  final taskTimeRecordRepository = container.resolve<ITaskTimeRecordRepository>();
  final appUsageTimeRecordRepository = container
      .resolve<IAppUsageTimeRecordRepository>(); // Register Demo Data Service (conditionally based on environment)
  container.registerSingleton<IDemoDataService>((_) => DemoDataService(
        settingRepository: settingRepository,
        tagRepository: tagRepository,
        taskRepository: taskRepository,
        taskTagRepository: taskTagRepository,
        taskTimeRecordRepository: taskTimeRecordRepository,
        habitRepository: habitRepository,
        habitRecordRepository: habitRecordRepository,
        habitTagRepository: habitTagRepository,
        noteRepository: noteRepository,
        noteTagRepository: noteTagRepository,
        appUsageRepository: appUsageRepository,
        appUsageTimeRecordRepository: appUsageTimeRecordRepository,
        appUsageTagRepository: appUsageTagRepository,
      ));

  // Register Features
  registerAppUsagesFeature(container, mediator, appUsageService, appUsageRepository, tagRepository,
      appUsageTagRepository, appUsageTagRuleRepository, appUsageTimeRecordRepository, appUsageIgnoreRuleRepository);
  registerHabitsFeature(container, mediator, habitRepository, habitRecordRepository, habitTagRepository,
      habitTimeRecordRepository, tagRepository);
  registerNotesFeature(
    container,
    mediator,
    noteRepository,
    noteTagRepository,
    tagRepository,
  );
  registerTasksFeature(
    container,
    mediator,
    taskRepository,
    taskTagRepository,
    taskTimeRecordRepository,
    tagRepository,
  );
  registerTagsFeature(
    container,
    mediator,
    tagRepository,
    tagTagRepository,
    appUsageTagRepository,
    appUsageTimeRecordRepository,
    taskRepository,
    taskTagRepository,
    taskTimeRecordRepository,
    habitRepository,
    habitRecordRepository,
    habitTimeRecordRepository,
    habitTagRepository,
    noteTagRepository,
  );
  registerSettingsFeature(
    container,
    mediator,
    settingRepository,
    appUsageIgnoreRuleRepository,
    appUsageRepository,
    appUsageTagRepository,
    appUsageTagRuleRepository,
    appUsageTimeRecordRepository,
    habitRecordRepository,
    habitRepository,
    habitTagRepository,
    syncDeviceRepository,
    tagRepository,
    tagTagRepository,
    taskRepository,
    taskTagRepository,
    taskTimeRecordRepository,
    noteRepository,
    noteTagRepository,
  );
  registerSyncFeature(
    container,
    mediator,
    appUsageIgnoreRuleRepository,
    appUsageRepository,
    appUsageTagRepository,
    appUsageTagRuleRepository,
    appUsageTimeRecordRepository,
    habitRecordRepository,
    habitRepository,
    habitTagRepository,
    settingRepository,
    syncDeviceRepository,
    tagRepository,
    tagTagRepository,
    taskRepository,
    taskTagRepository,
    taskTimeRecordRepository,
    noteRepository,
    noteTagRepository,
  );
  registerWidgetFeature(container, mediator);
}
