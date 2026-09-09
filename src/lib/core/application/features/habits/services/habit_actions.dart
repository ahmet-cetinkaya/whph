import 'package:acore/acore.dart';
import 'package:whph/core/application/features/habits/services/habit_day_state_resolver.dart';
import 'package:whph/core/application/features/habits/services/habit_record_operations_service.dart';
import 'package:whph/core/application/features/habits/services/habit_time_record_service.dart';
import 'package:whph/core/application/features/habits/services/i_habit_events.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_time_record_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';
import 'package:whph/core/application/shared/services/sibling_reorder_service.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_tag.dart';
import 'package:whph/core/domain/features/habits/habit_time_record.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';

final class HabitNotFoundException implements Exception {
  const HabitNotFoundException(this.id);
  final String id;
}

final class HabitRevisionConflictException implements Exception {
  const HabitRevisionConflictException(this.id);
  final String id;
}

final class HabitRecordNotFoundException implements Exception {
  const HabitRecordNotFoundException(this.id);
  final String id;
}

final class HabitTimeRecordNotFoundException implements Exception {
  const HabitTimeRecordNotFoundException(this.habitId);
  final String habitId;
}

final class HabitTagNotFoundException implements Exception {
  const HabitTagNotFoundException(this.id);
  final String id;
}

typedef HabitBeforeCommit = Future<void> Function();
typedef HabitRecordBeforeCommit = Future<void> Function(
    bool requiresTimerWrite);

final class HabitValues {
  const HabitValues({
    required this.name,
    required this.description,
    required this.type,
    required this.estimatedTime,
    required this.hasReminder,
    required this.reminderTime,
    required this.reminderDays,
    required this.hasGoal,
    required this.targetFrequency,
    required this.periodDays,
    required this.dailyTarget,
    required this.archivedDate,
    required this.order,
  });

  final String name;
  final String description;
  final HabitType type;
  final int? estimatedTime;
  final bool hasReminder;
  final String? reminderTime;
  final List<int> reminderDays;
  final bool hasGoal;
  final int targetFrequency;
  final int periodDays;
  final int? dailyTarget;
  final DateTime? archivedDate;
  final String order;

  factory HabitValues.fromHabit(Habit habit) => HabitValues(
        name: habit.name,
        description: habit.description,
        type: habit.type,
        estimatedTime: habit.estimatedTime,
        hasReminder: habit.hasReminder,
        reminderTime: habit.reminderTime,
        reminderDays: _storedReminderDays(habit),
        hasGoal: habit.hasGoal,
        targetFrequency: habit.targetFrequency,
        periodDays: habit.periodDays,
        dailyTarget: habit.dailyTarget,
        archivedDate: habit.archivedDate,
        order: habit.order,
      );
}

final class HabitActionResult {
  const HabitActionResult({required this.id, required this.revision});
  final String id;
  final DateTime revision;
}

final class HabitRecordSetResult {
  const HabitRecordSetResult({required this.status, required this.count});
  final HabitRecordStatus status;
  final int count;
}

final class HabitUndoResult {
  const HabitUndoResult(this.remainingCount);
  final int remainingCount;
}

final class HabitActions {
  HabitActions({
    required IApplicationTransactionService transactions,
    required IHabitRepository habitRepository,
    required IHabitRecordRepository habitRecordRepository,
    required IHabitTagsRepository habitTagsRepository,
    required IHabitTimeRecordRepository habitTimeRecordRepository,
    required ITagRepository tagRepository,
    required IHabitEvents habitEvents,
  })  : _transactions = transactions,
        _habitRepository = habitRepository,
        _habitRecordRepository = habitRecordRepository,
        _habitTagsRepository = habitTagsRepository,
        _habitTimeRecordRepository = habitTimeRecordRepository,
        _tagRepository = tagRepository,
        _habitEvents = habitEvents,
        _recordOperations = HabitRecordOperationsService(
          habitRecordRepository: habitRecordRepository,
          habitTimeRecordRepository: habitTimeRecordRepository,
        );

