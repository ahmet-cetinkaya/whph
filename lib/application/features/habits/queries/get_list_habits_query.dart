import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/core/acore/repository/models/custom_order.dart';
import 'package:whph/core/acore/repository/models/paginated_list.dart';
import 'package:whph/domain/features/habits/habit.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/acore/queries/models/sort_option.dart';

enum HabitSortFields {
  name,
  createdDate,
  modifiedDate,
  estimatedTime,
  archivedDate,
}

class GetListHabitsQuery implements IRequest<GetListHabitsQueryResponse> {
  late int pageIndex;
  late int pageSize;
  bool excludeCompleted;
  List<String>? filterByTags;
  bool filterNoTags;
  bool? filterByArchived;
  List<SortOption<HabitSortFields>>? sortBy;
  bool sortByCustomSort;
  String? search;

  GetListHabitsQuery({
    required this.pageIndex,
    required this.pageSize,
    this.excludeCompleted = false,
    this.filterByTags,
    this.filterNoTags = false,
    this.filterByArchived,
    this.sortBy,
    this.sortByCustomSort = false,
    this.search,
  });
}

class HabitListItem {
  String id;
  String name;
  List<TagListItem> tags;
  int? estimatedTime;
  bool hasReminder;
  String? reminderTime;
  List<int> reminderDays;
  DateTime? archivedDate;

  HabitListItem({
    required this.id,
    required this.name,
    this.tags = const [],
    this.estimatedTime,
    this.hasReminder = false,
    this.reminderTime,
    this.reminderDays = const [],
    this.archivedDate,
  });

  bool isArchived() {
    return archivedDate != null;
  }
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
      customOrder: _getCustomOrders(request),
    );

    List<HabitListItem> habitItems = [];

    for (final habit in habits.items) {
      // Fetch tags for each habit
      final habitTags =
          await _habitTagsRepository.getList(0, 5, customWhereFilter: CustomWhereFilter("habit_id = ?", [habit.id]));

      final tagItems = await Future.wait(habitTags.items.map((ht) async {
        final tag = await _tagRepository.getById(ht.tagId);
        return TagListItem(
          id: ht.tagId,
          name: tag?.name ?? "",
          color: tag?.color,
        );
      }).toList());

      habitItems.add(HabitListItem(
        id: habit.id,
        name: habit.name,
        tags: tagItems,
        estimatedTime: habit.estimatedTime,
        hasReminder: habit.hasReminder,
        reminderTime: habit.reminderTime,
        reminderDays: habit.getReminderDaysAsList(),
        archivedDate: habit.archivedDate,
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
    final conditions = <String>[];
    final variables = <Object>[];

    // Search filter
    if (request.search?.isNotEmpty ?? false) {
      conditions.add("habit_table.name LIKE ?");
      variables.add('%${request.search}%');
    }

    // Filter by archive status if specified
    if (request.filterByArchived != null) {
      conditions.add(
          request.filterByArchived! ? "habit_table.archived_date IS NOT NULL" : "habit_table.archived_date IS NULL");
    }

    if (request.excludeCompleted) {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).toUtc();
      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc();
      conditions.add(
          "(SELECT COUNT(*) FROM habit_record_table WHERE habit_record_table.habit_id = habit_table.id AND habit_record_table.date > ? AND habit_record_table.date < ? AND habit_record_table.deleted_date IS NULL) = 0");
      variables.add(startDate);
      variables.add(endDate);
    }

    if (request.filterNoTags) {
      // Filter habits with no tags
      conditions.add(
          "(SELECT COUNT(*) FROM habit_tag_table WHERE habit_tag_table.habit_id = habit_table.id AND habit_tag_table.deleted_date IS NULL) = 0");
    } else if (request.filterByTags != null && request.filterByTags!.isNotEmpty) {
      // Filter habits with specific tags
      final placeholders = request.filterByTags!.map((e) => '?').join(',');
      conditions.add(
          "(SELECT COUNT(*) FROM habit_tag_table WHERE habit_tag_table.habit_id = habit_table.id AND habit_tag_table.tag_id IN ($placeholders) AND habit_tag_table.deleted_date IS NULL) > 0");
      variables.addAll(request.filterByTags!);
    }

    if (conditions.isEmpty) return null;

    return CustomWhereFilter(conditions.join(' AND '), variables);
  }

  List<CustomOrder>? _getCustomOrders(GetListHabitsQuery request) {
    if (request.sortBy == null || request.sortBy!.isEmpty) {
      return null;
    }

    if (request.sortByCustomSort) {
      return [CustomOrder(field: "order")];
    }

    List<CustomOrder> customOrders = [];
    for (var option in request.sortBy!) {
      if (option.field == HabitSortFields.name) {
        customOrders.add(CustomOrder(field: "name", direction: option.direction));
      } else if (option.field == HabitSortFields.createdDate) {
        customOrders.add(CustomOrder(field: "created_date", direction: option.direction));
      } else if (option.field == HabitSortFields.modifiedDate) {
        customOrders.add(CustomOrder(field: "modified_date", direction: option.direction));
      } else if (option.field == HabitSortFields.estimatedTime) {
        customOrders.add(CustomOrder(field: "estimated_time", direction: option.direction));
      } else if (option.field == HabitSortFields.archivedDate) {
        customOrders.add(CustomOrder(field: "archived_date", direction: option.direction));
      }
    }
    return customOrders.isEmpty ? null : customOrders;
  }
}
