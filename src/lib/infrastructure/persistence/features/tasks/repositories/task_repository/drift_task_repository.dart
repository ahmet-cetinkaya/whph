import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:whph/core/application/features/tasks/models/task_query_filter.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';

import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tasks/utils/task_grouping_helper.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/models/task_with_total_duration.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/core/domain/shared/constants/domain_log_components.dart';
import 'package:whph/core/domain/shared/constants/task_error_ids.dart';
import 'package:whph/core/domain/features/tasks/models/recurrence_configuration.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/task_data_mapper.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/task_query_builder.dart';

@UseRowClass(Task)
class TaskTable extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get parentTaskId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get priority => intEnum<EisenhowerPriority>().nullable()();
  DateTimeColumn get plannedDate => dateTime().nullable()();
  DateTimeColumn get deadlineDate => dateTime().nullable()();
  IntColumn get estimatedTime => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdDate => dateTime()();
  DateTimeColumn get modifiedDate => dateTime().nullable()();
  DateTimeColumn get deletedDate => dateTime().nullable()();
  RealColumn get order => real().withDefault(const Constant(0.0))();

  // Reminder settings
  IntColumn get plannedDateReminderTime =>
      intEnum<ReminderTime>().withDefault(const Constant(0))(); // Default to ReminderTime.none (0)
  IntColumn get deadlineDateReminderTime =>
      intEnum<ReminderTime>().withDefault(const Constant(0))(); // Default to ReminderTime.none (0)
  IntColumn get plannedDateReminderCustomOffset => integer().nullable()();
  IntColumn get deadlineDateReminderCustomOffset => integer().nullable()();

  // Recurrence settings
  IntColumn get recurrenceType =>
      intEnum<RecurrenceType>().withDefault(const Constant(0))(); // Default to RecurrenceType.none (0)
  IntColumn get recurrenceInterval => integer().nullable()();
  TextColumn get recurrenceDaysString => text().nullable()();
  DateTimeColumn get recurrenceStartDate => dateTime().nullable()();
  DateTimeColumn get recurrenceEndDate => dateTime().nullable()();
  IntColumn get recurrenceCount => integer().nullable()();
  TextColumn get recurrenceParentId => text().nullable()();
  TextColumn get recurrenceConfiguration => text().map(const RecurrenceConfigurationConverter()).nullable()();
}

class RecurrenceConfigurationConverter extends TypeConverter<RecurrenceConfiguration, String> {
  const RecurrenceConfigurationConverter();

