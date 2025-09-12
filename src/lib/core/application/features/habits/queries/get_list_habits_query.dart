import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';

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
  bool ignoreArchivedTagVisibility;
  DateTime? excludeCompletedForDate;

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
    this.ignoreArchivedTagVisibility = false,
    this.excludeCompletedForDate,
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
  double? order;
  bool hasGoal;
  int? dailyTarget;
  int targetFrequency;
  int periodDays;

  HabitListItem({
    required this.id,
    required this.name,
    this.tags = const [],
    this.estimatedTime,
    this.hasReminder = false,
    this.reminderTime,
    this.reminderDays = const [],
    this.archivedDate,
    this.order,
    this.hasGoal = false,
    this.dailyTarget,
    this.targetFrequency = 1,
    this.periodDays = 1,
  });

  bool isArchived() {
    return archivedDate != null;
  }
}

class GetListHabitsQueryResponse extends PaginatedList<HabitListItem> {
  GetListHabitsQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
}

class GetListHabitsQueryHandler implements IRequestHandler<GetListHabitsQuery, GetListHabitsQueryResponse> {
  late final IHabitRepository _habitRepository;
  late final IHabitTagsRepository _habitTagsRepository;
  late final ITagRepository _tagRepository;
  late final IHabitRecordRepository _habitRecordRepository;

  GetListHabitsQueryHandler({
    required IHabitRepository habitRepository,
    required IHabitTagsRepository habitTagRepository,
    required ITagRepository tagRepository,
    required IHabitRecordRepository habitRecordRepository,
  })  : _habitRepository = habitRepository,
        _habitTagsRepository = habitTagRepository,
        _tagRepository = tagRepository,
        _habitRecordRepository = habitRecordRepository;

  @override
  Future<GetListHabitsQueryResponse> call(GetListHabitsQuery request) async {
    PaginatedList<Habit> habits = await _habitRepository.getList(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: _getCustomWhereFilter(request),
      customOrder: _getCustomOrders(request),
    );

    // Apply period-aware filtering if excludeCompletedForDate is specified
    List<Habit> filteredHabits = habits.items;
    if (request.excludeCompletedForDate != null) {
      filteredHabits = await _filterHabitsWithPeriodAwareness(habits.items, request.excludeCompletedForDate!);
    }

    List<HabitListItem> habitItems = [];

    // Fetch all habit tags for all habits in a single query to avoid N+1 problem
    final habitIds = filteredHabits.map((habit) => habit.id).toList();
    List<dynamic> habitTagsList = [];
    Map<String, List<TagListItem>> habitTagsMap = {};

    if (habitIds.isNotEmpty) {
      final habitTagsWhereFilter = CustomWhereFilter(
        "habit_id IN (${habitIds.map((_) => '?').join(',')})",
        habitIds as List<Object>,
      );
      habitTagsList = (await _habitTagsRepository.getList(
        0,
        habitIds.length * 5, // Allow up to 5 tags per habit
        customWhereFilter: habitTagsWhereFilter,
      ))
          .items;

      // Fetch all tags for these habit tags in a single query
      final tagIds = habitTagsList.map((ht) => ht.tagId).toSet().toList();
      List<dynamic> tagsList = [];
      if (tagIds.isNotEmpty) {
        final tagsWhereFilter = CustomWhereFilter(
          "id IN (${tagIds.map((_) => '?').join(',')})",
          tagIds.cast<Object>(),
        );
        tagsList = (await _tagRepository.getList(
          0,
          tagIds.length,
          customWhereFilter: tagsWhereFilter,
        ))
            .items;
      }

      // Create a map for quick tag lookup
      final tagMap = {for (final tag in tagsList) tag.id: tag};

      // Create a map of habitId to tag items
      habitTagsMap = <String, List<TagListItem>>{};
      for (final ht in habitTagsList) {
        final tag = tagMap[ht.tagId];
        if (tag != null) {
          habitTagsMap.putIfAbsent(ht.habitId, () => []).add(
                TagListItem(
                  id: ht.tagId,
                  name: tag.name ?? "",
                  color: tag.color,
                ),
              );
        }
      }
    }

    // Create habit items with their tags
    for (final habit in filteredHabits) {
      final tagItems = habitTagsMap.containsKey(habit.id) ? habitTagsMap[habit.id]! : <TagListItem>[];

      habitItems.add(HabitListItem(
        id: habit.id,
        name: habit.name,
        tags: tagItems,
        estimatedTime: habit.estimatedTime,
        hasReminder: habit.hasReminder,
        reminderTime: habit.reminderTime,
        reminderDays: habit.getReminderDaysAsList(),
        archivedDate: habit.archivedDate,
        order: habit.order,
        hasGoal: habit.hasGoal,
        dailyTarget: habit.dailyTarget,
        targetFrequency: habit.targetFrequency,
        periodDays: habit.periodDays,
      ));
    }

    return GetListHabitsQueryResponse(
      items: habitItems,
      totalItemCount: habits.totalItemCount,
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
          "(SELECT COUNT(*) FROM habit_record_table WHERE habit_record_table.habit_id = habit_table.id AND habit_record_table.occurred_at > ? AND habit_record_table.occurred_at < ? AND habit_record_table.deleted_date IS NULL) < COALESCE(habit_table.daily_target, 1)");
      variables.add(startDate);
      variables.add(endDate);
    }

