import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
import 'package:acore/acore.dart';

class _HabitRepository extends Mock implements IHabitRepository {
  Habit? savedHabit;
  List<Habit> habits = const [];

  @override
  Future<PaginatedList<Habit>> getList(
    int pageIndex,
    int pageSize, {
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
    bool includeDeleted = false,
  }) async =>
      PaginatedList(
        items: habits,
        totalItemCount: habits.length,
        pageIndex: pageIndex,
        pageSize: pageSize,
      );

  @override
  Future<void> add(Habit entity) async {
    savedHabit = entity;
  }

  @override
  Future<Habit?> getById(String id, {bool includeDeleted = false}) async =>
      habits.where((habit) => habit.id == id).firstOrNull;

  @override
  Future<String> getReminderDaysById(String id) async =>
      habits.where((habit) => habit.id == id).firstOrNull?.reminderDays ?? '';

  @override
  Future<void> update(Habit entity) async {
    savedHabit = entity;
  }
}

void main() {
  test('new habits append a non-empty canonical rank', () async {
    final repository = _HabitRepository();
    final handler = SaveHabitCommandHandler(habitRepository: repository);
    final existingHabit = Habit(
      id: 'existing',
      createdDate: DateTime.now().toUtc(),
      name: 'Existing',
      description: '',
      order: 'U',
    );
    repository.habits = [existingHabit];
    await handler(SaveHabitCommand(name: 'New', description: ''));

    final newHabit = repository.savedHabit!;
    expect(newHabit.order, isNotEmpty);
    expect(OrderRank.needsNormalization([newHabit.order]), isFalse);
    expect(newHabit.order.compareTo(existingHabit.order), greaterThan(0));
  });

  test('new habits default to the good type', () async {
    final repository = _HabitRepository();
    final handler = SaveHabitCommandHandler(habitRepository: repository);

    await handler(SaveHabitCommand(name: 'Good', description: ''));

    expect(repository.savedHabit!.type, HabitType.good);
  });

  test('bad habit commands normalize goal fields before persistence', () async {
    final repository = _HabitRepository();
    final handler = SaveHabitCommandHandler(habitRepository: repository);

    await handler(SaveHabitCommand(
      name: 'Bad',
      description: '',
      type: HabitType.bad,
      hasGoal: true,
      dailyTarget: 9,
      targetFrequency: 8,
      periodDays: 7,
    ));

    final savedHabit = repository.savedHabit!;
    expect(savedHabit.type, HabitType.bad);
    expect(savedHabit.hasGoal, isFalse);
    expect(savedHabit.dailyTarget, 1);
    expect(savedHabit.targetFrequency, 1);
    expect(savedHabit.periodDays, 1);
  });

  test('changing a habit type updates the same habit identity', () async {
    final repository = _HabitRepository();
    final existingHabit = Habit(
      id: 'habit-id',
      createdDate: DateTime.utc(2024, 1, 1),
      name: 'Convert',
      description: '',
    );
    repository.habits = [existingHabit];
    final handler = SaveHabitCommandHandler(habitRepository: repository);

    await handler(SaveHabitCommand(
      id: existingHabit.id,
      name: existingHabit.name,
      description: existingHabit.description,
      type: HabitType.bad,
    ));

    expect(repository.savedHabit!.id, existingHabit.id);
    expect(repository.savedHabit!.createdDate, existingHabit.createdDate);
    expect(repository.savedHabit!.type, HabitType.bad);
  });
}
