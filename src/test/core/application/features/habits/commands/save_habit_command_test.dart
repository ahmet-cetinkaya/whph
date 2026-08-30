import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:whph/core/application/features/habits/commands/save_habit_command.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
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
}
