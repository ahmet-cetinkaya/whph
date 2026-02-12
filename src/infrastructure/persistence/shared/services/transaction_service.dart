import 'dart:io';
import 'package:drift/drift.dart';
import 'package:application/shared/services/abstraction/i_transaction_service.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';

/// Drift-based implementation of ITransactionService.
/// Wraps AppDatabase.instance() transaction method.
class TransactionService implements ITransactionService {
  final AppDatabase _database = AppDatabase.instance();

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    return _database.transaction(action);
  }

  @override
  Future<File?> createDatabaseBackup() {
    return _database.createDatabaseBackup();
  }

  @override
  Future<List<Map<String, dynamic>>> checkForeignKeyIntegrity() async {
    final violations = await _database.customSelect('PRAGMA foreign_key_check').get();
    return violations.map((row) => row.data).toList();
  }

  @override
  Selectable<dynamic> customSelect(String sql, {List<Variable>? variables}) {
    return _database.customSelect(sql, variables: variables ?? const []);
  }

  @override
  Future<void> customStatement(String sql, [List<Object?>? args]) {
    return _database.customStatement(sql, args ?? const []);
  }
}
