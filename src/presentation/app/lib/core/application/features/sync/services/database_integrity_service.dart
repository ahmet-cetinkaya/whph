import 'package:drift/drift.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
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
    await _checkSyncStateConsistency(report);
    await _checkTimestampConsistency(report);

    return report;
  }

  /// Automatically fix common integrity issues
  /// Returns a report containing any repair failures that occurred
  Future<DatabaseIntegrityReport> fixIntegrityIssues() async {
    Logger.info('Starting database integrity fixes...');
    final report = DatabaseIntegrityReport();

    await _repairCorruptedTimestamps(report);
    await _fixDuplicateIds(report);
    await _cleanupOrphanedReferences(report);
    await _fixSyncStateIssues(report);

    Logger.info('Database integrity fixes completed');
    if (report.repairFailures.isNotEmpty) {
      Logger.warning('${report.repairFailures.length} repair operations failed');
    }
    return report;
  }

  /// Fix only critical integrity issues (not ancient devices)
  /// Returns a report containing any repair failures that occurred
  Future<DatabaseIntegrityReport> fixCriticalIntegrityIssues() async {
    Logger.info('Starting critical database integrity fixes...');
    final report = DatabaseIntegrityReport();

    await _repairCorruptedTimestamps(report);
    await _fixDuplicateIds(report);
    await _cleanupOrphanedReferences(report);
    // Skip _fixSyncStateIssues() as it includes ancient device cleanup

    Logger.info('Critical database integrity fixes completed');
    if (report.repairFailures.isNotEmpty) {
      Logger.warning('${report.repairFailures.length} repair operations failed');
    }
    return report;
  }

  /// Check for fields that represent timestamps but contain text/string values
  Future<void> _checkTimestampConsistency(DatabaseIntegrityReport report) async {
    Logger.debug('Checking timestamp consistency...');

    // Map of table names to their date columns that need checking
    final tableColumns = {
      'sync_device_table': ['created_date', 'modified_date', 'deleted_date', 'last_sync_date'],
      'tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'task_tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'habit_tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'app_usage_tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'note_tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'tag_tag_table': ['created_date', 'modified_date', 'deleted_date'],
    };

    int corruptedCount = 0;

    for (final entry in tableColumns.entries) {
      final table = entry.key;
      final columns = entry.value;

      for (final column in columns) {
        try {
          final hasTextData = await _database.customSelect('''
            SELECT COUNT(*) as count 
            FROM $table 
            WHERE typeof($column) = 'text'
          ''').getSingleOrNull();

          if (hasTextData != null) {
            final count = hasTextData.data['count'] as int? ?? 0;
            if (count > 0) {
              corruptedCount += count;
              Logger.warning('Found $count rows in $table.$column with corrupted text timestamp');
            }
          }
        } catch (e, stackTrace) {
          // Table or column might not exist during schema migrations
          Logger.debug('Table or column not found during timestamp check: $table.$column - $e', stackTrace: stackTrace);
        }
      }
    }

    if (corruptedCount > 0) {
      report.timestampInconsistencies = corruptedCount;
    }
  }

  /// Repair fields that were incorrectly set to string values (e.g. CURRENT_TIMESTAMP)
  /// instead of integer timestamps.
  Future<void> _repairCorruptedTimestamps(DatabaseIntegrityReport report) async {
    Logger.debug('Checking for corrupted timestamp fields...');
    final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Map of table names to their date columns that need checking
    final tableColumns = {
      'sync_device_table': ['created_date', 'modified_date', 'deleted_date', 'last_sync_date'],
      'tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'task_tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'habit_tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'app_usage_tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'note_tag_table': ['created_date', 'modified_date', 'deleted_date'],
      'tag_tag_table': ['created_date', 'modified_date', 'deleted_date'],
    };

    for (final entry in tableColumns.entries) {
      final table = entry.key;
      final columns = entry.value;

      for (final column in columns) {
        try {
          // Check if any rows have text data in this column
          final hasTextData = await _database.customSelect('''
            SELECT COUNT(*) as count 
            FROM $table 
            WHERE typeof($column) = 'text'
          ''').getSingleOrNull();

          if (hasTextData != null) {
            final count = hasTextData.data['count'] as int? ?? 0;
            if (count > 0) {
              Logger.warning('Found $count rows in $table.$column with corrupted text timestamp. Repairing...');

              // Repair: Try to parse string date using SQLite's strftime to preserve the date if possible
              await _database.customStatement('''
                UPDATE $table
                SET $column = CAST(strftime('%s', $column) AS INTEGER)
                WHERE typeof($column) = 'text'
              ''');

              // Cleanup: If parsing failed (result is null) or somehow still text, reset to now
              await _database.customStatement('''
                UPDATE $table
                SET $column = ?
                WHERE typeof($column) = 'text' OR $column IS NULL
              ''', [nowTimestamp]);

              Logger.info('Repaired $table.$column timestamps');
            }
          }
        } catch (e, stackTrace) {
          // Table or column might not exist, log but continue
          final key = '$table.$column';
          Logger.error('Failed to repair timestamps for $key: $e', stackTrace: stackTrace);
          report.repairFailures[key] = 'Timestamp repair failed: $e';
        }
      }
    }
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

  Future<void> _checkSyncStateConsistency(DatabaseIntegrityReport report) async {
    Logger.debug('Checking sync state consistency...');

    try {
      // Check for sync devices with invalid IP addresses
      final invalidSyncDevices = await _database.customSelect('''
        SELECT COUNT(*) as count
        FROM sync_device_table
        WHERE deleted_date IS NULL
        AND (from_ip IS NULL OR from_ip = '' OR to_ip IS NULL OR to_ip = '')
      ''').getSingleOrNull();

      if (invalidSyncDevices != null) {
        final count = invalidSyncDevices.data['count'] as int? ?? 0;
        if (count > 0) {
          report.syncStateIssues['invalid_device_ips'] = count;
          Logger.warning('Found $count sync devices with invalid IP addresses');
        }
      }

      // Check for duplicate sync devices (same device pair)
      final duplicateSyncDevices = await _database.customSelect('''
        SELECT from_device_id, to_device_id, COUNT(*) as count
        FROM sync_device_table
        WHERE deleted_date IS NULL
        GROUP BY from_device_id, to_device_id
        HAVING COUNT(*) > 1
      ''').get();

      if (duplicateSyncDevices.isNotEmpty) {
        report.syncStateIssues['duplicate_sync_devices'] = duplicateSyncDevices.length;
        Logger.warning('Found ${duplicateSyncDevices.length} duplicate sync device pairs');
      }

      // Check for sync devices with extremely old creation dates (possible corruption)
      // Changed from 1 year to 5 years to be less aggressive with cleanup
      final oldSyncDevices = await _database.customSelect('''
        SELECT COUNT(*) as count, MIN(created_date) as oldest_date, MAX(created_date) as newest_date
        FROM sync_device_table
        WHERE deleted_date IS NULL
      ''').getSingleOrNull();

      if (oldSyncDevices != null) {
        final totalCount = oldSyncDevices.data['count'] as int? ?? 0;
        final oldestDate = oldSyncDevices.data['oldest_date']?.toString();
        final newestDate = oldSyncDevices.data['newest_date']?.toString();

        Logger.debug('Sync device date analysis: count=$totalCount, oldest=$oldestDate, newest=$newestDate');

        // Check for devices older than 5 years
        // We calculate the cutoff timestamp in seconds (Drift default) to avoid String vs Int comparison issues
        final cutoffDate = DateTime.now().subtract(const Duration(days: 365 * 5));
        final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch ~/ 1000;

        // First, get accurate count using integer comparison
        final ancientDeviceCount = await _database.customSelect('''
          SELECT COUNT(*) as count
          FROM sync_device_table
          WHERE deleted_date IS NULL
          AND created_date < ?
        ''', variables: [Variable.withInt(cutoffTimestamp)]).getSingleOrNull();

        // Then, get sample records for debugging
        final ancientDeviceSamples = await _database.customSelect('''
          SELECT id, created_date
          FROM sync_device_table
          WHERE deleted_date IS NULL
          AND created_date < ?
          LIMIT 3
        ''', variables: [Variable.withInt(cutoffTimestamp)]).get();

        if (ancientDeviceCount != null) {
          final count = ancientDeviceCount.data['count'] as int? ?? 0;
          if (count > 0) {
            report.syncStateIssues['ancient_sync_devices'] = count;
            Logger.warning('Found $count sync devices older than 5 years (possible corruption):');

            // Log sample devices for debugging
            for (final device in ancientDeviceSamples) {
              final deviceId = device.data['id']?.toString();
              final createdDate = device.data['created_date']?.toString();
              Logger.warning('- Device ID: $deviceId, Created: $createdDate');
            }
          }
        }
      }

      // Check for sync devices with invalid device IDs (empty or null)
      final invalidDeviceIds = await _database.customSelect('''
        SELECT COUNT(*) as count
        FROM sync_device_table
        WHERE deleted_date IS NULL
        AND (from_device_id IS NULL OR from_device_id = '' OR to_device_id IS NULL OR to_device_id = '')
      ''').getSingleOrNull();

      if (invalidDeviceIds != null) {
        final count = invalidDeviceIds.data['count'] as int? ?? 0;
        if (count > 0) {
          report.syncStateIssues['invalid_device_ids'] = count;
          Logger.warning('Found $count sync devices with invalid device IDs');
        }
      }

      Logger.debug('Sync state consistency check completed');
    } catch (e, stackTrace) {
      Logger.warning('Error during sync state consistency check: $e', stackTrace: stackTrace);
      // Don't let sync state check failures prevent other integrity checks
    }
  }

  Future<void> _fixDuplicateIds(DatabaseIntegrityReport report) async {
    final tables = [
      'tag_table',
      'task_tag_table',
      'habit_tag_table',
      'app_usage_tag_table',
      'note_tag_table',
      'tag_tag_table',
    ];

    final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    for (final tableName in tables) {
      try {
        Logger.info('Fixing duplicates in $tableName...');

        // Keep the most recent record for each ID, soft-delete the rest
        await _database.customStatement('''
          UPDATE $tableName
          SET deleted_date = ?
          WHERE rowid NOT IN (
            SELECT MAX(rowid)
            FROM $tableName
            WHERE deleted_date IS NULL
            GROUP BY id
          ) AND deleted_date IS NULL
        ''', [nowTimestamp]);
      } catch (e, stackTrace) {
        Logger.error('Failed to fix duplicates in $tableName: $e', stackTrace: stackTrace);
        report.repairFailures['$tableName.duplicates'] = 'Duplicate fix failed: $e';
      }
    }
  }

  Future<void> _cleanupOrphanedReferences(DatabaseIntegrityReport report) async {
    Logger.info('Cleaning up orphaned references...');

    final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      // Soft-delete task_tags that reference deleted tags
      await _database.customStatement('''
        UPDATE task_tag_table
        SET deleted_date = ?
        WHERE tag_id NOT IN (
          SELECT id FROM tag_table WHERE deleted_date IS NULL
        ) AND deleted_date IS NULL
      ''', [nowTimestamp]);
    } catch (e, stackTrace) {
      Logger.error('Failed to cleanup orphaned task tags: $e', stackTrace: stackTrace);
      report.repairFailures['task_tags.orphans'] = 'Orphan cleanup failed: $e';
    }

    try {
      // Soft-delete habit_tags that reference deleted tags
      await _database.customStatement('''
        UPDATE habit_tag_table
        SET deleted_date = ?
        WHERE tag_id NOT IN (
          SELECT id FROM tag_table WHERE deleted_date IS NULL
        ) AND deleted_date IS NULL
      ''', [nowTimestamp]);
    } catch (e, stackTrace) {
      Logger.error('Failed to cleanup orphaned habit tags: $e', stackTrace: stackTrace);
      report.repairFailures['habit_tags.orphans'] = 'Orphan cleanup failed: $e';
    }
  }

  Future<void> _fixSyncStateIssues(DatabaseIntegrityReport report) async {
    Logger.info('Fixing sync state issues...');

    try {
      // Fix sync devices with invalid IP addresses by setting them to localhost
      await _database.customStatement('''
        UPDATE sync_device_table
        SET from_ip = CASE
          WHEN from_ip IS NULL OR from_ip = '' THEN '127.0.0.1'
          ELSE from_ip
        END,
        to_ip = CASE
          WHEN to_ip IS NULL OR to_ip = '' THEN '127.0.0.1'
          ELSE to_ip
        END
        WHERE deleted_date IS NULL
        AND (from_ip IS NULL OR from_ip = '' OR to_ip IS NULL OR to_ip = '')
      ''');
      Logger.debug('Fixed invalid IP addresses in sync devices');
    } catch (e, stackTrace) {
      Logger.error('Failed to fix invalid IP addresses: $e', stackTrace: stackTrace);
      report.repairFailures['sync_device.invalid_ips'] = 'IP fix failed: $e';
    }

    final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    try {
      // Soft-delete duplicate sync devices, keeping the most recent one
      await _database.customStatement('''
        UPDATE sync_device_table
        SET deleted_date = ?
        WHERE rowid NOT IN (
          SELECT MAX(rowid)
          FROM sync_device_table
          WHERE deleted_date IS NULL
          GROUP BY from_device_id, to_device_id
        ) AND deleted_date IS NULL
      ''', [nowTimestamp]);
      Logger.debug('Soft-deleted duplicate sync device records');
    } catch (e, stackTrace) {
      Logger.error('Failed to fix duplicate sync devices: $e', stackTrace: stackTrace);
      report.repairFailures['sync_device.duplicates'] = 'Duplicate device fix failed: $e';
    }

    try {
      // Fix sync devices with invalid device IDs by setting them to default values
      await _database.customStatement('''
        UPDATE sync_device_table
        SET from_device_id = CASE
          WHEN from_device_id IS NULL OR from_device_id = '' THEN 'unknown_device'
          ELSE from_device_id
        END,
        to_device_id = CASE
          WHEN to_device_id IS NULL OR to_device_id = '' THEN 'unknown_device'
          ELSE to_device_id
        END
        WHERE deleted_date IS NULL
        AND (from_device_id IS NULL OR from_device_id = '' OR to_device_id IS NULL OR to_device_id = '')
      ''');
      Logger.debug('Fixed invalid device IDs in sync devices');
    } catch (e, stackTrace) {
      Logger.error('Failed to fix invalid device IDs: $e', stackTrace: stackTrace);
      report.repairFailures['sync_device.invalid_ids'] = 'Device ID fix failed: $e';
    }

    final cutoffDate = DateTime.now().subtract(const Duration(days: 365 * 5));
    final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch ~/ 1000;

    try {
      // Soft-delete extremely old sync devices (older than 5 years)
      await _database.customStatement('''
        UPDATE sync_device_table
        SET deleted_date = ?
        WHERE deleted_date IS NULL
        AND created_date < ?
      ''', [nowTimestamp, cutoffTimestamp]);
      Logger.debug('Soft-deleted ancient sync device records (older than 5 years)');
    } catch (e, stackTrace) {
      Logger.error('Failed to cleanup ancient sync devices: $e', stackTrace: stackTrace);
      report.repairFailures['sync_device.ancient'] = 'Ancient device cleanup failed: $e';
    }

    Logger.info('Sync state issues fixed');
  }
}