  final IApplicationTransactionService _transactions;
  final IHabitRepository _habitRepository;
  final IHabitRecordRepository _habitRecordRepository;
  final IHabitTagsRepository _habitTagsRepository;
  final IHabitTimeRecordRepository _habitTimeRecordRepository;
  final ITagRepository _tagRepository;
  final IHabitEvents _habitEvents;
  final HabitRecordOperationsService _recordOperations;

  Future<HabitActionResult> create(HabitValues values, List<String> tagIds,
      HabitBeforeCommit beforeCommit) async {
    final result = await _transactions.run(() async {
      await _validateTags(tagIds);
      final last = await _habitRepository.getList(
        0,
        1,
        customWhereFilter: CustomWhereFilter('deleted_date IS NULL', const []),
        customOrder: [
          CustomOrder(field: 'order', direction: SortDirection.desc)
        ],
      );
      final order = OrderRank.neighborRank(
        beforeOrder: last.items.firstOrNull?.order,
        afterOrder: null,
      );
      final habit = _newHabit(values, order);
      await beforeCommit();
      await _habitRepository.add(habit);
      await _replaceTags(habit.id, const [], tagIds, const {});
      final persisted = await _getHabit(habit.id);
      return HabitActionResult(id: habit.id, revision: _revision(persisted));
    });
    _habitEvents.notifyHabitCreated(result.id);
    return result;
  }

