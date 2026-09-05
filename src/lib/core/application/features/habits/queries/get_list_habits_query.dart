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
import 'package:whph/core/domain/features/habits/habit_record_status.dart';
import 'package:whph/core/domain/features/habits/habit_type.dart';
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
    PaginatedList<HabitListItem> habits = await _habitRepository.getHabitListItems(
      request.pageIndex,
      request.pageSize,
      customWhereFilter: _getCustomWhereFilter(request),
      customOrder: _getCustomOrders(request),
    );

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

    final habitIds = filteredHabits.map((h) => h.id).toList();
    final habitTagsMap = await _habitTagsRepository.getTagsForHabitIds(habitIds);

    HabitSortFields? primarySortField;
    if (request.groupBy != null) {
      primarySortField = request.groupBy!.field;
    } else if (request.sortBy != null && request.sortBy!.isNotEmpty) {
      primarySortField = request.sortBy!.first.field;
    }

    final resultItems = filteredHabits.map((habitItem) {
      List<TagListItem> tags = habitItem.tags;
      if (habitTagsMap.containsKey(habitItem.id)) {
        tags = List<TagListItem>.from(habitTagsMap[habitItem.id]!);
      }

      // Ensure the best tag is first for HabitGroupingHelper.getGroupName
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

      final groupInfo = HabitGroupingHelper.getGroupInfo(habitItem.copyWith(tags: tags), primarySortField);

      return habitItem.copyWith(
        tags: tags,
        groupName: groupInfo?.name,
        isGroupNameTranslatable: groupInfo?.isTranslatable ?? false,
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
      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc();
      conditions.add('''(
        (habit_table.type != ? AND
          (SELECT COUNT(*) FROM habit_record_table
           WHERE habit_record_table.habit_id = habit_table.id
             AND habit_record_table.occurred_at >= ?
             AND habit_record_table.occurred_at <= ?
             AND habit_record_table.deleted_date IS NULL) < COALESCE(habit_table.daily_target, 1))
        OR
        (habit_table.type = ? AND (
          habit_table.created_date > ?
          OR habit_table.archived_date < ?
          OR EXISTS (
            SELECT 1 FROM habit_record_table
            WHERE habit_record_table.habit_id = habit_table.id
              AND habit_record_table.occurred_at >= ?
              AND habit_record_table.occurred_at <= ?
              AND habit_record_table.status = ?
              AND habit_record_table.deleted_date IS NULL
          )
        ))
      )''');
      variables.addAll([
        HabitType.bad.id,
        startDate,
        endDate,
        HabitType.bad.id,
        endDate,
        startDate,
        startDate,
        endDate,
        HabitRecordStatus.notDone.index,
      ]);
    }

    if (request.excludeCompletedForDate != null) {
      final requestedDate = request.excludeCompletedForDate!;
      final startDate = DateTime(requestedDate.year, requestedDate.month, requestedDate.day).toUtc();
      final endDate = DateTime(requestedDate.year, requestedDate.month, requestedDate.day, 23, 59, 59, 999).toUtc();
      final now = DateTime.now();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc();
      conditions.add('''(
        (habit_table.type != ? AND (
          habit_table.has_goal = 1
          OR (SELECT COUNT(*) FROM habit_record_table
              WHERE habit_record_table.habit_id = habit_table.id
                AND habit_record_table.occurred_at >= ?
                AND habit_record_table.occurred_at <= ?
                AND habit_record_table.deleted_date IS NULL) < COALESCE(habit_table.daily_target, 1)))
        OR
        (habit_table.type = ? AND (
          habit_table.created_date > ?
          OR habit_table.archived_date < ?
          OR ? > ?
          OR EXISTS (
            SELECT 1 FROM habit_record_table
            WHERE habit_record_table.habit_id = habit_table.id
              AND habit_record_table.occurred_at >= ?
              AND habit_record_table.occurred_at <= ?
              AND habit_record_table.status = ?
              AND habit_record_table.deleted_date IS NULL
          )
        ))
      )''');
      variables.addAll([
        HabitType.bad.id,
        startDate,
        endDate,
        HabitType.bad.id,
        endDate,
        startDate,
        startDate,
        todayEnd,
        startDate,
        endDate,
        HabitRecordStatus.notDone.index,
      ]);
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
    if (request.sortByCustomSort) {
      final customOrders = <CustomOrder>[];
      if (request.groupBy != null) {
        _addCustomOrder(customOrders, request.groupBy!, request);
      }
      return [
        ...customOrders,
        CustomOrder(field: "order", direction: SortDirection.asc),
        CustomOrder(field: "created_date", direction: SortDirection.asc),
        CustomOrder(field: "id", direction: SortDirection.asc),
      ];
    }

    List<CustomOrder> customOrders = [];

    if (request.groupBy != null) {
      _addCustomOrder(customOrders, request.groupBy!, request);
    }

    if (request.sortBy == null || request.sortBy!.isEmpty) {
      return customOrders.isEmpty ? null : customOrders;
    }

    if (request.sortBy != null) {
      for (var option in request.sortBy!) {
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
      orders.add(CustomOrder(field: "actual_time", direction: option.direction));
    } else if (option.field == HabitSortFields.archivedDate) {
      orders.add(CustomOrder(field: "archived_date", direction: option.direction));
    } else if (option.field == HabitSortFields.tag) {
      // Sort by the best tag (custom order first, then name)
      if (request.customTagSortOrder != null && request.customTagSortOrder!.isNotEmpty) {
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
  Future<List<HabitListItem>> _filterHabitsWithPeriodAwareness(List<HabitListItem> habits, DateTime date) async {
    final filteredHabits = <HabitListItem>[];

    for (final habit in habits) {
      if (habit.type == HabitType.bad || !habit.hasGoal) {
        filteredHabits.add(habit);
        continue;
      }

      final periodStart = date.subtract(Duration(days: habit.periodDays - 1));
      final records = await _habitRecordRepository.getListByHabitIdAndRangeDate(
          habit.id, periodStart, date, 0, habit.targetFrequency);

      final completedCount = records.items.where((record) => record.status == HabitRecordStatus.complete).length;

      if (completedCount < habit.targetFrequency) {
        filteredHabits.add(habit);
      }
    }

    return filteredHabits;
  }
}
