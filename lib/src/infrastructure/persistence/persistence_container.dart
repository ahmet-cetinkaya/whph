import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_repository.dart';
import 'package:whph/src/core/application/features/notes/services/abstraction/i_note_tag_repository.dart';
import 'package:whph/src/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/src/core/application/features/sync/services/abstraction/i_sync_device_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/src/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_time_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/app_usages/drift_app_usage_ignore_rule_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/app_usages/drift_app_usage_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/app_usages/drift_app_usage_tag_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/app_usages/drift_app_usage_tag_rule_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/app_usages/drift_app_usage_time_record_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/habits/drift_habit_records_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/habits/drift_habit_tags_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/habits/drift_habits_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/notes/drift_note_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/notes/drift_note_tag_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/settings/drift_settings_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/sync/drift_sync_device_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/tags/drift_tag_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/tags/drift_tag_tag_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/tasks/drift_task_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/tasks/drift_task_tag_repository.dart';
import 'package:whph/src/infrastructure/persistence/features/tasks/drift_task_time_record_repository.dart';
import 'package:whph/src/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

void registerPersistence(IContainer container) {
  // Initialize the database with the container for dependency injection
  AppDatabase.instance(container);

  container.registerSingleton<IAppUsageIgnoreRuleRepository>((_) => DriftAppUsageIgnoreRuleRepository());
  container.registerSingleton<IAppUsageRepository>((_) => DriftAppUsageRepository());
  container.registerSingleton<IAppUsageTagRepository>((_) => DriftAppUsageTagRepository());
  container.registerSingleton<IAppUsageTagRuleRepository>((_) => DriftAppUsageTagRuleRepository());
  container.registerSingleton<IAppUsageTimeRecordRepository>((_) => DriftAppUsageTimeRecordRepository());
  container.registerSingleton<IHabitRecordRepository>((_) => DriftHabitRecordRepository());
  container.registerSingleton<IHabitRepository>((_) => DriftHabitRepository());
  container.registerSingleton<IHabitTagsRepository>((_) => DriftHabitTagRepository());
  container.registerSingleton<INoteRepository>((_) => DriftNoteRepository());
  container.registerSingleton<INoteTagRepository>((_) => DriftNoteTagRepository());
  container.registerSingleton<ISettingRepository>((_) => DriftSettingRepository());
  container.registerSingleton<ISyncDeviceRepository>((_) => DriftSyncDeviceRepository());
  container.registerSingleton<ITagRepository>((_) => DriftTagRepository());
  container.registerSingleton<ITagTagRepository>((_) => DriftTagTagRepository());
  container.registerSingleton<ITaskRepository>((_) => DriftTaskRepository());
  container.registerSingleton<ITaskTagRepository>((_) => DriftTaskTagRepository());
  container.registerSingleton<ITaskTimeRecordRepository>((_) => DriftTaskTimeRecordRepository());
}
