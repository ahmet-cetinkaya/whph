import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';

class GetListHabitsQuery implements IRequest<GetListHabitsQueryResponse> {
  late int pageIndex;
  late int pageSize;
  bool excludeCompleted;
  List<String>? filterByTags;

  GetListHabitsQuery(
      {required this.pageIndex, required this.pageSize, this.excludeCompleted = false, this.filterByTags});
}

class HabitListItem {
  String id;
  String name;
  List<TagListItem> tags;

  HabitListItem({
    required this.id,
    required this.name,
    this.tags = const [],
  });
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
  late final IHabitTagsRepository _habitTagsRepository;
  late final ITagRepository _tagRepository;

  GetListHabitsQueryHandler({
    required IHabitRepository habitRepository,
    required IHabitTagsRepository habitTagRepository,
    required ITagRepository tagRepository,
  })  : _habitRepository = habitRepository,
        _habitTagsRepository = habitTagRepository,
        _tagRepository = tagRepository;

  @override
  Future<GetListHabitsQueryResponse> call(GetListHabitsQuery request) async {
    PaginatedList<Habit> habits = await _habitRepository.getList(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: _getCustomWhereFilter(request),
    );

    List<HabitListItem> habitItems = [];

    for (var habit in habits.items) {
      // Fetch tags for each habit
      var habitTags =
          await _habitTagsRepository.getList(0, 5, customWhereFilter: CustomWhereFilter("habit_id = ?", [habit.id]));

      var tagItems = await Future.wait(habitTags.items.map((ht) async {
        var tag = await _tagRepository.getById(ht.tagId);
        return TagListItem(
          id: ht.tagId,
          name: tag?.name ?? "",
        );
      }).toList());

      habitItems.add(HabitListItem(
        id: habit.id,
        name: habit.name,
        tags: tagItems,
      ));
    }

    return GetListHabitsQueryResponse(
      items: habitItems,
      totalItemCount: habits.totalItemCount,
      totalPageCount: habits.totalPageCount,
      pageIndex: habits.pageIndex,
      pageSize: habits.pageSize,
    );
  }

  CustomWhereFilter? _getCustomWhereFilter(GetListHabitsQuery request) {
    CustomWhereFilter? customWhereFilter;

    if (request.excludeCompleted) {
      customWhereFilter = CustomWhereFilter.empty();

      var startDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      var endDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);
      customWhereFilter.query =
          "(SELECT COUNT(*) FROM habit_record_table WHERE habit_record_table.habit_id = habit_table.id AND habit_record_table.date > ? AND habit_record_table.date < ? AND habit_record_table.deleted_date IS NULL) = 0";
      customWhereFilter.variables.add(startDate);
      customWhereFilter.variables.add(endDate);
    }

    if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      customWhereFilter = CustomWhereFilter.empty();

      customWhereFilter.query =
          "(SELECT COUNT(*) FROM habit_tag_table WHERE habit_tag_table.habit_id = habit_table.id AND habit_tag_table.tag_id IN (${request.filterByTags!.map((e) => '?').join(',')})) > 0";
      customWhereFilter.variables.addAll(request.filterByTags!);
    }

    return customWhereFilter;
  }
}
