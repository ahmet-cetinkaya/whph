import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/habits/habit.dart';

class GetListHabitsQuery implements IRequest<GetListHabitsQueryResponse> {
  late int pageIndex;
  late int pageSize;

  GetListHabitsQuery({required this.pageIndex, required this.pageSize});
}

class HabitListItem {
  int id;
  String name;

  HabitListItem({required this.id, required this.name});
}

class GetListHabitsQueryResponse extends PaginatedList<HabitListItem> {
  GetListHabitsQueryResponse(
      {required super.items,
      required super.totalItemCount,
      required super.totalPageCount,
      required super.pageIndex,
      required super.pageSize});
}

class GetListHabitsQueryHandler implements IRequestHandler<GetListHabitsQuery, GetListHabitsQueryResponse> {
  late final IHabitRepository _habitRepository;

  GetListHabitsQueryHandler({required IHabitRepository habitRepository}) : _habitRepository = habitRepository;

  @override
  Future<GetListHabitsQueryResponse> call(GetListHabitsQuery request) async {
    PaginatedList<Habit> habits = await _habitRepository.getList(
      request.pageIndex,
      request.pageSize,
    );

    return GetListHabitsQueryResponse(
      items: habits.items.map((e) => HabitListItem(id: e.id, name: e.name)).toList(),
      totalItemCount: habits.totalItemCount,
      totalPageCount: habits.totalPageCount,
      pageIndex: habits.pageIndex,
      pageSize: habits.pageSize,
    );
  }
}
