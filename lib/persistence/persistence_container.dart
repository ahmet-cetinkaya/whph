import 'package:whph/core/acore/dependency_injection/abstraction/i_container.dart';
import 'package:whph/application/features/app_usage/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/persistence/features/app_usage/drift_app_usage_repository.dart';

void registerPersistence(IContainer container) {
  container.registerSingleton<IAppUsageRepository>((_) => DriftAppUsageRepository());
}
