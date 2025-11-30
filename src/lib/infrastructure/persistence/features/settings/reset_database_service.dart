import 'package:whph/core/application/features/settings/services/abstraction/i_reset_database_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

class ResetDatabaseService implements IResetDatabaseService {
  final AppDatabase _appDatabase;

  ResetDatabaseService({required AppDatabase appDatabase}) : _appDatabase = appDatabase;

  @override
  Future<void> resetDatabase() async {
    await _appDatabase.resetDatabase();
  }
}
