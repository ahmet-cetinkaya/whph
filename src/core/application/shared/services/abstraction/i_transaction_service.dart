import 'dart:io';
import 'package:drift/drift.dart';

/// Abstract interface for database transaction operations.
/// This allows the application layer to perform transactions
/// without depending on the infrastructure implementation.
abstract class ITransactionService {
  /// Executes a function within a database transaction.
  /// If the function throws, all changes are rolled back.
  /// Returns the result of the function.
  Future<T> runInTransaction<T>(Future<T> Function() action);

  /// Creates a database backup.
  /// Returns the backup file or null if backup failed.
  Future<File?> createDatabaseBackup();

  /// Validates foreign key integrity.
  /// Returns list of integrity violations.
  Future<List<Map<String, dynamic>>> checkForeignKeyIntegrity();

  /// Executes a custom SQL statement and returns the result.
  Selectable<dynamic> customSelect(String sql, {List<Variable>? variables});

  /// Executes a custom SQL statement without returning a result.
  Future<void> customStatement(String sql, [List<Object?>? args]);
}
