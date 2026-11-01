// Application services over one fleet device's database for the identity-rule
// suites (T27 part 1): the same commands and services the app runs, wired to
// the device's Drift repositories, plus an independent SQL oracle that counts
// items violating an FR-030 identity rule.
import 'package:acore/acore.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_tag_command.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/application/features/sync/services/abstraction/i_device_id_service.dart';
import 'package:whph/core/application/features/tags/commands/add_tag_tag_command.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_tag_command.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/queries/get_list_task_tags_query.dart';
import 'package:whph/core/application/features/tasks/queries/get_task_query.dart';
import 'package:whph/core/application/features/tasks/services/task_recurrence_service.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_records_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_tags_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/settings/repositories/drift_settings_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tags/repositories/drift_tag_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_tag_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

import 'acceptance_fleet.dart';

const String _localDeviceId = 'acceptance-device';

/// FR-030 rules, each with the SQL that counts the identities held by more
/// than one live row.
final Map<String, String> _identityViolationSql = {
  'habit record per habit per day': 'SELECT COUNT(*) FROM (SELECT 1 FROM habit_record_table r '
      'JOIN habit_table h ON h.id = r.habit_id AND h.daily_target = 1 WHERE r.deleted_date IS NULL '
      "GROUP BY r.habit_id, date(r.occurred_at, 'unixepoch') HAVING COUNT(*) > 1)",
  'setting per key': 'SELECT COUNT(*) FROM (SELECT 1 FROM setting_table WHERE deleted_date IS NULL '
      'GROUP BY key HAVING COUNT(*) > 1)',
  'built-in status per kind': 'SELECT COUNT(*) FROM (SELECT 1 FROM task_status_table '
      'WHERE deleted_date IS NULL AND is_built_in = 1 GROUP BY is_done_status HAVING COUNT(*) > 1)',
  'recurring occurrence per date': 'SELECT COUNT(*) FROM (SELECT 1 FROM task_table '
      'WHERE deleted_date IS NULL AND planned_date IS NOT NULL '
      "GROUP BY COALESCE(recurrence_parent_id, id), date(planned_date, 'unixepoch') HAVING COUNT(*) > 1)",
  'task tag link': _linkViolations('task_tag_table', 'task_id', 'tag_id'),
  'habit tag link': _linkViolations('habit_tag_table', 'habit_id', 'tag_id'),
  'note tag link': _linkViolations('note_tag_table', 'note_id', 'tag_id'),
  'app usage tag link': _linkViolations('app_usage_tag_table', 'app_usage_id', 'tag_id'),
  'tag tag link': _linkViolations('tag_tag_table', 'primary_tag_id', 'secondary_tag_id'),
  'paired-device entry per device': 'SELECT COUNT(*) FROM (SELECT 1 FROM sync_member_table '
      'WHERE deleted_date IS NULL GROUP BY member_id HAVING COUNT(*) > 1)',
};

String _linkViolations(String table, String owner, String tag) =>
    'SELECT COUNT(*) FROM (SELECT 1 FROM $table WHERE deleted_date IS NULL GROUP BY $owner, $tag HAVING COUNT(*) > 1)';

/// Per FR-030 rule, how many identities are held by more than one live row in
/// [db]. All zero means no identity rule is violated.
Future<Map<String, int>> identityViolations(AppDatabase db) async {
  final counts = <String, int>{};
  for (final rule in _identityViolationSql.entries) {
    final row = await db.customSelect(rule.value).getSingle();
    counts[rule.key] = row.data.values.first! as int;
  }
  return counts;
}

Future<void> expectNoIdentityViolations(AppDatabase db, {required String device}) async {
  final violations = await identityViolations(db);
  expect(violations.values.where((count) => count != 0), isEmpty, reason: '$device: $violations');
}

class _AcceptanceDeviceIds extends Fake implements IDeviceIdService {
  @override
  Future<String> getDeviceId() async => _localDeviceId;
}

/// Keeps the warnings and errors the services log, so a null result can say why.
class _RecordingLogger implements ILogger {
  final List<String> problems = [];

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace, String? component]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace, String? component]) =>
      problems.add('$message $error');

  @override
  void error(String message, [Object? error, StackTrace? stackTrace, String? component]) =>
      problems.add('$message $error');

  @override
  void fatal(String message, [Object? error, StackTrace? stackTrace, String? component]) =>
      problems.add('$message $error');
}

/// The application's commands and services wired to one device.
class DeviceServices {
  final FleetDevice device;
  final Mediator mediator = Mediator(Pipeline());
  final _RecordingLogger _logger = _RecordingLogger();
  late final HabitRecordOperationsService habitRecords;
  late final TaskRecurrenceService recurrence;

