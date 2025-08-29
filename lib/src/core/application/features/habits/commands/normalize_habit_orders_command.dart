import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/src/core/domain/features/habits/habit.dart';
import 'package:acore/acore.dart';

class NormalizeHabitOrdersCommand implements IRequest<NormalizeHabitOrdersResponse> {
  const NormalizeHabitOrdersCommand();
}

class NormalizeHabitOrdersResponse {
  final int normalizedCount;

  NormalizeHabitOrdersResponse(this.normalizedCount);
}

class NormalizeHabitOrdersCommandHandler implements IRequestHandler<NormalizeHabitOrdersCommand, NormalizeHabitOrdersResponse> {
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

    // Use single timestamp for all updates in the batch
    final now = DateTime.now().toUtc();

    // Assign new normalized orders
    double orderStep = OrderRank.initialStep;
    final habitsToUpdate = <Habit>[];

    for (var habit in allHabits) {
      habit.order = orderStep;
      habit.modifiedDate = now;
      habitsToUpdate.add(habit);
      orderStep += OrderRank.initialStep;
    }

    // Batch update all habits
    await _habitRepository.updateAll(habitsToUpdate);

    return NormalizeHabitOrdersResponse(habitsToUpdate.length);
  }
}