import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:acore/acore.dart';

class NormalizeHabitOrdersCommand implements IRequest<NormalizeHabitOrdersResponse> {
  const NormalizeHabitOrdersCommand();
}

class NormalizeHabitOrdersResponse {
  final int normalizedCount;

  NormalizeHabitOrdersResponse(this.normalizedCount);
}

class NormalizeHabitOrdersCommandHandler
    implements IRequestHandler<NormalizeHabitOrdersCommand, NormalizeHabitOrdersResponse> {
  final IHabitRepository _habitRepository;

  NormalizeHabitOrdersCommandHandler(this._habitRepository);

  @override
  Future<NormalizeHabitOrdersResponse> call(NormalizeHabitOrdersCommand request) async {
    // Get all non-deleted habits
    final allHabits = await _habitRepository.getAll(
      customWhereFilter: CustomWhereFilter('deleted_date IS NULL', []),
      customOrder: [CustomOrder(field: "order")],
    );

    if (allHabits.isEmpty) {
      return NormalizeHabitOrdersResponse(0);
    }

    // Sort by current order to maintain relative positions
    allHabits.sort((a, b) => a.order.compareTo(b.order));

    // Assign clean, evenly spaced orders and batch update in one transaction.
    OrderRank.assignSequential<Habit>(allHabits, setOrder: (habit, order) => habit.order = order);
    await _habitRepository.updateMultiple(allHabits);

    return NormalizeHabitOrdersResponse(allHabits.length);
  }
}
