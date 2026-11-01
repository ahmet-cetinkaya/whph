import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_repository.dart';
import 'package:whph/infrastructure/persistence/features/app_usages/repositories/drift_app_usage_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';

/// Duration sums must use SQLite's `TOTAL()`, not `SUM()`: `SUM()` returns a
/// 64-bit integer and aborts the whole query with `SQLITE_ERROR` once the sum
/// overflows, which crashed app usage reports in production.
void main() {
  group('App Usage Time Record Overflow Tests', () {
    // Half of the max 64-bit signed integer. Two of these overflow `SUM()`
    // while staying clear of float precision loss in `TOTAL()`.
    const int halfMaxInt = 4611686018427387903;

    late AppDatabase database;
    late DriftAppUsageTimeRecordRepository repository;
    late DriftAppUsageRepository appUsageRepository;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      database = AppDatabase.forTesting();
      repository = DriftAppUsageTimeRecordRepository.withDatabase(database);
      appUsageRepository = DriftAppUsageRepository.withDatabase(database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> addOverflowingRecords(String appUsageId, String recordIdPrefix) async {
      await appUsageRepository.add(AppUsage(
        id: appUsageId,
        name: 'overflow-app-$appUsageId',
        createdDate: DateTime.now(),
      ));

      final durations = [halfMaxInt, halfMaxInt, 1000];
      for (var i = 0; i < durations.length; i++) {
        await repository.add(AppUsageTimeRecord(
          id: '$recordIdPrefix-$i',
          appUsageId: appUsageId,
          duration: durations[i],
          usageDate: DateTime.now(),
          createdDate: DateTime.now(),
        ));
      }
    }

    test('getAppUsageDurations survives duration overflow', () async {
      await addOverflowingRecords('app-1', 'record-a');

      final durations = await repository.getAppUsageDurations(appUsageIds: ['app-1']);

      expect(durations['app-1'], greaterThan(halfMaxInt));
    });

    test('getAppUsageDurations reports exact sums for realistic durations', () async {
      await appUsageRepository.add(AppUsage(
        id: 'app-2',
        name: 'realistic-app',
        createdDate: DateTime.now(),
      ));
      for (var i = 0; i < 3; i++) {
        await repository.add(AppUsageTimeRecord(
          id: 'record-b-$i',
          appUsageId: 'app-2',
          duration: 3600,
          usageDate: DateTime.now(),
          createdDate: DateTime.now(),
        ));
      }

      final durations = await repository.getAppUsageDurations(appUsageIds: ['app-2']);

      expect(durations['app-2'], 10800);
    });

    test('getListByTopAppUsages sums device buckets of one hour before clamping', () async {
      for (final id in ['app-3', 'app-4']) {
        await appUsageRepository.add(AppUsage(id: id, name: 'bucket-$id', createdDate: DateTime.now()));
      }
      final hour = DateTime.utc(2026, 1, 1, 10);
      // app-3: one hour with two device buckets whose sum is negative, so the
      // hour clamps to 0. Clamping each row first would rank it at 3600.
      final records = [
        ('record-c-local', 'app-3', 3600),
        ('record-c-remote', 'app-3', -7200),
        ('record-d', 'app-4', 1800),
      ];
      for (final (id, appUsageId, duration) in records) {
        await repository.add(AppUsageTimeRecord(
          id: id,
          appUsageId: appUsageId,
          duration: duration,
          usageDate: hour,
          createdDate: DateTime.now(),
        ));
      }

      final page = await appUsageRepository.getListByTopAppUsages(pageIndex: 0, pageSize: 10);

      expect(page.items.map((item) => item.id).toList(), ['app-4', 'app-3']);
    });
  });
}
