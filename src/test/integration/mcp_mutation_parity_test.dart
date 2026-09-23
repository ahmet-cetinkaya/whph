import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:acore/acore.dart' show WeekDays;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/notes/commands/save_note_command.dart';
import 'package:whph/core/application/features/notes/services/abstraction/i_note_events.dart';
import 'package:whph/core/application/features/habits/commands/add_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_time_record_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_events.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tasks/commands/complete_task_command.dart';
import 'package:whph/core/application/features/tasks/commands/add_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_time_record_command.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_events.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_recurrence_service.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_tag_repository.dart';
import 'package:whph/core/application/features/settings/services/abstraction/i_setting_repository.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/tasks/task_tag.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habit_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/habits/repositories/drift_habits_repository.dart';
import 'package:whph/infrastructure/persistence/features/notes/repositories/drift_note_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/drift_task_time_record_repository.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/drift_task_repository.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';

class RecordingNoteEvents implements INoteEvents {
  final List<String> created = [];
  final List<String> updated = [];
  final List<String> deleted = [];

  @override
  void notifyNoteCreated(String noteId) => created.add(noteId);

  @override
  void notifyNoteDeleted(String noteId) => deleted.add(noteId);

  @override
  void notifyNoteUpdated(String noteId) => updated.add(noteId);
}

class RecordingTaskEvents implements ITaskEvents {
  final List<String> created = [];
  final List<String> completed = [];
  final List<String> timeUpdated = [];

  @override
  void notifyTaskCreated(String taskId) => created.add(taskId);
  @override
  void notifyTaskCompleted(String taskId) => completed.add(taskId);
  @override
  void notifyTaskDeleted(String taskId) {}
  @override
  void notifyTaskTimeRecordUpdated(String taskId) => timeUpdated.add(taskId);
  @override
  void notifyTaskUpdated(String taskId) {}
}

class RecordingHabitEvents implements IHabitEvents {
  final List<String> updated = [];

  @override
  void notifyHabitCreated(String habitId) {}
  @override
  void notifyHabitDeleted(String habitId) {}
  @override
  void notifyHabitRecordAdded(String habitId) {}
  @override
  void notifyHabitRecordRemoved(String habitId) {}
  @override
  void notifyHabitUpdated(String habitId) => updated.add(habitId);
}

class FailingTaskTimeRecordRepository extends DriftTaskTimeRecordRepository {
  FailingTaskTimeRecordRepository(super.database) : super.withDatabase();

  @override
  Future<void> add(TaskTimeRecord item) => Future.error(StateError('task time write failed'));
}

class FailingHabitTimeRecordRepository extends DriftHabitTimeRecordRepository {
  FailingHabitTimeRecordRepository(super.database) : super.withDatabase();

  @override
  Future<void> add(HabitTimeRecord item) => Future.error(StateError('habit time write failed'));
}

class FailingTaskTagRepository extends Fake implements ITaskTagRepository {
  @override
  Future<void> add(TaskTag item) => Future.error(StateError('tag write failed'));
}

class EmptySettingRepository extends Fake implements ISettingRepository {
  @override
  Future<Setting?> getByKey(String key) async => null;
}

class AwaitingRecurrenceService extends Fake implements ITaskRecurrenceService {
  int calls = 0;

  @override
  List<WeekDays>? getRecurrenceDays(Task task) => const [WeekDays.monday];