  DeviceServices(this.device) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = device.database.db;
    final deviceIds = _AcceptanceDeviceIds();
    final taskRepository = DriftTaskRepository.withDatabase(db);
    final taskTags = DriftTaskTagRepository.withDatabase(db);
    final tags = DriftTagRepository.withDatabase(db);
    final settings = DriftSettingRepository.withDatabase(db);
    final habitTags = DriftHabitTagRepository.withDatabase(db);
    final tagTags = DriftTagTagRepository.withDatabase(db);
    habitRecords = HabitRecordOperationsService(
      habitRecordRepository: DriftHabitRecordRepository.withDatabase(db),
      habitTimeRecordRepository: DriftHabitTimeRecordRepository.withDatabase(db),
      deviceIds: deviceIds,
    );
    recurrence = TaskRecurrenceService(_logger, taskRepository);
    mediator
      ..registerHandler<GetTaskQuery, GetTaskQueryResponse, GetTaskQueryHandler>(() => GetTaskQueryHandler(
          taskRepository: taskRepository, taskTimeRecordRepository: DriftTaskTimeRecordRepository.withDatabase(db)))
      ..registerHandler<GetListTaskTagsQuery, GetListTaskTagsQueryResponse, GetListTaskTagsQueryHandler>(
          () => GetListTaskTagsQueryHandler(tagRepository: tags, taskTagRepository: taskTags))
      ..registerHandler<SaveTaskCommand, SaveTaskCommandResponse, SaveTaskCommandHandler>(() => SaveTaskCommandHandler(
          taskService: taskRepository,
          taskTagRepository: taskTags,
          taskTimeRecordRepository: DriftTaskTimeRecordRepository.withDatabase(db),
          settingRepository: settings,
          deviceIds: deviceIds))
      ..registerHandler<AddTaskTagCommand, AddTaskTagCommandResponse, AddTaskTagCommandHandler>(
          () => AddTaskTagCommandHandler(taskTagRepository: taskTags))
      ..registerHandler<AddHabitTagCommand, AddHabitTagCommandResponse, AddHabitTagCommandHandler>(
          () => AddHabitTagCommandHandler(habitTagRepository: habitTags))
      ..registerHandler<AddTagTagCommand, AddTagTagCommandResponse, AddTagTagCommandHandler>(
          () => AddTagTagCommandHandler(tagTagRepository: tagTags))
      ..registerHandler<SaveSettingCommand, SaveSettingCommandResponse, SaveSettingCommandHandler>(
          () => SaveSettingCommandHandler(settingRepository: settings));
  }

  Future<void> insertHabit(String id, {int dailyTarget = 1}) => device.sql(
      "INSERT INTO habit_table (id, created_date, type, name, description, has_goal, target_frequency, daily_target) "
      "VALUES ('$id', 0, 0, 'habit $id', 'd', 1, 0, $dailyTarget)");

  Future<void> insertTag(String id) => device.sql(
      "INSERT INTO tag_table (id, created_date, name, color, is_archived, type) VALUES ('$id', 1, 'tag $id', 'ff0000', 0, 0)");

  Future<void> insertBuiltInTodoStatus() =>
      device.sql('INSERT INTO task_status_table (id, created_date, name, color, "order", is_built_in, is_done_status) '
          "VALUES ('task-status-builtin-todo', 1, '', '9E9E9E', 'U', 1, 0)");

  /// The user marks [habitId] for the calendar day of [day] with [status].
  Future<void> recordHabit(String habitId, DateTime day, HabitRecordStatus status) =>
      habitRecords.addHabitRecord(habitId, day, status, DateTime.now().toUtc(), deterministic: true);

  Future<void> saveSetting(String key, String value) async {
    await mediator.send<SaveSettingCommand, SaveSettingCommandResponse>(
        SaveSettingCommand(key: key, value: value, valueType: SettingValueType.string));
  }

  Future<void> tagTask(String taskId, String tagId) async {
    await mediator.send<AddTaskTagCommand, AddTaskTagCommandResponse>(AddTaskTagCommand(taskId: taskId, tagId: tagId));
  }

  Future<void> tagHabit(String habitId, String tagId) async {
    await mediator
        .send<AddHabitTagCommand, AddHabitTagCommandResponse>(AddHabitTagCommand(habitId: habitId, tagId: tagId));
  }

  Future<void> linkTags(String primaryTagId, String secondaryTagId) async {
    await mediator.send<AddTagTagCommand, AddTagTagCommandResponse>(
        AddTagTagCommand(primaryTagId: primaryTagId, secondaryTagId: secondaryTagId));
  }

  /// The user completes the recurring task [taskId]; the app then creates the
  /// next occurrence. Returns the occurrence id.
  Future<String> completeRecurringTask(String taskId, int completedAtSeconds) async {
    await device.sql('UPDATE task_table SET completed_at = $completedAtSeconds WHERE id = \'$taskId\'');
    final occurrenceId = await recurrence.handleCompletedRecurringTask(taskId, mediator);
    if (occurrenceId == null) fail('no occurrence created for $taskId: ${_logger.problems}');
    return occurrenceId;
  }
}
