import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/habits/services/i_habit_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_tags_repository.dart';
import 'package:whph/core/application/features/habits/services/i_habit_record_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/shared/utils/validation_utils.dart';

import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/core/application/features/habits/utils/habit_grouping_helper.dart';
import 'package:whph/core/application/features/habits/models/habit_list_item.dart';
export 'package:whph/core/application/features/habits/models/habit_list_item.dart';

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
  SortOption<HabitSortFields>? groupBy;
  List<String>? customTagSortOrder;

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
    this.groupBy,
    this.customTagSortOrder,
  });
}

class GetListHabitsQueryResponse extends PaginatedList<HabitListItem> {
  GetListHabitsQueryResponse(
      {required super.items, required super.totalItemCount, required super.pageIndex, required super.pageSize});
}

class GetListHabitsQueryHandler implements IRequestHandler<GetListHabitsQuery, GetListHabitsQueryResponse> {
  late final IHabitRepository _habitRepository;
  late final IHabitTagsRepository _habitTagsRepository;
  late final IHabitRecordRepository _habitRecordRepository;

  GetListHabitsQueryHandler({
    required IHabitRepository habitRepository,
    required IHabitTagsRepository habitTagRepository,
    required IHabitRecordRepository habitRecordRepository,
  })  : _habitRepository = habitRepository,
        _habitTagsRepository = habitTagRepository,
        _habitRecordRepository = habitRecordRepository;

