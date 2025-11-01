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
    await _checkSyncStateConsistency(report);

    return report;
  }

  /// Automatically fix common integrity issues
  Future<void> fixIntegrityIssues() async {
    Logger.info('🔧 Starting database integrity fixes...');

    await _fixDuplicateIds();
    await _cleanupOrphanedReferences();
    await _fixSyncStateIssues();

    Logger.info('✅ Database integrity fixes completed');
  }

  /// Fix only critical integrity issues (not ancient devices)
  Future<void> fixCriticalIntegrityIssues() async {
    Logger.info('🔧 Starting critical database integrity fixes...');

    await _fixDuplicateIds();
    await _cleanupOrphanedReferences();
    // Skip _fixSyncStateIssues() as it includes ancient device cleanup

    Logger.info('✅ Critical database integrity fixes completed');
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
    Logger.debug('🔍 Checking sync state consistency...');

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
        final oldestDate = oldSyncDevices.data['oldest_date'] as String?;
        final newestDate = oldSyncDevices.data['newest_date'] as String?;

        Logger.debug('📅 Sync device date analysis: count=$totalCount, oldest=$oldestDate, newest=$newestDate');

        // Check for devices older than 5 years
        // First, get accurate count
        final ancientDeviceCount = await _database.customSelect('''
          SELECT COUNT(*) as count
          FROM sync_device_table
          WHERE deleted_date IS NULL
          AND created_date < datetime('now', '-5 years')
        ''').getSingleOrNull();

        // Then, get sample records for debugging
        final ancientDeviceSamples = await _database.customSelect('''
          SELECT id, created_date
          FROM sync_device_table
          WHERE deleted_date IS NULL
          AND created_date < datetime('now', '-5 years')
          LIMIT 3
        ''').get();

        if (ancientDeviceCount != null) {
          final count = ancientDeviceCount.data['count'] as int? ?? 0;
          if (count > 0) {
            report.syncStateIssues['ancient_sync_devices'] = count;
            Logger.warning('Found $count sync devices older than 5 years (possible corruption):');

            // Log sample devices for debugging
            for (final device in ancientDeviceSamples) {
              final deviceId = device.data['id'] as String?;
              final createdDate = device.data['created_date'] as String?;
              Logger.warning('  - Device ID: $deviceId, Created: $createdDate');
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

      Logger.debug('✅ Sync state consistency check completed');
    } catch (e) {
      Logger.warning('⚠️ Error during sync state consistency check: $e');
      // Don't let sync state check failures prevent other integrity checks
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

  Future<void> _fixSyncStateIssues() async {
    Logger.info('🔧 Fixing sync state issues...');

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
      Logger.debug('🔧 Fixed invalid IP addresses in sync devices');

      // Soft-delete duplicate sync devices, keeping the most recent one
      await _database.customStatement('''
        UPDATE sync_device_table
        SET deleted_date = CURRENT_TIMESTAMP
        WHERE rowid NOT IN (
          SELECT MAX(rowid)
          FROM sync_device_table
          WHERE deleted_date IS NULL
          GROUP BY from_device_id, to_device_id
        ) AND deleted_date IS NULL
      ''');
      Logger.debug('🔧 Soft-deleted duplicate sync device records');

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
      Logger.debug('🔧 Fixed invalid device IDs in sync devices');

      // Soft-delete extremely old sync devices (older than 5 years)
      await _database.customStatement('''
        UPDATE sync_device_table
        SET deleted_date = CURRENT_TIMESTAMP
        WHERE deleted_date IS NULL
        AND created_date < datetime('now', '-5 years')
      ''');
      Logger.debug('🔧 Soft-deleted ancient sync device records (older than 5 years)');

      Logger.info('✅ Sync state issues fixed');
    } catch (e) {
      Logger.error('❌ Error fixing sync state issues: $e');
      // Don't rethrow - sync state fix failures shouldn't prevent app startup
    }
  }
}

class DatabaseIntegrityReport {
  final Map<String, int> duplicateIds = {};
  final Map<String, int> orphanedReferences = {};
  final Map<String, int> syncStateIssues = {};
  int softDeleteInconsistencies = 0;

  bool get hasIssues =>
      duplicateIds.isNotEmpty ||
      orphanedReferences.isNotEmpty ||
      syncStateIssues.isNotEmpty ||
      softDeleteInconsistencies > 0;

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

    if (syncStateIssues.isNotEmpty) {
      buffer.writeln('🔄 Sync state issues:');
      syncStateIssues.forEach((type, count) {
        buffer.writeln('  - $type: $count issues');
      });
    }

    return buffer.toString();
  }
}