  @override
  Future<String?> handleCompletedRecurringTask(String taskId, Mediator mediator) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return 'next-task';
  }
}

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late DriftNoteRepository repository;
  late RecordingNoteEvents events;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    AppDatabase.isTestMode = true;
    tempDirectory = await Directory.systemTemp.createTemp('whph-mcp-mutation-');
    database = AppDatabase(NativeDatabase(File('${tempDirectory.path}/notes.sqlite')));
    repository = DriftNoteRepository.withDatabase(database);
    events = RecordingNoteEvents();
  });

  tearDown(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  test('direct note commands preserve omitted fields and emit after committed writes', () async {
    final handler = SaveNoteCommandHandler(noteRepository: repository, noteEvents: events);
    final created = await handler.call(SaveNoteCommand(title: 'Original', content: 'Body'));

    expect(events.created, [created.id]);

    final updateHandler = UpdateNoteCommandHandler(noteRepository: repository, noteEvents: events);
    final updated = await updateHandler.call(UpdateNoteCommand(
      id: created.id,
      expectedRevision: created.revision,
      title: 'Renamed',
    ));
    final persisted = await repository.getById(created.id);

    expect(persisted?.title, 'Renamed');
    expect(persisted?.content, 'Body');
    expect(events.updated, [created.id]);
    expect(updated.revision, isNot(created.revision));
  });

  test('stale note revision changes no data and emits no event', () async {
    final handler = SaveNoteCommandHandler(noteRepository: repository, noteEvents: events);
    final created = await handler.call(SaveNoteCommand(title: 'Original', content: 'Body'));
    final updateHandler = UpdateNoteCommandHandler(noteRepository: repository, noteEvents: events);
    final current = await updateHandler.call(UpdateNoteCommand(
      id: created.id,
      expectedRevision: created.revision,
      content: const NoteContentUpdate.set('Fresh body'),
    ));
    final afterCurrentUpdate = await repository.getById(created.id);
    expect(current.revision, isNot(created.revision));
    expect(afterCurrentUpdate?.modifiedDate?.isAtSameMomentAs(current.revision), isTrue);

    await expectLater(
      updateHandler.call(UpdateNoteCommand(
        id: created.id,
        expectedRevision: created.revision,
        title: 'Stale title',
      )),
      throwsA(isA<NoteRevisionConflictException>()),
    );

    final persisted = await repository.getById(created.id);
    expect(persisted?.title, 'Original');
    expect(persisted?.content, 'Fresh body');
    expect(persisted?.modifiedDate?.isAtSameMomentAs(current.revision), isTrue);
    expect(events.updated, [created.id]);
  });

  test('multi-write failure exposes persisted prefix but publishes no success event', () async {
    final taskRepository = DriftTaskRepository.withDatabase(database);
    final taskEvents = RecordingTaskEvents();
    final handler = SaveTaskCommandHandler(
      taskService: taskRepository,
      taskTagRepository: FailingTaskTagRepository(),
      taskTimeRecordRepository: DriftTaskTimeRecordRepository.withDatabase(database),
      settingRepository: EmptySettingRepository(),
      taskEvents: taskEvents,
    );

    await expectLater(
      handler.call(SaveTaskCommand(title: 'Partially persisted', tagIdsToAdd: ['tag-id'])),
      throwsA(isA<StateError>()),
    );

    final persisted = await taskRepository.getList(0, 20);
    expect(persisted.items.map((task) => task.title), contains('Partially persisted'));
    expect(taskEvents.created, isEmpty);
  });

  test('task completion awaits recurrence and repeated completion is idempotent', () async {
    final taskRepository = DriftTaskRepository.withDatabase(database);
    final timeRepository = DriftTaskTimeRecordRepository.withDatabase(database);
    final taskEvents = RecordingTaskEvents();
    final recurrence = AwaitingRecurrenceService();
    await taskRepository.add(Task(
      id: 'recurring-task',
      createdDate: DateTime.now().toUtc(),
      title: 'Recurring',
      recurrenceType: RecurrenceType.weekly,
    ));
    final handler = CompleteTaskCommandHandler(
      taskRepository,
      timeRepository,
      recurrence,
      Mediator(Pipeline()),
      taskEvents,
    );

    final first = await handler.call(CompleteTaskCommand(id: 'recurring-task'));
    final second = await handler.call(CompleteTaskCommand(id: 'recurring-task'));
    final persisted = await taskRepository.getById('recurring-task');

    expect(first.recurringTaskId, 'next-task');
    expect(second.recurringTaskId, isNull);
    expect(recurrence.calls, 1);
    expect(taskEvents.completed, ['recurring-task']);
    expect(persisted?.isCompleted, isTrue);
  });

  test('direct task time logging emits once after real persistence and never after a failed write', () async {
    final taskEvents = RecordingTaskEvents();
    final repository = DriftTaskTimeRecordRepository.withDatabase(database);
    final handler = AddTaskTimeRecordCommandHandler(
      taskTimeRecordRepository: repository,
      taskEvents: taskEvents,
    );

    await handler.call(AddTaskTimeRecordCommand(
      taskId: 'task-time',
      duration: 90,
      customDateTime: DateTime.utc(2026, 1, 12, 10),
    ));

    expect(await repository.getTotalDurationByTaskId('task-time'), 90);
    expect(taskEvents.timeUpdated, ['task-time']);

    await SaveTaskTimeRecordCommandHandler(
      taskTimeRecordRepository: repository,
      taskEvents: taskEvents,
    ).call(SaveTaskTimeRecordCommand(
      taskId: 'task-time-total',
      duration: 45,
      targetDate: DateTime.utc(2026, 1, 12, 10),
    ));
    expect(await repository.getTotalDurationByTaskId('task-time-total'), 45);
    expect(taskEvents.timeUpdated, ['task-time', 'task-time-total']);

    final failingEvents = RecordingTaskEvents();
    final failingHandler = AddTaskTimeRecordCommandHandler(
      taskTimeRecordRepository: FailingTaskTimeRecordRepository(database),
      taskEvents: failingEvents,
    );
    await expectLater(
      failingHandler.call(AddTaskTimeRecordCommand(taskId: 'failed-task-time', duration: 30)),
      throwsA(isA<StateError>()),
    );
    expect(failingEvents.timeUpdated, isEmpty);
  });

  test('direct habit time logging emits once after real persistence and never after a failed write', () async {
    final habitRepository = DriftHabitRepository.withDatabase(database);
    await habitRepository.add(Habit(
      id: 'habit-time',
      createdDate: DateTime.utc(2026, 1, 1),
      name: 'Timed habit',
      description: '',
    ));
    final habitEvents = RecordingHabitEvents();
    final repository = DriftHabitTimeRecordRepository.withDatabase(database);
    final handler = AddHabitTimeRecordCommandHandler(
      habitTimeRecordRepository: repository,
      habitEvents: habitEvents,
    );

    await handler.call(AddHabitTimeRecordCommand(
      habitId: 'habit-time',
      duration: 120,
      customDateTime: DateTime.utc(2026, 1, 12, 10),
    ));

    expect(await repository.getTotalDurationByHabitId('habit-time'), 120);
    expect(habitEvents.updated, ['habit-time']);

    await SaveHabitTimeRecordCommandHandler(
      habitTimeRecordRepository: repository,
      habitEvents: habitEvents,
    ).call(SaveHabitTimeRecordCommand(
      habitId: 'habit-time',
      totalDuration: 60,
      targetDate: DateTime.utc(2026, 1, 12, 10),
    ));
    expect(await repository.getTotalDurationByHabitId('habit-time'), 60);
    expect(habitEvents.updated, ['habit-time', 'habit-time']);

    final failingEvents = RecordingHabitEvents();
    final failingHandler = AddHabitTimeRecordCommandHandler(
      habitTimeRecordRepository: FailingHabitTimeRecordRepository(database),
      habitEvents: failingEvents,
    );
    await expectLater(
      failingHandler.call(AddHabitTimeRecordCommand(habitId: 'habit-time', duration: 30)),
      throwsA(isA<StateError>()),
    );
    expect(failingEvents.updated, isEmpty);
  });
}