  @override
  Future<GetListHabitsQueryResponse> call(GetListHabitsQuery request) async {
    // 1. Fetch habits with aggregated actualTime in a single query
    PaginatedList<HabitListItem> habits = await _habitRepository.getHabitListItems(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: _getCustomWhereFilter(request),
      customOrder: _getCustomOrders(request),
    );

    // Apply period-aware filtering if excludeCompletedForDate is specified
    List<HabitListItem> filteredHabits = habits.items;
    if (request.excludeCompletedForDate != null) {
      filteredHabits = await _filterHabitsWithPeriodAwareness(habits.items, request.excludeCompletedForDate!);
    }

    if (filteredHabits.isEmpty) {
      return GetListHabitsQueryResponse(
        items: [],
        totalItemCount: habits.totalItemCount,
        pageIndex: habits.pageIndex,
        pageSize: habits.pageSize,
      );
    }

    // 2. Fetch tags for the retrieved habits in a single batch query
    final habitIds = filteredHabits.map((h) => h.id).toList();
    final habitTagsMap = await _habitTagsRepository.getTagsForHabitIds(habitIds);

    // 3. Populate tags and calculate group names
    // Determine sort field for grouping
    HabitSortFields? primarySortField;
    if (request.groupBy != null) {
      primarySortField = request.groupBy!.field;
    } else if (request.sortBy != null && request.sortBy!.isNotEmpty) {
      primarySortField = request.sortBy!.first.field;
    }

    final resultItems = filteredHabits.map((habitItem) {
      // Assign tags
      List<TagListItem> tags = habitItem.tags;
      if (habitTagsMap.containsKey(habitItem.id)) {
        tags = List<TagListItem>.from(habitTagsMap[habitItem.id]!);
      }

      // Sort tags of the habit based on the same criteria as sorting/grouping
      // This ensures the "best" tag is first for HabitGroupingHelper.getGroupName
      if (tags.isNotEmpty) {
        if (request.customTagSortOrder != null && request.customTagSortOrder!.isNotEmpty) {
          final orderMap = {
            for (var i = 0; i < request.customTagSortOrder!.length; i++) request.customTagSortOrder![i]: i
          };
          tags.sort((a, b) {
            final indexA = orderMap[a.id] ?? 999;
            final indexB = orderMap[b.id] ?? 999;
            if (indexA != indexB) return indexA.compareTo(indexB);
            return a.tagOrder.compareTo(b.tagOrder);
          });
        }
      }

      // Assign group name
      final groupName = HabitGroupingHelper.getGroupName(habitItem.copyWith(tags: tags), primarySortField);

      return habitItem.copyWith(
        tags: tags,
        groupName: groupName,
      );
    }).toList();

    return GetListHabitsQueryResponse(
      items: resultItems,
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
    List<CustomOrder> customOrders = [];

    // Prioritize grouping field if exists
    if (request.groupBy != null) {
      _addCustomOrder(customOrders, request.groupBy!, request);
    }

    if (request.sortByCustomSort) {
      customOrders.add(CustomOrder(field: "order", direction: SortDirection.asc));
      return customOrders;
    }

    if (request.sortBy == null || request.sortBy!.isEmpty) {
      return customOrders.isEmpty ? null : customOrders;
    }

    // Add other sort options from list
    if (request.sortBy != null) {
      for (var option in request.sortBy!) {
        // Avoid duplicate if group by is same as first sort option
        if (request.groupBy != null && option.field == request.groupBy!.field) {
          continue;
        }
        _addCustomOrder(customOrders, option, request);
      }
    }

    return customOrders.isEmpty ? null : customOrders;
  }

  void _addCustomOrder(List<CustomOrder> orders, SortOption<HabitSortFields> option, GetListHabitsQuery request) {
    if (option.field == HabitSortFields.name) {
      orders.add(CustomOrder(field: "name", direction: option.direction));
    } else if (option.field == HabitSortFields.createdDate) {
      orders.add(CustomOrder(field: "created_date", direction: option.direction));
    } else if (option.field == HabitSortFields.modifiedDate) {
      orders.add(CustomOrder(field: "modified_date", direction: option.direction));
    } else if (option.field == HabitSortFields.estimatedTime) {
      orders.add(CustomOrder(field: "estimated_time", direction: option.direction));
    } else if (option.field == HabitSortFields.actualTime) {
      // actualTime sorting is now handled at the database level with LEFT JOIN
      orders.add(CustomOrder(field: "actual_time", direction: option.direction));
    } else if (option.field == HabitSortFields.archivedDate) {
      orders.add(CustomOrder(field: "archived_date", direction: option.direction));
    } else if (option.field == HabitSortFields.tag) {
      // Sort by the first tag
      // Logic:
      // 1. Get the "best" tag for each habit based on custom order or name
      // 2. Sort habits by that tag

      if (request.customTagSortOrder != null && request.customTagSortOrder!.isNotEmpty) {
        // Create a CASE statement for custom ordering
        final caseStatements = StringBuffer();
        for (int i = 0; i < request.customTagSortOrder!.length; i++) {
          final safeId = sanitizeAndValidateId(request.customTagSortOrder![i]);
          caseStatements.write("WHEN '$safeId' THEN $i ");
        }

        orders.add(CustomOrder(
          field: '''(
            SELECT MIN(CASE ht.tag_id 
              $caseStatements
              ELSE 999 
            END) 
            FROM habit_tag_table ht 
            WHERE ht.habit_id = habit_table.id 
            AND ht.deleted_date IS NULL
          )''',
          direction: option.direction,
        ));
      } else {
        // Default sort by first tag order, then name
        orders.add(CustomOrder(
          field: '''(
            SELECT t.name
            FROM habit_tag_table ht
            JOIN tag_table t ON ht.tag_id = t.id
            WHERE ht.habit_id = habit_table.id
            AND ht.deleted_date IS NULL
            AND t.deleted_date IS NULL
            ORDER BY ht.tag_order ASC, t.name COLLATE NOCASE ASC
            LIMIT 1
          )''',
          direction: option.direction,
        ));
      }
    }
  }

  /// Filters habits with period-aware completion logic
  Future<List<HabitListItem>> _filterHabitsWithPeriodAwareness(List<HabitListItem> habits, DateTime targetDate) async {
    final List<HabitListItem> filteredHabits = [];
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
