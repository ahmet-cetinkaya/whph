import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

class DatabaseIntegrityService {
  final AppDatabase _database;

  DatabaseIntegrityService(this._database);

  /// Validates database integrity and reports any issues
  Future<DatabaseIntegrityReport> validateIntegrity() async {
    final report = DatabaseIntegrityReport();

    await _checkDuplicateIds(report);
    await _checkOrphanedReferences(report);
    await _checkSoftDeletedConsistency(report);

    return report;
  }

  /// Automatically fix common integrity issues
  Future<void> fixIntegrityIssues() async {
    Logger.info('🔧 Starting database integrity fixes...');

    await _fixDuplicateIds();
    await _cleanupOrphanedReferences();

    Logger.info('✅ Database integrity fixes completed');
  }

  Future<void> _checkDuplicateIds(DatabaseIntegrityReport report) async {
    final tables = [
      'tag_table',
      'task_tag_table',
      'habit_tag_table',
      'app_usage_tag_table',
      'note_tag_table',
      'tag_tag_table',
    ];

    for (final tableName in tables) {
      final duplicates = await _database.customSelect('''
        SELECT id, COUNT(*) as count
        FROM $tableName
        WHERE deleted_date IS NULL
        GROUP BY id
        HAVING COUNT(*) > 1
      ''').get();

      if (duplicates.isNotEmpty) {
        report.duplicateIds[tableName] = duplicates.length;
        Logger.warning('Found ${duplicates.length} duplicate IDs in $tableName');
      }
    }
  }

  Future<void> _checkOrphanedReferences(DatabaseIntegrityReport report) async {
    // Check for task_tags referencing non-existent tags
    final orphanedTaskTags = await _database.customSelect('''
      SELECT COUNT(*) as count
      FROM task_tag_table tt
      LEFT JOIN tag_table t ON tt.tag_id = t.id AND t.deleted_date IS NULL
      WHERE tt.deleted_date IS NULL AND t.id IS NULL
    ''').getSingleOrNull();

    if (orphanedTaskTags != null) {
      final count = orphanedTaskTags.data['count'] as int? ?? 0;
      if (count > 0) {
        report.orphanedReferences['task_tags'] = count;
        Logger.warning('Found $count orphaned task-tag references');
      }
    }
  }

  Future<void> _checkSoftDeletedConsistency(DatabaseIntegrityReport report) async {
    // Check for inconsistent soft-delete states
    final inconsistencies = await _database.customSelect('''
      SELECT COUNT(*) as count
      FROM task_tag_table tt
      INNER JOIN tag_table t ON tt.tag_id = t.id
      WHERE tt.deleted_date IS NULL AND t.deleted_date IS NOT NULL
    ''').getSingleOrNull();

    if (inconsistencies != null) {
      final count = inconsistencies.data['count'] as int? ?? 0;
      if (count > 0) {
        report.softDeleteInconsistencies = count;
        Logger.warning('Found $count soft-delete inconsistencies');
      }
    }
  }

  Future<void> _fixDuplicateIds() async {
    final tables = [
      'tag_table',
      'task_tag_table',
      'habit_tag_table',
      'app_usage_tag_table',
      'note_tag_table',
      'tag_tag_table',
    ];

    for (final tableName in tables) {
      Logger.info('🔧 Fixing duplicates in $tableName...');

      // Keep the most recent record for each ID, soft-delete the rest
      await _database.customStatement('''
        UPDATE $tableName
        SET deleted_date = CURRENT_TIMESTAMP
        WHERE rowid NOT IN (
          SELECT MAX(rowid)
          FROM $tableName
          WHERE deleted_date IS NULL
          GROUP BY id
        ) AND deleted_date IS NULL
      ''');
    }
  }

  Future<void> _cleanupOrphanedReferences() async {
    Logger.info('🔧 Cleaning up orphaned references...');

    // Soft-delete task_tags that reference deleted tags
    await _database.customStatement('''
      UPDATE task_tag_table
      SET deleted_date = CURRENT_TIMESTAMP
      WHERE tag_id NOT IN (
        SELECT id FROM tag_table WHERE deleted_date IS NULL
      ) AND deleted_date IS NULL
    ''');

    // Soft-delete habit_tags that reference deleted tags
    await _database.customStatement('''
      UPDATE habit_tag_table
      SET deleted_date = CURRENT_TIMESTAMP
      WHERE tag_id NOT IN (
        SELECT id FROM tag_table WHERE deleted_date IS NULL
      ) AND deleted_date IS NULL
    ''');
  }
}

class DatabaseIntegrityReport {
  final Map<String, int> duplicateIds = {};
  final Map<String, int> orphanedReferences = {};
  int softDeleteInconsistencies = 0;

  bool get hasIssues => duplicateIds.isNotEmpty || orphanedReferences.isNotEmpty || softDeleteInconsistencies > 0;

  @override
  String toString() {
    if (!hasIssues) return 'Database integrity: ✅ No issues found';

    final buffer = StringBuffer('Database integrity issues found:\n');

    if (duplicateIds.isNotEmpty) {
      buffer.writeln('🔄 Duplicate IDs:');
      duplicateIds.forEach((table, count) {
        buffer.writeln('  - $table: $count duplicates');
      });
    }

    if (orphanedReferences.isNotEmpty) {
      buffer.writeln('🔗 Orphaned references:');
      orphanedReferences.forEach((type, count) {
        buffer.writeln('  - $type: $count orphaned');
      });
    }

    if (softDeleteInconsistencies > 0) {
      buffer.writeln('❌ Soft-delete inconsistencies: $softDeleteInconsistencies');
    }

    return buffer.toString();
  }
}
