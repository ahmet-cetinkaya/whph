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
    // Match the visible list's tie-breakers so normalization preserves its order.
    final allHabits = await _habitRepository.getAll(
      customWhereFilter: CustomWhereFilter('deleted_date IS NULL', []),
      customOrder: [
        CustomOrder(field: "order", direction: SortDirection.asc),
        CustomOrder(field: "created_date", direction: SortDirection.asc),
        CustomOrder(field: "id", direction: SortDirection.asc),
      ],
    );

    if (allHabits.isEmpty) {
      return NormalizeHabitOrdersResponse(0);
    }

    allHabits.sort((a, b) {
      final orderComparison = a.order.compareTo(b.order);
      if (orderComparison != 0) return orderComparison;

      final createdDateComparison = a.createdDate.compareTo(b.createdDate);
      if (createdDateComparison != 0) return createdDateComparison;

      return a.id.compareTo(b.id);
    });

    // Assign clean, evenly spaced orders and batch update in one transaction.
    OrderRank.assignSequential<Habit>(allHabits, setOrder: (habit, order) => habit.order = order);
    await _habitRepository.updateMultiple(allHabits);

    return NormalizeHabitOrdersResponse(allHabits.length);
  }
}