  Future<HabitActionResult> update({
    required String id,
    required DateTime expectedRevision,
    required HabitValues Function(HabitValues current) updateValues,
    List<String>? tagIds,
    Map<String, int>? tagOrder,
    required HabitBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      final current = await _getHabit(id);
      _checkRevision(current, expectedRevision);
      final existingTags = await _habitTagsRepository.getByHabitId(id);
      final replacementIds = tagIds ??
          existingTags.map((tag) => tag.tagId).toList(growable: false);
      await _validateTags(replacementIds);
      final updated =
          _copyHabit(current, updateValues(HabitValues.fromHabit(current)));
      await beforeCommit();
      final revision =
          await _habitRepository.updateIfRevision(updated, expectedRevision);
      if (revision == null) throw HabitRevisionConflictException(id);
      await _replaceTags(
          id, existingTags, replacementIds, tagOrder ?? const {});
      return HabitActionResult(id: id, revision: revision);
    });
    _habitEvents.notifyHabitUpdated(id);
    return result;
  }

  Future<HabitActionResult> archive(String id, DateTime expectedRevision,
          bool isArchived, HabitBeforeCommit beforeCommit) =>
      update(
        id: id,
        expectedRevision: expectedRevision,
        updateValues: (current) => HabitValues(
          name: current.name,
          description: current.description,
          type: current.type,
          estimatedTime: current.estimatedTime,
          hasReminder: current.hasReminder,
          reminderTime: current.reminderTime,
          reminderDays: current.reminderDays,
          hasGoal: current.hasGoal,
          targetFrequency: current.targetFrequency,
          periodDays: current.periodDays,
          dailyTarget: current.dailyTarget,
          archivedDate: isArchived ? DateTime.now().toUtc() : null,
          order: current.order,
        ),
        beforeCommit: beforeCommit,
      );

  Future<DateTime> delete(String id, DateTime expectedRevision,
      HabitBeforeCommit beforeCommit) async {
    final deletedAt = await _transactions.run(() async {
      final habit = await _getHabit(id);
      _checkRevision(habit, expectedRevision);
      await beforeCommit();
      for (final tag in await _habitTagsRepository.getByHabitId(id)) {
        await _habitTagsRepository.delete(tag);
      }
      for (final record in await _habitRecordRepository.getByHabitId(id)) {
        await _habitRecordRepository.delete(record);
      }
      for (final record in await _habitTimeRecordRepository.getByHabitId(id)) {
        await _habitTimeRecordRepository.delete(record);
      }
      final deletedAt =
          await _habitRepository.deleteIfRevision(id, expectedRevision);
      if (deletedAt == null) throw HabitRevisionConflictException(id);
      return deletedAt;
    });
    _habitEvents.notifyHabitDeleted(id);
    return deletedAt;
  }

  Future<HabitActionResult> reorder({
    required String id,
    required DateTime expectedRevision,
    required int targetIndex,
    String? beforeId,
    String? afterId,
    required HabitBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      final habit = await _getHabit(id);
      _checkRevision(habit, expectedRevision);
      final siblings = await _habitRepository.getAll(
        customWhereFilter:
            CustomWhereFilter('id != ? AND deleted_date IS NULL', [id]),
        customOrder: [
          CustomOrder(field: 'order', direction: SortDirection.asc),
          CustomOrder(field: 'created_date', direction: SortDirection.asc),
          CustomOrder(field: 'id', direction: SortDirection.asc),
        ],
      );
      final placement = const SiblingReorderService().computePlacement(
        moved: habit,
        siblings: siblings,
        targetIndex: targetIndex,
        beforeId: beforeId,
        afterId: afterId,
        idOf: (value) => value.id,
        orderOf: (value) => value.order,
      );
      await beforeCommit();
      if (placement.requiresRenormalization) {
        final replacements = placement.renumbered!
            .where((value) => value.id != id)
            .map((value) => _copyHabit(
                value,
                _withOrder(HabitValues.fromHabit(value),
                    placement.renumberedOrder![value.id]!)))
            .toList(growable: false);
        await _habitRepository.updateMultiple(replacements);
      }
      final replacement = _copyHabit(
          habit, _withOrder(HabitValues.fromHabit(habit), placement.order));
      final revision = await _habitRepository.updateIfRevision(
          replacement, expectedRevision);
      if (revision == null) throw HabitRevisionConflictException(id);
      return HabitActionResult(id: id, revision: revision);
    });
    _habitEvents.notifyHabitUpdated(id);
    return result;
  }

  Future<HabitRecordSetResult> setRecords({
    required String habitId,
    required DateTime date,
    required HabitRecordStatus status,
    required int count,
    required HabitRecordBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      final habit = await _getHabit(habitId);
      final range = HabitDayStateResolver.utcRangeFor(date);
      final existing = (await _habitRecordRepository.getByHabitId(habitId))
          .where((record) =>
              !record.occurredAt.isBefore(range.start) &&
              !record.occurredAt.isAfter(range.end))
          .toList(growable: false);
      final timeRecords = await _habitTimeRecordRepository
          .getByHabitIdAndDateRange(habitId, range.start, range.end);
      final effectiveCount = _effectiveRecordCount(habit, status, count);
      final changesEstimatedTime =
          timeRecords.any((record) => record.isEstimated) ||
              (effectiveCount > 0 &&
                  status == HabitRecordStatus.complete &&
                  (habit.estimatedTime ?? 0) > 0);
      await beforeCommit(changesEstimatedTime);
      await _recordOperations.clearAllRecordsForDay(
        habitId,
        range.start,
        range.end,
        existing,
      );
      for (var index = 0; index < effectiveCount; index++) {
        await _recordOperations.addHabitRecord(
          habitId,
          date,
          status,
          DateTime.now().toUtc(),
        );
        await _recordOperations.addTimeRecordIfComplete(
            habit, habitId, date, status);
      }
      return HabitRecordSetResult(status: status, count: effectiveCount);
    });
    _habitEvents.notifyHabitRecordAdded(habitId);
    return result;
  }

  Future<HabitUndoResult> undoRecord({
    required String habitId,
    required DateTime date,
    String? recordId,
    required HabitBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      await _getHabit(habitId);
      final range = HabitDayStateResolver.utcRangeFor(date);
      final page = await _habitRecordRepository.getListByHabitIdAndRangeDate(
        habitId,
        range.start,
        range.end,
        0,
        1000,
      );
      final candidates = page.items
          .where((record) => recordId == null || record.id == recordId)
          .toList()
        ..sort((left, right) {
          final occurred = right.occurredAt.compareTo(left.occurredAt);
          if (occurred != 0) return occurred;
          final created = right.createdDate.compareTo(left.createdDate);
          return created != 0 ? created : right.id.compareTo(left.id);
        });
      if (candidates.isEmpty)
        throw HabitRecordNotFoundException(recordId ?? habitId);
      await beforeCommit();
      await _habitRecordRepository.delete(candidates.first);
      return HabitUndoResult(page.items.length - 1);
    });
    _habitEvents.notifyHabitRecordRemoved(habitId);
    return result;
  }

  Future<HabitActionResult> updateTimeRecord({
    required String habitId,
    required DateTime date,
    required int totalDuration,
    required DateTime expectedRevision,
    required HabitBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      await _getHabit(habitId);
      final range = HabitDayStateResolver.utcRangeFor(date);
      final records = await _habitTimeRecordRepository.getByHabitIdAndDateRange(
          habitId, range.start, range.end);
      if (records.isEmpty) throw HabitTimeRecordNotFoundException(habitId);
      records.sort((left, right) {
        final occurred = _timeOf(left).compareTo(_timeOf(right));
        return occurred != 0 ? occurred : left.id.compareTo(right.id);
      });
      final current = records
          .where((record) => _sameRevision(_revision(record), expectedRevision))
          .firstOrNull;
      if (current == null) throw HabitRevisionConflictException(habitId);
      await beforeCommit();
      for (final record in records.where((record) => record.id != current.id)) {
        await _habitTimeRecordRepository.delete(record);
      }
      final replacement = _copyTimeRecord(current, totalDuration);
      final revision = await _habitTimeRecordRepository.updateIfRevision(
          replacement, expectedRevision);
      if (revision == null) throw HabitRevisionConflictException(current.id);
      return HabitActionResult(id: replacement.id, revision: revision);
    });
    _habitEvents.notifyHabitUpdated(habitId);
    return result;
  }

  Future<HabitActionResult> addTimeRecord({
    required String habitId,
    required DateTime occurredAt,
    required int duration,
    required HabitBeforeCommit beforeCommit,
  }) async {
    final result = await _transactions.run(() async {
      await _getHabit(habitId);
      await beforeCommit();
      final record = await HabitTimeRecordService.addDurationToHabitTimeRecord(
        repository: _habitTimeRecordRepository,
        habitId: habitId,
        targetDate: occurredAt,
        durationToAdd: duration,
      );
      final persisted = await _habitTimeRecordRepository.getById(record.id);
      return HabitActionResult(id: record.id, revision: _revision(persisted!));
    });
    _habitEvents.notifyHabitUpdated(habitId);
    return result;
  }

  Future<Habit> _getHabit(String id) async {
    final habit = await _habitRepository.getById(id);
    if (habit == null) throw HabitNotFoundException(id);
    return habit;
  }

  void _checkRevision(Habit habit, DateTime expected) {
    if (!_sameRevision(_revision(habit), expected))
      throw HabitRevisionConflictException(habit.id);
  }

  Future<void> _validateTags(List<String> tagIds) async {
    if (tagIds.toSet().length != tagIds.length)
      throw ArgumentError('Duplicate tag id');
    final tags = await _tagRepository.getByIds(tagIds);
    final missing = tagIds.where((id) => !tags.containsKey(id)).firstOrNull;
    if (missing != null) throw HabitTagNotFoundException(missing);
  }

  Future<void> _replaceTags(
    String habitId,
    List<HabitTag> existing,
    List<String> requestedIds,
    Map<String, int> requestedOrder,
  ) async {
    final requested = requestedIds.toSet();
    for (final relation
        in existing.where((relation) => !requested.contains(relation.tagId))) {
      await _habitTagsRepository.delete(relation);
    }
    final existingIds = existing.map((relation) => relation.tagId).toSet();
    for (final tagId in requestedIds.where((id) => !existingIds.contains(id))) {
      await _habitTagsRepository.add(HabitTag(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        habitId: habitId,
        tagId: tagId,
      ));
    }
    final order = <String, int>{
      for (var index = 0; index < requestedIds.length; index++)
        requestedIds[index]: requestedOrder[requestedIds[index]] ?? index,
    };
    await _habitTagsRepository.updateTagOrders(habitId, order);
  }

  Habit _newHabit(HabitValues values, String order) => _habitFromValues(
        id: KeyHelper.generateStringId(),
        createdDate: DateTime.now().toUtc(),
        values: values,
        order: order,
      );

  Habit _copyHabit(Habit source, HabitValues values) => _habitFromValues(
        id: source.id,
        createdDate: source.createdDate,
        modifiedDate: source.modifiedDate,
        values: values,
        order: values.order,
      );

  HabitValues _withOrder(HabitValues values, String order) => HabitValues(
        name: values.name,
        description: values.description,
        type: values.type,
        estimatedTime: values.estimatedTime,
        hasReminder: values.hasReminder,
        reminderTime: values.reminderTime,
        reminderDays: values.reminderDays,
        hasGoal: values.hasGoal,
        targetFrequency: values.targetFrequency,
        periodDays: values.periodDays,
        dailyTarget: values.dailyTarget,
        archivedDate: values.archivedDate,
        order: order,
      );

  Habit _habitFromValues({
    required String id,
    required DateTime createdDate,
    required HabitValues values,
    required String order,
    DateTime? modifiedDate,
  }) {
    final isBad = values.type == HabitType.bad;
    final habit = Habit(
      id: id,
      createdDate: createdDate,
      modifiedDate: modifiedDate,
      name: values.name,
      description: values.description,
      type: values.type,
      estimatedTime: values.estimatedTime,
      archivedDate: values.archivedDate,
      hasReminder: values.hasReminder,
      reminderTime: values.reminderTime,
      hasGoal: isBad ? false : values.hasGoal,
      targetFrequency: isBad ? 1 : values.targetFrequency,
      periodDays: isBad ? 1 : values.periodDays,
      dailyTarget: isBad ? 1 : values.dailyTarget,
      order: order,
    );
    habit.setReminderDaysFromList(values.reminderDays);
    return habit;
  }

  HabitTimeRecord _copyTimeRecord(HabitTimeRecord source, int duration) =>
      HabitTimeRecord(
        id: source.id,
        habitId: source.habitId,
        duration: duration,
        occurredAt: source.occurredAt,
        isEstimated: false,
        createdDate: source.createdDate,
        modifiedDate: source.modifiedDate,
      );

  int _effectiveRecordCount(Habit habit, HabitRecordStatus status, int count) {
    if (status == HabitRecordStatus.skipped) return 0;
    if (habit.type == HabitType.bad)
      return status == HabitRecordStatus.notDone ? 1 : 0;
    return status == HabitRecordStatus.notDone ? 1 : count;
  }

  DateTime _revision(dynamic entity) =>
      _databaseDate(entity.modifiedDate ?? entity.createdDate);

  bool _sameRevision(DateTime left, DateTime right) =>
      _databaseDate(left).isAtSameMomentAs(_databaseDate(right));

  DateTime _databaseDate(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
        value.toUtc().millisecondsSinceEpoch,
        isUtc: true,
      );

  DateTime _timeOf(HabitTimeRecord record) =>
      record.occurredAt ?? record.createdDate;
}

List<int> _storedReminderDays(Habit habit) {
  if (habit.reminderDays.isEmpty) return const [];
  try {
    return habit.reminderDays
        .split(',')
        .where((day) => day.isNotEmpty)
        .map((day) => int.parse(day.trim()))
        .toList(growable: false);
  } on FormatException {
    return const [];
  }
}
