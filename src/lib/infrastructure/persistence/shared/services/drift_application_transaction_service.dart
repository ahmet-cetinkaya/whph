import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

final class DriftApplicationTransactionService implements IApplicationTransactionService {
  const DriftApplicationTransactionService(this._database);

  final AppDatabase _database;

  @override
  Future<T> run<T>(Future<T> Function() operation) => _database.transaction(operation);
}
