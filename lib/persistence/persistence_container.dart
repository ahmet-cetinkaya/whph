import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_repository.dart';
import 'package:whph/persistence/features/app_usages/drift_app_usage_tag_repository.dart';
import 'package:whph/persistence/features/habits/drift_habit_records_repository.dart';
import 'package:whph/persistence/features/habits/drift_habits_repository.dart';
import 'package:whph/persistence/features/settings/drift_settings_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_repository.dart';
import 'package:whph/persistence/features/tags/drift_tag_tag_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_tag_repository.dart';

void registerPersistence(IContainer container) {
  container.registerSingleton<IAppUsageRepository>((_) => DriftAppUsageRepository());
  container.registerSingleton<IAppUsageTagRepository>((_) => DriftAppUsageTagRepository());
  container.registerSingleton<IHabitRepository>((_) => DriftHabitRepository());
  container.registerSingleton<IHabitRecordRepository>((_) => DriftHabitRecordRepository());
  container.registerSingleton<ITagRepository>((_) => DriftTagRepository());
  container.registerSingleton<ITagTagRepository>((_) => DriftTagTagRepository());
  container.registerSingleton<ITaskRepository>((_) => DriftTaskRepository());
  container.registerSingleton<ITaskTagRepository>((_) => DriftTaskTagRepository());
  container.registerSingleton<ISettingRepository>((_) => DriftSettingRepository());
}