  @override
  RecurrenceConfiguration fromSql(String fromDb) {
    try {
      return RecurrenceConfiguration.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);
    } on FormatException catch (e, stackTrace) {
      Logger.error(
        'Invalid JSON in recurrence_configuration column - returning safe default. Task ID context not available at this layer [$TaskErrorIds.recurrenceConfigInvalidJson]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      // Return a safe default configuration instead of crashing
      return RecurrenceConfiguration.safeDefault();
    } on TypeError catch (e, stackTrace) {
      Logger.error(
        'Invalid recurrence_configuration data structure - returning safe default [$TaskErrorIds.recurrenceConfigInvalidStructure]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return RecurrenceConfiguration.safeDefault();
    } catch (e, stackTrace) {
      Logger.error(
        'Unexpected error deserializing RecurrenceConfiguration - returning safe default [$TaskErrorIds.recurrenceConfigDeserializeError]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
      return RecurrenceConfiguration.safeDefault();
    }
  }

  @override
  String toSql(RecurrenceConfiguration value) {
    return jsonEncode(value.toJson());
  }
}

class DriftTaskRepository extends DriftBaseRepository<Task, String, TaskTable> implements ITaskRepository {
  static const sortFieldMap = <String, TaskSortFields>{
    'created_date': TaskSortFields.createdDate,
    'deadline_date': TaskSortFields.deadlineDate,
    'total_duration': TaskSortFields.totalDuration,
    'estimated_time': TaskSortFields.estimatedTime,
    'modified_date': TaskSortFields.modifiedDate,
    'planned_date': TaskSortFields.plannedDate,
    'priority': TaskSortFields.priority,
    'title': TaskSortFields.title,
  };

  final TaskDataMapper _mapper = TaskDataMapper();
  final TaskQueryBuilder _queryBuilder = TaskQueryBuilder();

  DriftTaskRepository() : super(AppDatabase.instance(), AppDatabase.instance().taskTable);

  DriftTaskRepository.withDatabase(AppDatabase appDatabase) : super(appDatabase, appDatabase.taskTable);

  @override
  Expression<String> getPrimaryKey(TaskTable t) {
    return t.id;
  }

  /// Override getList to use custom mapper that correctly handles all Task fields including recurrenceParentId
  @override
  Future<PaginatedList<Task>> getList(int pageIndex, int pageSize,
      {bool includeDeleted = false, CustomWhereFilter? customWhereFilter, List<CustomOrder>? customOrder}) async {
    List<String> whereClauses = [
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;

    String? orderByClause = customOrder?.isNotEmpty == true
        ? ' ORDER BY ${customOrder!.map((order) {
            if (order.field == 'title') {
              return '`${order.field}` IS NULL, `${order.field}` COLLATE NOCASE ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
            }
            return '`${order.field}` IS NULL, `${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
          }).join(', ')} '
        : null;

    final query = database.customSelect(
      "SELECT * FROM ${table.actualTableName}${whereClause ?? ''}${orderByClause ?? ''} LIMIT ? OFFSET ?",
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => _convertToQueryVariable(e)),
        Variable.withInt(pageSize),
        Variable.withInt(pageIndex * pageSize)
      ],
      readsFrom: {table},
    );
    final result = await query.get();

    final countQuery = await database.customSelect(
      'SELECT COUNT(*) AS count FROM ${table.actualTableName}${whereClause ?? ''}',
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => _convertToQueryVariable(e)),
      ],
    ).getSingleOrNull();
    final totalCount = countQuery?.data['count'] as int? ?? 0;

    return PaginatedList(
      items: result.map((row) => _mapper.mapTaskFromRow(row.data)).toList(),
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }

  @override
  Future<Task?> getById(String id, {bool includeDeleted = false}) async {
    List<String> whereClauses = [
      'id = ?',
      if (!includeDeleted) 'deleted_date IS NULL',
    ];
    String whereClause = whereClauses.join(' AND ');

    final results = await database.customSelect(
      'SELECT * FROM ${table.actualTableName} WHERE $whereClause',
      variables: [Variable.withString(id.toString())],
      readsFrom: {table},
    ).get();

    if (results.isEmpty) return null;

    // Clean up duplicates in the background (keep the first, delete the rest)
    if (results.length > 1) {
      _cleanupDuplicateTasksInBackground(id, results.skip(1).toList());
    }

    return _mapper.mapTaskFromRow(results.first.data);
  }

  Future<void> _cleanupDuplicateTasksInBackground(String taskId, List<QueryRow> duplicatesToDelete) async {
    if (duplicatesToDelete.isEmpty) return;

    try {
      final rowIds = duplicatesToDelete.map((d) => d.data['rowid'] as int).toList();
      final placeholders = List.filled(rowIds.length, '?').join(',');

      await database.customStatement(
        'DELETE FROM ${table.actualTableName} WHERE rowid IN ($placeholders)',
        rowIds.map((id) => Variable.withInt(id)).toList(),
      );
      Logger.info('Cleaned up ${rowIds.length} duplicate tasks for ID $taskId.');
    } on Exception catch (e, stackTrace) {
      // Log the error but don't throw - this is a background cleanup operation
      Logger.error(
        'Repository: Failed to cleanup duplicate tasks for ID $taskId [$TaskErrorIds.repositoryDuplicateCleanupFailed]',
        error: e,
        stackTrace: stackTrace,
        component: DomainLogComponents.task,
      );
    }
  }

  @override
  Future<List<Task>> getAll({
    List<CustomOrder>? customOrder,
    CustomWhereFilter? customWhereFilter,
    bool includeDeleted = false,
  }) async {
    final allResults = <Task>[];

    // Build the query
    String query = 'SELECT * FROM ${table.actualTableName}';
    final variables = <Variable>[];

    // Add where clause if needed
    if (!includeDeleted || customWhereFilter != null) {
      query += ' WHERE ';

      if (!includeDeleted) {
        query += 'deleted_date IS NULL';

        if (customWhereFilter != null) {
          query += ' AND ${customWhereFilter.query}';
          variables.addAll(customWhereFilter.variables.map((e) => _convertToQueryVariable(e)));
        }
      } else if (customWhereFilter != null) {
        query += customWhereFilter.query;
        variables.addAll(customWhereFilter.variables.map((e) => _convertToQueryVariable(e)));
      }
    }

    // Add order by clause if needed
    if (customOrder != null && customOrder.isNotEmpty) {
      query += ' ORDER BY ';
      query += customOrder.map((order) {
        String collation = (order.field == 'title') ? 'COLLATE NOCASE ' : '';
        return '`${order.field}` IS NULL, `${order.field}` $collation${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
      }).join(', ');
    }

    // Execute the query
    final result = await database
        .customSelect(
          query,
          variables: variables,
          readsFrom: {table},
        )
        .map((row) => _mapper.mapTaskFromRow(row.data))
        .get();

    allResults.addAll(result);
    return allResults;
  }

  // Helper method to convert values to query variables
  Variable<Object> _convertToQueryVariable(dynamic object) {
    if (object is String) {
      return Variable.withString(object);
    } else if (object is int) {
      return Variable.withInt(object);
    } else if (object is double) {
      return Variable.withReal(object);
    } else if (object is DateTime) {
      return Variable.withDateTime(object);
    } else if (object is bool) {
      return Variable.withBool(object);
    } else {
      throw Exception('Unsupported variable type: ${object.runtimeType}');
    }
  }

  @override
  Future<PaginatedList<TaskWithTotalDuration>> getListWithTotalDuration(
    int pageIndex,
    int pageSize, {
    bool includeDeleted = false,
    CustomWhereFilter? customWhereFilter,
    List<CustomOrder>? customOrder,
  }) async {
    List<String> whereClauses = [
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'task_table.deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;

    String? orderByClause = _queryBuilder.buildOrderByClause(customOrder);

    final baseQuery = '''
      ${TaskQueryBuilder.selectClauseWithDuration}
      ${whereClause ?? ''}
      ${orderByClause ?? ''}
      LIMIT ? OFFSET ?
    ''';

    final query = database.customSelect(
      baseQuery,
      variables: [
        if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => _convertToQueryVariable(e)),
        Variable.withInt(pageSize),
        Variable.withInt(pageIndex * pageSize)
      ],
      readsFrom: {table, database.taskTimeRecordTable},
    );

    final result = await query.get();

    // Count total records (without pagination)
    final countQuery = '''
      SELECT COUNT(*) as count 
      FROM ${table.actualTableName} task_table
      ${whereClause ?? ''}
    ''';
    final count = await database.customSelect(
      countQuery,
      variables: [if (customWhereFilter != null) ...customWhereFilter.variables.map((e) => _convertToQueryVariable(e))],
    ).getSingleOrNull();
    final totalCount = count?.data['count'] as int? ?? 0;

    final items = result.map((row) => _mapToTaskWithTotalDuration(row.data)).toList();

    return PaginatedList(
      items: items,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }

  @override
  Future<List<Task>> getByParentTaskId(String parentTaskId) async {
    final result = await database.customSelect(
      'SELECT * FROM ${table.actualTableName} WHERE parent_task_id = ? AND deleted_date IS NULL',
      variables: [Variable.withString(parentTaskId)],
      readsFrom: {table},
    ).get();

    return result.map((row) => _mapper.mapTaskFromRow(row.data)).toList();
  }

  @override
  Future<PaginatedList<TaskWithTotalDuration>> getListWithOptions({
    required int pageIndex,
    required int pageSize,
    TaskQueryFilter? filter,
    bool includeDeleted = false,
  }) async {
    final f = filter ?? const TaskQueryFilter();
    final conditions = <String>[];
    final variables = <Variable>[];

    // Build tag filter
    final tagResult = _queryBuilder.buildTagCondition(
      filterByTags: f.tags,
      filterNoTags: f.noTags,
    );
    if (tagResult.condition != '1=1') {
      conditions.add(tagResult.condition);
      variables.addAll(tagResult.variables);
    }

    // Exclude tasks only if ALL their tags are archived
    if (!f.ignoreArchivedTagVisibility) {
      conditions.add(_queryBuilder.buildArchivedTagVisibilityCondition());
    }

    // Completed date range filter
    final completedDateResult = _queryBuilder.buildCompletedDateRangeCondition(
      filterByCompletedStartDate: f.completedStartDate,
      filterByCompletedEndDate: f.completedEndDate,
    );
    if (completedDateResult.condition != '1=1') {
      conditions.add(completedDateResult.condition);
      variables.addAll(completedDateResult.variables);
    }

    if (f.includeParentAndSubTasks) {
      // Complex case: include both parent tasks and subtasks with filters applied to both
      final dateResult = _queryBuilder.buildDateCondition(
        filterByPlannedStartDate: f.plannedStartDate,
        filterByPlannedEndDate: f.plannedEndDate,
        filterByDeadlineStartDate: f.deadlineStartDate,
        filterByDeadlineEndDate: f.deadlineEndDate,
        filterDateOr: f.dateOr,
        areParentAndSubTasksIncluded: true,
        includeNullDates: f.includeNullDates,
      );

      final searchResult = _queryBuilder.buildSearchCondition(
        filterBySearch: f.search,
        areParentAndSubTasksIncluded: true,
      );
      final completionResult = _queryBuilder.buildCompletionCondition(
        filterByCompleted: f.completed,
        areParentAndSubTasksIncluded: true,
      );

      final parentSubtaskResult = _queryBuilder.buildParentAndSubtaskFilterCondition(
        searchCondition: searchResult.condition,
        dateCondition: dateResult.condition,
        completedCondition: completionResult.condition,
        searchVariables: searchResult.variables,
        dateVariables: dateResult.variables,
        completedVariables: completionResult.variables,
        filterByTags: f.tags,
      );

      conditions.add(parentSubtaskResult.condition);
      variables.addAll(parentSubtaskResult.variables);
    } else {
      // Simple case: only parent tasks or only subtasks with filters applied to the main task
      final dateResult = _queryBuilder.buildDateCondition(
        filterByPlannedStartDate: f.plannedStartDate,
        filterByPlannedEndDate: f.plannedEndDate,
        filterByDeadlineStartDate: f.deadlineStartDate,
        filterByDeadlineEndDate: f.deadlineEndDate,
        filterDateOr: f.dateOr,
        areParentAndSubTasksIncluded: false,
        includeNullDates: f.includeNullDates,
      );

      if (dateResult.condition != '1=1') {
        conditions.add(dateResult.condition);
        variables.addAll(dateResult.variables);
      }

      final searchResult = _queryBuilder.buildSearchCondition(filterBySearch: f.search);
      if (searchResult.condition != '1=1') {
        conditions.add(searchResult.condition);
        variables.addAll(searchResult.variables);
      }

      // Completed filter
      if (f.completed != null) {
        conditions.add(f.completed! ? 'task_table.completed_at IS NOT NULL' : 'task_table.completed_at IS NULL');
      }

      // Parent task filter
      if (f.parentTaskId != null) {
        conditions.add('task_table.parent_task_id = ?');
        variables.add(Variable.withString(f.parentTaskId!));
      } else {
        conditions.add('task_table.parent_task_id IS NULL');
      }
    }

    if (!includeDeleted) {
      conditions.add('task_table.deleted_date IS NULL');
    }

    String? whereClause = conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')} " : null;
    String? orderByClause = _queryBuilder.buildOrderByClause(f.sortBy, useCustomSort: f.sortByCustomSort);

    final baseQuery = '''
      ${TaskQueryBuilder.selectClauseWithDuration}
      ${whereClause ?? ''}
      ${orderByClause ?? ''}
      LIMIT ? OFFSET ?
    ''';

    final query = database.customSelect(
      baseQuery,
      variables: [...variables, Variable.withInt(pageSize), Variable.withInt(pageIndex * pageSize)],
      readsFrom: {table, database.taskTimeRecordTable},
    );

    final result = await query.get();

    // Count total records (without pagination)
    final countQuery = '''
      SELECT COUNT(*) as count 
      FROM ${table.actualTableName} task_table
      ${whereClause ?? ''}
    ''';
    final count = await database
        .customSelect(
          countQuery,
          variables: variables,
        )
        .getSingleOrNull();
    final totalCount = count?.data['count'] as int? ?? 0;

    final items = result.map((row) => _mapToTaskWithTotalDuration(row.data)).toList();

    return PaginatedList(
      items: items,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }

  /// Helper to map row data to TaskWithTotalDuration.
  TaskWithTotalDuration _mapToTaskWithTotalDuration(Map<String, dynamic> data) {
    final taskData = Map<String, dynamic>.from(data);
    final totalDuration = taskData['total_duration'] as int? ?? 0;
    taskData.remove('total_duration');

    final task = _mapper.mapTaskFromRow(taskData);
    return TaskWithTotalDuration(
      id: task.id,
      title: task.title,
      totalDuration: totalDuration,
      priority: task.priority,
      plannedDate: task.plannedDate,
      deadlineDate: task.deadlineDate,
      completedAt: task.completedAt,
      estimatedTime: task.estimatedTime,
      parentTaskId: task.parentTaskId,
      order: task.order,
      plannedDateReminderTime: task.plannedDateReminderTime,
      plannedDateReminderCustomOffset: task.plannedDateReminderCustomOffset,
      deadlineDateReminderTime: task.deadlineDateReminderTime,
      deadlineDateReminderCustomOffset: task.deadlineDateReminderCustomOffset,
      recurrenceEndDate: task.recurrenceEndDate,
      recurrenceCount: task.recurrenceCount,
      recurrenceParentId: task.recurrenceParentId,
      recurrenceConfiguration: task.recurrenceConfiguration,
      createdDate: task.createdDate,
      modifiedDate: task.modifiedDate,
      deletedDate: task.deletedDate,
    );
  }

  @override
  Future<PaginatedList<TaskWithTotalDuration>> getListWithFilter({
    required int pageIndex,
    required int pageSize,
    TaskQueryFilter? filter,
    bool includeDeleted = false,
  }) {
    return getListWithOptions(
      pageIndex: pageIndex,
      pageSize: pageSize,
      filter: filter,
      includeDeleted: includeDeleted,
    );
  }

  @override
  Future<List<Task>> getByRecurrenceParentId(String recurrenceParentId) async {
    final result = await database.customSelect(
      'SELECT * FROM ${table.actualTableName} WHERE recurrence_parent_id = ? AND deleted_date IS NULL',
      variables: [Variable.withString(recurrenceParentId)],
      readsFrom: {table},
    ).get();

    return result.map((row) => _mapper.mapTaskFromRow(row.data)).toList();
  }

  @override
  Insertable<Task> toCompanion(Task entity) {
    return _mapper.toCompanion(entity);
  }

  @override
  Future<PaginatedList<TaskListItem>> getListWithDetails({
    required int pageIndex,
    required int pageSize,
    TaskQueryFilter? filter,
    bool includeDeleted = false,
  }) async {
    // 1. Fetch Request Page
    final tasksWithDuration = await getListWithOptions(
        pageIndex: pageIndex, pageSize: pageSize, filter: filter, includeDeleted: includeDeleted);

    if (tasksWithDuration.items.isEmpty) {
      return PaginatedList(
          items: [], totalItemCount: tasksWithDuration.totalItemCount, pageIndex: pageIndex, pageSize: pageSize);
    }

    final taskIds = tasksWithDuration.items.map((e) => e.id).toList();

    // 2. Batch Fetch Tags (efficient IN clause)
    // Manually constructed query to avoid N+1 calls
    final tagsQuery = database.customSelect(
      '''
      SELECT tt.task_id, t.id, t.name, t.color, t.is_archived
      FROM task_tag_table tt
      INNER JOIN tag_table t ON tt.tag_id = t.id
      WHERE tt.task_id IN (${taskIds.map((_) => '?').join(',')})
      AND tt.deleted_date IS NULL
      AND (t.deleted_date IS NULL)
      ''',
      variables: taskIds.map((e) => Variable.withString(e)).toList(),
      readsFrom: {database.taskTagTable, database.tagTable},
    );
    final tagsResult = await tagsQuery.get();

    final tagsMap = <String, List<TagListItem>>{};
    for (final row in tagsResult) {
      final taskId = row.read<String>('task_id');
      final tagItem = TagListItem(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        color: row.read<String?>('color'),
        isArchived: row.read<bool>('is_archived'),
      );
      tagsMap.putIfAbsent(taskId, () => []).add(tagItem);
    }

    // 3. Batch Fetch Subtasks
    final subtasksQuery = database.customSelect(
      'SELECT * FROM ${table.actualTableName} WHERE parent_task_id IN (${taskIds.map((_) => '?').join(',')}) AND deleted_date IS NULL',
      variables: taskIds.map((e) => Variable.withString(e)).toList(),
      readsFrom: {table},
    );
    final subtasksResult = await subtasksQuery.get();
    final allSubtasks = subtasksResult.map((row) => _mapper.mapTaskFromRow(row.data)).toList();

    // 4. Batch Fetch Subtask Durations
    final subtaskIds = allSubtasks.map((e) => e.id).toList();
    final subtaskDurationsMap = <String, int>{};
    if (subtaskIds.isNotEmpty) {
      final durationQuery = database.customSelect(
          '''
         SELECT task_id, SUM(duration) as total_duration 
         FROM task_time_record_table 
         WHERE task_id IN (${subtaskIds.map((_) => '?').join(',')})
         AND deleted_date IS NULL
         GROUP BY task_id
         ''',
          variables: subtaskIds.map((e) => Variable.withString(e)).toList(),
          readsFrom: {database.taskTimeRecordTable});
      final durationResult = await durationQuery.get();
      for (final row in durationResult) {
        subtaskDurationsMap[row.read<String>('task_id')] = row.read<int>('total_duration');
      }
    }

    // Group Subtasks
    final subtasksMap = <String, List<TaskListItem>>{};
    for (final subtask in allSubtasks) {
      final parentId = subtask.parentTaskId;
      if (parentId == null) continue;

      final duration = subtaskDurationsMap[subtask.id] ?? 0;

      final subItem = TaskListItem(
          id: subtask.id,
          title: subtask.title,
          priority: subtask.priority,
          isCompleted: subtask.isCompleted,
          plannedDate: subtask.plannedDate,
          deadlineDate: subtask.deadlineDate,
          estimatedTime: subtask.estimatedTime,
          totalElapsedTime: duration,
          parentTaskId: subtask.parentTaskId,
          order: subtask.order,
          plannedDateReminderTime: subtask.plannedDateReminderTime,
          deadlineDateReminderTime: subtask.deadlineDateReminderTime);
      subtasksMap.putIfAbsent(parentId, () => []).add(subItem);
    }

    // 5. Construct Final List
    TaskSortFields? primarySortField;
    if (filter?.sortBy != null && filter!.sortBy!.isNotEmpty) {
      primarySortField = sortFieldMap[filter.sortBy!.first.field];
    }

    final detailedItems = tasksWithDuration.items.map((task) {
      final subTasksList = subtasksMap[task.id] ?? [];

      double subTasksCompletionPercentage = 0;
      if (subTasksList.isNotEmpty) {
        final completed = subTasksList.where((s) => s.isCompleted).length;
        subTasksCompletionPercentage = (completed / subTasksList.length) * 100;
      }

      final tItem = TaskListItem(
        id: task.id,
        title: task.title,
        priority: task.priority,
        // Assuming TaskWithTotalDuration has completedAt and logic for isCompleted
        isCompleted: task.completedAt != null,
        plannedDate: task.plannedDate,
        deadlineDate: task.deadlineDate,
        modifiedDate: task.modifiedDate,
        createdDate: task.createdDate,
        tags: tagsMap[task.id] ?? [],
        estimatedTime: task.estimatedTime,
        totalElapsedTime: task.totalDuration,
        parentTaskId: task.parentTaskId,
        subTasksCompletionPercentage: subTasksCompletionPercentage,
        order: task.order,
        subTasks: subTasksList,
        plannedDateReminderTime: task.plannedDateReminderTime,
        deadlineDateReminderTime: task.deadlineDateReminderTime,
      );

      // Add grouping
      final groupName =
          filter?.enableGrouping == true ? TaskGroupingHelper.getGroupName(tItem, primarySortField) : null;

      return tItem.copyWith(groupName: groupName);
    }).toList();

    return PaginatedList(
        items: detailedItems,
        totalItemCount: tasksWithDuration.totalItemCount,
        pageIndex: pageIndex,
        pageSize: pageSize);
  }
}
