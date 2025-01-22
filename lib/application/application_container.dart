import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/app_usages_registration.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/application/features/habits/habits_registration.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/features/settings/settings_registration.dart';
import 'package:whph/application/features/sync/sync_registration.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/application/features/tags/tags_registration.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:whph/application/features/tasks/tasks_registration.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/core/acore/mapper/abstraction/i_mapper.dart';
import 'package:whph/core/acore/mapper/mapper.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/application/features/sync/services/abstraction/i_sync_device_repository.dart';

void registerApplication(IContainer container) {
  container.registerSingleton<IMapper>((_) => CoreMapper());

  Mediator mediator = Mediator(Pipeline());
  container.registerSingleton((_) => mediator);

  // Common Dependencies
  final appUsageRepository = container.resolve<IAppUsageRepository>();
  final appUsageService = container.resolve<IAppUsageService>();
  final appUsageTagRepository = container.resolve<IAppUsageTagRepository>();
  final habitRecordRepository = container.resolve<IHabitRecordRepository>();
  final habitRepository = container.resolve<IHabitRepository>();
  final habitTagRepository = container.resolve<IHabitTagsRepository>();
  final settingRepository = container.resolve<ISettingRepository>();
  final syncDeviceRepository = container.resolve<ISyncDeviceRepository>();
  final tagRepository = container.resolve<ITagRepository>();
  final tagRuleRepository = container.resolve<IAppUsageTagRuleRepository>();
  final tagTagRepository = container.resolve<ITagTagRepository>();
  final taskRepository = container.resolve<ITaskRepository>();
  final taskTagRepository = container.resolve<ITaskTagRepository>();
  final taskTimeRecordRepository = container.resolve<ITaskTimeRecordRepository>();
  final timeRecordRepository = container.resolve<IAppUsageTimeRecordRepository>();

  // Register Features
  registerAppUsagesFeature(container, mediator, appUsageService, appUsageRepository, tagRepository,
      appUsageTagRepository, tagRuleRepository, timeRecordRepository);
  registerHabitsFeature(container, mediator, habitRepository, habitRecordRepository, habitTagRepository, tagRepository);
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
    timeRecordRepository,
    taskRepository,
    taskTagRepository,
    taskTimeRecordRepository,
  );
  registerSettingsFeature(
    container,
    mediator,
    settingRepository,
  );
  registerSyncFeature(
    container,
    mediator,
    syncDeviceRepository,
    appUsageRepository,
    appUsageTagRepository,
    tagRuleRepository,
    timeRecordRepository,
    habitRecordRepository,
    habitRepository,
    habitTagRepository,
    settingRepository,
    tagRepository,
    tagTagRepository,
    taskRepository,
    taskTagRepository,
    taskTimeRecordRepository,
  );
}
