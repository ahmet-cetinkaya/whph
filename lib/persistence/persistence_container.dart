import 'package:whph/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:whph/application/features/topics/services/abstraction/i_topic_repository.dart';
import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/application/features/app_usage/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/persistence/features/app_usage/drift_app_usage_repository.dart';
import 'package:whph/persistence/features/tasks/drift_task_repository.dart';
import 'package:whph/persistence/features/topics/drift_topic_repository.dart';

void registerPersistence(IContainer container) {
  container.registerSingleton<IAppUsageRepository>((_) => DriftAppUsageRepository());
  container.registerSingleton<ITopicRepository>((_) => DriftTopicRepository());
  container.registerSingleton<ITaskRepository>((_) => DriftTaskRepository());
}
