// dart format width=80
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/shared/utils/sync_identity.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/settings/repositories/drift_settings_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';

final class TestDeviceIds extends Fake implements IDeviceIdService {
  @override
  Future<String> getDeviceId() async => 'local-device';
}

/// T15 acceptance 3-5: deterministic habit records under D5c, settings
/// delete-recreate revival, and random ids while the target exceeds 1.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting();
    await db.customSelect('SELECT 1').getSingle();
  });

  tearDown(() async => db.close());

  test(
      'uncheck -> recheck the same day on a target-1 habit keeps one live record',
      () async {
    await db.customStatement(
        "INSERT INTO habit_table (id, created_date, type, name, description, has_goal, target_frequency, daily_target) "
        "VALUES ('h1', 0, 0, 'H', 'D', 1, 0, 1)");
    final repo = DriftHabitRecordRepository.withDatabase(db);
    final ops = HabitRecordOperationsService(
        habitRecordRepository: repo,
        habitTimeRecordRepository:
            DriftHabitTimeRecordRepository.withDatabase(db),
        deviceIds: TestDeviceIds());
    final day = DateTime.utc(2026, 3, 1, 12);
    final id = syncIdentityId(identityKindHabitRecord,
        ['h1', day.toLocal().toIso8601String().substring(0, 10)]);

    await ops.addHabitRecord(
        'h1', day, HabitRecordStatus.complete, DateTime.now().toUtc(),
        deterministic: true);
    await db.customStatement(
        "UPDATE habit_record_table SET deleted_date = 700 WHERE id = '$id'");
    await ops.addHabitRecord(
        'h1', day, HabitRecordStatus.complete, DateTime.now().toUtc(),
        deterministic: true);

    final rows = await db
        .customSelect(
            "SELECT id, deleted_date FROM habit_record_table WHERE habit_id = 'h1' AND deleted_date IS NULL")
        .get();
    expect(rows.length, 1);
    expect(rows.first.data['id'], id);
    expect(rows.first.data['deleted_date'], isNull);
  });

  test(
      'delete -> recreate a setting key revives one live row with the new value',
      () async {
    final repo = DriftSettingRepository.withDatabase(db);
    final save = SaveSettingCommandHandler(settingRepository: repo);

    await save(SaveSettingCommand(
        key: 'theme', value: 'dark', valueType: SettingValueType.string));
    await db.customStatement(
        "UPDATE setting_table SET deleted_date = 900 WHERE key = 'theme'");
    final revived = await save(SaveSettingCommand(
        key: 'theme', value: 'light', valueType: SettingValueType.string));

    final rows = await db
        .customSelect(
            "SELECT id, value, deleted_date FROM setting_table WHERE key = 'theme'")
        .get();
    expect(rows.length, 1);
    expect(rows.first.data['value'], 'light');
    expect(rows.first.data['deleted_date'], isNull);
    expect(rows.first.data['id'], revived.id);
    expect(revived.id, syncIdentityId(identityKindSetting, ['theme']));
  });

  test('target-3 habit completions keep random, distinct ids (D5c)', () async {
    await db.customStatement(
        "INSERT INTO habit_table (id, created_date, type, name, description, has_goal, target_frequency, daily_target) "
        "VALUES ('h3', 0, 0, 'H3', 'D', 1, 0, 3)");
    final repo = DriftHabitRecordRepository.withDatabase(db);
    final ops = HabitRecordOperationsService(
        habitRecordRepository: repo,
        habitTimeRecordRepository:
            DriftHabitTimeRecordRepository.withDatabase(db),
        deviceIds: TestDeviceIds());
    final day = DateTime.utc(2026, 3, 2, 9);
    for (var i = 0; i < 3; i++) {
      await ops.addHabitRecord(
          'h3', day, HabitRecordStatus.complete, DateTime.now().toUtc(),
          deterministic: false);
    }
    final rows = await db
        .customSelect("SELECT id FROM habit_record_table WHERE habit_id = 'h3'")
        .get();
    expect(rows.length, 3);
    expect(rows.map((r) => r.data['id']).toSet().length, 3);
  });
}