    // Exclude habits completed for a specific date (only daily target check in SQL)
    if (request.excludeCompletedForDate != null) {
      final startDate = DateTime(request.excludeCompletedForDate!.year, request.excludeCompletedForDate!.month,
              request.excludeCompletedForDate!.day)
          .toUtc();
      final endDate = DateTime(request.excludeCompletedForDate!.year, request.excludeCompletedForDate!.month,
              request.excludeCompletedForDate!.day, 23, 59, 59, 999)
          .toUtc();
      conditions.add(
          "(SELECT COUNT(*) FROM habit_record_table WHERE habit_record_table.habit_id = habit_table.id AND habit_record_table.occurred_at >= ? AND habit_record_table.occurred_at <= ? AND habit_record_table.deleted_date IS NULL) < COALESCE(habit_table.daily_target, 1)");
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

    // Exclude habits only if ALL their tags are archived (show if at least one tag is not archived)
    if (!request.ignoreArchivedTagVisibility) {
      conditions.add('''
        habit_table.id NOT IN (
          SELECT DISTINCT ht1.habit_id 
          FROM habit_tag_table ht1
          WHERE ht1.deleted_date IS NULL
          AND NOT EXISTS (
            SELECT 1 
            FROM habit_tag_table ht2
            INNER JOIN tag_table t ON ht2.tag_id = t.id
            WHERE ht2.habit_id = ht1.habit_id 
            AND ht2.deleted_date IS NULL
            AND (t.is_archived = 0 OR t.is_archived IS NULL)
          )
        )
      ''');
    }

    if (conditions.isEmpty) return null;

    return CustomWhereFilter(conditions.join(' AND '), variables);
  }

  List<CustomOrder>? _getCustomOrders(GetListHabitsQuery request) {
    if (request.sortBy == null || request.sortBy!.isEmpty) {
      return null;
    }

    if (request.sortByCustomSort) {
      return [CustomOrder(field: "order", direction: SortDirection.asc)];
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

  /// Filters habits with period-aware completion logic
  Future<List<Habit>> _filterHabitsWithPeriodAwareness(List<Habit> habits, DateTime targetDate) async {
    final List<Habit> filteredHabits = [];
    final today = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);

    // Identify period-based habits and their date ranges
    final periodHabits = habits.where((habit) => habit.hasGoal && habit.periodDays > 1).toList();
    final Map<String, dynamic> habitPeriodData = {};

    // Calculate the earliest period start date to fetch all needed records in one query
    DateTime? earliestPeriodStart;

    for (final habit in periodHabits) {
      final periodStartDate = today.subtract(Duration(days: habit.periodDays - 1));
      final periodStartOfDay = DateTime(periodStartDate.year, periodStartDate.month, periodStartDate.day);

      habitPeriodData[habit.id] = {
        'periodStartOfDay': periodStartOfDay,
        'dailyTarget': habit.dailyTarget ?? 1,
        'targetFrequency': habit.targetFrequency,
      };

      if (earliestPeriodStart == null || periodStartOfDay.isBefore(earliestPeriodStart)) {
        earliestPeriodStart = periodStartOfDay;
      }
    }

    // Batch fetch all period records for all period-based habits in a single query
    Map<String, List<dynamic>> allHabitRecords = {};
    if (periodHabits.isNotEmpty && earliestPeriodStart != null) {
      final habitIds = periodHabits.map((habit) => habit.id).toList();

      // Use a custom where filter to get all records for all habits in the period range
      final whereFilter = CustomWhereFilter(
        "habit_id IN (${habitIds.map((_) => '?').join(',')}) AND occurred_at >= ? AND occurred_at <= ? AND deleted_date IS NULL",
        [...habitIds, earliestPeriodStart, endOfDay],
      );

      final allRecords = await _habitRecordRepository.getList(
        0,
        habitIds.length * 100, // Sufficient for multiple periods
        customWhereFilter: whereFilter,
      );

      // Group records by habit ID
      for (final record in allRecords.items) {
        allHabitRecords.putIfAbsent(record.habitId, () => []).add(record);
      }
    }

    // Process each habit using pre-fetched data
    for (final habit in habits) {
      bool shouldInclude = true;

      if (habit.hasGoal && habit.periodDays > 1) {
        // For period-based goals, check if period goal is already met using pre-fetched records
        final periodData = habitPeriodData[habit.id];
        final periodStartOfDay = periodData['periodStartOfDay'] as DateTime;
        final dailyTarget = periodData['dailyTarget'] as int;
        final targetFrequency = periodData['targetFrequency'] as int;

        final habitRecords = allHabitRecords[habit.id] ?? [];

        // Filter records to the specific period for this habit and group by date
        final recordsByDate = <DateTime, List>{};
        for (final record in habitRecords) {
          final recordDate = DateTime(record.occurredAt.year, record.occurredAt.month, record.occurredAt.day);
          if (!recordDate.isBefore(periodStartOfDay) && !recordDate.isAfter(today)) {
            recordsByDate.putIfAbsent(recordDate, () => []).add(record);
          }
        }

        // Count days that meet the daily target
        int completedDaysInPeriod = 0;
        for (final entry in recordsByDate.entries) {
          if (entry.value.length >= dailyTarget) {
            completedDaysInPeriod++;
          }
        }

        // If period goal is met, exclude this habit
        if (completedDaysInPeriod >= targetFrequency) {
          shouldInclude = false;
        }
      }
      // For daily habits, the SQL filtering already handled them correctly

      if (shouldInclude) {
        filteredHabits.add(habit);
      }
    }

    return filteredHabits;
  }
}