class DatabaseIntegrityReport {
  final Map<String, int> duplicateIds = {};
  final Map<String, int> orphanedReferences = {};
  final Map<String, int> syncStateIssues = {};
  final Map<String, String> repairFailures = {};
  int softDeleteInconsistencies = 0;
  int timestampInconsistencies = 0;

  bool get hasIssues =>
      duplicateIds.isNotEmpty ||
      orphanedReferences.isNotEmpty ||
      syncStateIssues.isNotEmpty ||
      repairFailures.isNotEmpty ||
      softDeleteInconsistencies > 0 ||
      timestampInconsistencies > 0;

  @override
  String toString() {
    if (!hasIssues) return 'Database integrity: No issues found';

    final buffer = StringBuffer('Database integrity issues found:\n');

    if (timestampInconsistencies > 0) {
      buffer.writeln('Timestamp inconsistencies: $timestampInconsistencies corrupted date fields');
    }

    if (duplicateIds.isNotEmpty) {
      buffer.writeln('Duplicate IDs:');
      duplicateIds.forEach((table, count) {
        buffer.writeln('  - $table: $count duplicates');
      });
    }

    if (orphanedReferences.isNotEmpty) {
      buffer.writeln('Orphaned references:');
      orphanedReferences.forEach((type, count) {
        buffer.writeln('  - $type: $count orphaned');
      });
    }

    if (softDeleteInconsistencies > 0) {
      buffer.writeln('Soft-delete inconsistencies: $softDeleteInconsistencies');
    }

    if (syncStateIssues.isNotEmpty) {
      buffer.writeln('Sync state issues:');
      syncStateIssues.forEach((type, count) {
        buffer.writeln('  - $type: $count issues');
      });
    }

    if (repairFailures.isNotEmpty) {
      buffer.writeln('Repair failures:');
      repairFailures.forEach((operation, error) {
        buffer.writeln('  - $operation: $error');
      });
    }

    return buffer.toString();
  }
}
