import 'package:drift/drift.dart';
import 'package:whph/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/models/task_with_total_duration.dart';
import 'package:whph/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';
import 'package:whph/core/shared/utils/logger.dart';

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

  // Recurrence settings
  IntColumn get recurrenceType =>
      intEnum<RecurrenceType>().withDefault(const Constant(0))(); // Default to RecurrenceType.none (0)
  IntColumn get recurrenceInterval => integer().nullable()();
  TextColumn get recurrenceDaysString => text().nullable()();
  DateTimeColumn get recurrenceStartDate => dateTime().nullable()();
  DateTimeColumn get recurrenceEndDate => dateTime().nullable()();
  IntColumn get recurrenceCount => integer().nullable()();
  TextColumn get recurrenceParentId => text().nullable()();
}

class DriftTaskRepository extends DriftBaseRepository<Task, String, TaskTable> implements ITaskRepository {
  DriftTaskRepository() : super(AppDatabase.instance(), AppDatabase.instance().taskTable);

  DriftTaskRepository.withDatabase(AppDatabase appDatabase) : super(appDatabase, appDatabase.taskTable);

  @override
  Expression<String> getPrimaryKey(TaskTable t) {
    return t.id;
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

    return _mapTaskFromRow(results.first.data);
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
    } catch (e) {
      // Log the error but don't throw - this is a background cleanup operation
      Logger.warning('Failed to cleanup duplicate tasks for ID $taskId: $e');
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
      query += customOrder
          .map((order) =>
              '`${order.field}` IS NULL, `${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}')
          .join(', ');
    }

    // Execute the query
    final result = await database
        .customSelect(
          query,
          variables: variables,
          readsFrom: {table},
        )
        .map((row) => _mapTaskFromRow(row.data))
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

  // Custom mapping method to handle enum values correctly
  Task _mapTaskFromRow(Map<String, dynamic> data) {
    // Handle DateTime conversions safely
    DateTime? convertToDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toUtc(); // Ensure UTC format
      if (value is int) {
        // Drift stores dates as seconds since epoch, not milliseconds
        // Multiply by 1000 to convert seconds to milliseconds
        // Always use UTC timezone for storage
        return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
      }
      if (value is String) {
        // Try to parse ISO 8601 string and ensure UTC
        final dateTime = DateTime.tryParse(value);
        return dateTime?.toUtc();
      }
      return null;
    }

    // Convert dates
    final plannedDate = convertToDateTime(data['planned_date']);
    final deadlineDate = convertToDateTime(data['deadline_date']);

    // Create a task with the base data
    final task = Task(
      id: data['id'] as String,
      createdDate: convertToDateTime(data['created_date']) ?? DateTime.now().toUtc(),
      modifiedDate: convertToDateTime(data['modified_date']),
      deletedDate: convertToDateTime(data['deleted_date']),
      title: data['title'] as String,
      description: data['description'] as String?,
      plannedDate: plannedDate,
      deadlineDate: deadlineDate,
      priority: data['priority'] != null ? EisenhowerPriority.values[data['priority'] as int] : null,
      estimatedTime: data['estimated_time'] as int?,
      completedAt: convertToDateTime(data['completed_at']),
      parentTaskId: data['parent_task_id'] as String?,
      order: (data['order'] is num) ? (data['order'] as num).toDouble() : 0.0,
    );

    // Explicitly set reminder values
    if (data['planned_date_reminder_time'] != null) {
      final reminderTimeValue = data['planned_date_reminder_time'] as int;
      if (reminderTimeValue >= 0 && reminderTimeValue < ReminderTime.values.length) {
        task.plannedDateReminderTime = ReminderTime.values[reminderTimeValue];
      }
    }

    if (data['deadline_date_reminder_time'] != null) {
      final reminderTimeValue = data['deadline_date_reminder_time'] as int;
      if (reminderTimeValue >= 0 && reminderTimeValue < ReminderTime.values.length) {
        task.deadlineDateReminderTime = ReminderTime.values[reminderTimeValue];
      }
    }

    // Set recurrence values
    if (data['recurrence_type'] != null) {
      final recurrenceTypeValue = data['recurrence_type'] as int;
      if (recurrenceTypeValue >= 0 && recurrenceTypeValue < RecurrenceType.values.length) {
        task.recurrenceType = RecurrenceType.values[recurrenceTypeValue];
      }
    }

    task.recurrenceInterval = data['recurrence_interval'] as int?;
    task.recurrenceDaysString = data['recurrence_days_string'] as String?;
    task.recurrenceStartDate = convertToDateTime(data['recurrence_start_date']);
    task.recurrenceEndDate = convertToDateTime(data['recurrence_end_date']);
    task.recurrenceCount = data['recurrence_count'] as int?;
    task.recurrenceParentId = data['recurrence_parent_id'] as String?;

    return task;
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
      // NOTE: CustomWhereFilter should use fully qualified column names (e.g., 'task_table.created_date')
      // to avoid ambiguity when referencing columns that exist in both joined tables
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'task_table.deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;

    String? orderByClause = customOrder?.isNotEmpty == true
        ? ' ORDER BY ${customOrder!.map((order) {
            // Handle total_duration which is an alias, not a table column
            if (order.field == 'total_duration') {
              return '`${order.field}` IS NULL, `${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
            }
            return 'task_table.`${order.field}` IS NULL, task_table.`${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
          }).join(', ')} '
        : null;

    final baseQuery = '''
      SELECT 
        task_table.id,
        task_table.parent_task_id,
        task_table.title,
        task_table.description,
        task_table.priority,
        task_table.planned_date,
        task_table.deadline_date,
        task_table.estimated_time,
        task_table.completed_at,
        task_table.created_date,
        task_table.modified_date,
        task_table.deleted_date,
        task_table."order",
        task_table.planned_date_reminder_time,
        task_table.deadline_date_reminder_time,
        task_table.recurrence_type,
        task_table.recurrence_interval,
        task_table.recurrence_days_string,
        task_table.recurrence_start_date,
        task_table.recurrence_end_date,
        task_table.recurrence_count,
        task_table.recurrence_parent_id,
        COALESCE(SUM(task_time_record_table.duration), 0) as total_duration
      FROM ${table.actualTableName} task_table
      LEFT JOIN task_time_record_table ON task_table.id = task_time_record_table.task_id 
        AND task_time_record_table.deleted_date IS NULL
      ${whereClause ?? ''}
      GROUP BY task_table.id, task_table.parent_task_id, task_table.title, task_table.description, task_table.priority, task_table.planned_date, task_table.deadline_date, task_table.estimated_time, task_table.completed_at, task_table.created_date, task_table.modified_date, task_table.deleted_date, task_table."order", task_table.planned_date_reminder_time, task_table.deadline_date_reminder_time, task_table.recurrence_type, task_table.recurrence_interval, task_table.recurrence_days_string, task_table.recurrence_start_date, task_table.recurrence_end_date, task_table.recurrence_count, task_table.recurrence_parent_id
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

    final items = result.map((row) {
      final taskData = Map<String, dynamic>.from(row.data);
      final totalDuration = taskData['total_duration'] as int? ?? 0;
      taskData.remove('total_duration');

      final task = _mapTaskFromRow(taskData);
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
        deadlineDateReminderTime: task.deadlineDateReminderTime,
        createdDate: task.createdDate,
        modifiedDate: task.modifiedDate,
        deletedDate: task.deletedDate,
      );
    }).toList();

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

    return result.map((row) => _mapTaskFromRow(row.data)).toList();
  }

  @override
  Future<PaginatedList<TaskWithTotalDuration>> getListWithOptions({
    required int pageIndex,
    required int pageSize,
    List<String>? filterByTags,
    bool filterNoTags = false,
    DateTime? filterByPlannedStartDate,
    DateTime? filterByPlannedEndDate,
    DateTime? filterByDeadlineStartDate,
    DateTime? filterByDeadlineEndDate,
    bool filterDateOr = false,
    bool? filterByCompleted,
    DateTime? filterByCompletedStartDate,
    DateTime? filterByCompletedEndDate,
    String? filterBySearch,
    String? filterByParentTaskId,
    bool areParentAndSubTasksIncluded = false,
    List<CustomOrder>? sortBy,
    bool sortByCustomSort = false,
    bool ignoreArchivedTagVisibility = false,
    bool includeDeleted = false,
  }) async {
    // Build conditions for the query
    final conditions = <String>[];
    final variables = <Variable>[];

    // Search and date filters - only apply globally when NOT including parent and sub tasks together
    // When including parent and sub tasks, these filters are handled in the parent task filter section below
    if (!areParentAndSubTasksIncluded) {
      // Search filter for non-subtasks case
      if (filterBySearch?.isNotEmpty ?? false) {
        conditions.add('task_table.title LIKE ?');
        variables.add(Variable.withString('%$filterBySearch%'));
      }

      final plannedFilters = <String>[];
      if (filterByPlannedStartDate != null || filterByPlannedEndDate != null) {
        plannedFilters.add('task_table.planned_date >= ? AND task_table.planned_date <= ?');
        variables.add(Variable.withDateTime(filterByPlannedStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByPlannedEndDate ?? DateTime(9999)));
      }
      final deadlineFilters = <String>[];
      if (filterByDeadlineStartDate != null || filterByDeadlineEndDate != null) {
        deadlineFilters.add('task_table.deadline_date >= ? AND task_table.deadline_date <= ?');
        variables.add(Variable.withDateTime(filterByDeadlineStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByDeadlineEndDate ?? DateTime(9999)));
      }
      if (plannedFilters.isNotEmpty || deadlineFilters.isNotEmpty) {
        final joiner = filterDateOr ? ' OR ' : ' AND ';
        final dateBlock = <String>[...plannedFilters, ...deadlineFilters];
        conditions.add('(${dateBlock.join(joiner)})');
      }
    }

    // Tag filter
    if (filterByTags != null && filterByTags.isNotEmpty) {
      final placeholders = List.filled(filterByTags.length, '?').join(',');
      conditions.add(
          '(SELECT COUNT(*) FROM task_tag_table WHERE task_id = task_table.id AND tag_id IN ($placeholders) AND deleted_date IS NULL) > 0');
      variables.addAll(filterByTags.map((tagId) => Variable.withString(tagId)));
    }

    // No tags filter
    if (filterNoTags) {
      conditions
          .add('(SELECT COUNT(*) FROM task_tag_table WHERE task_id = task_table.id AND deleted_date IS NULL) = 0');
    }

    // Exclude tasks only if ALL their tags are archived (show if at least one tag is not archived)
    if (!ignoreArchivedTagVisibility) {
      conditions.add('''
        task_table.id NOT IN (
          SELECT DISTINCT tt1.task_id 
          FROM task_tag_table tt1
          WHERE tt1.deleted_date IS NULL
          AND NOT EXISTS (
            SELECT 1 
            FROM task_tag_table tt2
            INNER JOIN tag_table t ON tt2.tag_id = t.id
            WHERE tt2.task_id = tt1.task_id 
            AND tt2.deleted_date IS NULL
            AND (t.is_archived = 0 OR t.is_archived IS NULL)
          )
        )
      ''');
    }

    // Completed date range filter
    if (filterByCompletedStartDate != null || filterByCompletedEndDate != null) {
      if (filterByCompletedStartDate != null && filterByCompletedEndDate != null) {
        // Convert DateTime to Unix timestamp (seconds) to match database storage format
        conditions.add('task_table.completed_at >= ? AND task_table.completed_at < ?');
        variables.add(Variable.withInt(filterByCompletedStartDate.millisecondsSinceEpoch ~/ 1000));
        // Add one day to end date to include the entire end day
        final nextDay = filterByCompletedEndDate.add(const Duration(days: 1));
        variables.add(Variable.withInt(nextDay.millisecondsSinceEpoch ~/ 1000));
      } else if (filterByCompletedStartDate != null) {
        conditions.add('task_table.completed_at >= ?');
        variables.add(Variable.withInt(filterByCompletedStartDate.millisecondsSinceEpoch ~/ 1000));
      } else if (filterByCompletedEndDate != null) {
        // Include the entire end day by adding one day and using < instead of <=
        conditions.add('task_table.completed_at < ?');
        final nextDay = filterByCompletedEndDate.add(const Duration(days: 1));
        variables.add(Variable.withInt(nextDay.millisecondsSinceEpoch ~/ 1000));
      }
    }

    // Completed filter - apply when NOT including parent and sub tasks together
    if (filterByCompleted != null && !areParentAndSubTasksIncluded) {
      if (filterByCompleted) {
        conditions.add('task_table.completed_at IS NOT NULL');
      } else {
        conditions.add('task_table.completed_at IS NULL');
      }
    }

    // Parent task filter
    if (!areParentAndSubTasksIncluded) {
      if (filterByParentTaskId != null) {
        conditions.add('task_table.parent_task_id = ?');
        variables.add(Variable.withString(filterByParentTaskId));
      } else {
        conditions.add('task_table.parent_task_id IS NULL');
      }
    } else {
      // Complex case: include both parent tasks and subtasks with filters applied to both
      final dateResult = _buildDateCondition(
        filterByPlannedStartDate: filterByPlannedStartDate,
        filterByPlannedEndDate: filterByPlannedEndDate,
        filterByDeadlineStartDate: filterByDeadlineStartDate,
        filterByDeadlineEndDate: filterByDeadlineEndDate,
        filterDateOr: filterDateOr,
        areParentAndSubTasksIncluded: areParentAndSubTasksIncluded,
      );

      final searchResult = _buildSearchCondition(filterBySearch: filterBySearch);
      final completionResult = _buildCompletionCondition(filterByCompleted: filterByCompleted, areParentAndSubTasksIncluded: areParentAndSubTasksIncluded);

      final parentSubtaskCondition = _buildParentAndSubtaskFilterCondition(
        searchCondition: searchResult.condition,
        dateCondition: dateResult.condition,
        completedCondition: completionResult.condition,
        searchVariables: searchResult.variables,
        dateVariables: dateResult.variables,
        completedVariables: completionResult.variables,
        filterByTags: filterByTags,
        variables: variables,
      );

      conditions.add(parentSubtaskCondition);
    }

    if (!includeDeleted) {
      conditions.add('task_table.deleted_date IS NULL');
    }

    String? whereClause = conditions.isNotEmpty ? " WHERE ${conditions.join(' AND ')} " : null;

    // Build order by clause
    String? orderByClause;
    if (sortByCustomSort) {
      orderByClause = ' ORDER BY task_table.`order` IS NULL, task_table.`order` ASC ';
    } else if (sortBy != null && sortBy.isNotEmpty) {
      orderByClause = ' ORDER BY ${sortBy.map((order) {
        // Handle total_duration which is an alias, not a table column
        if (order.field == 'total_duration') {
          return '`${order.field}` IS NULL, `${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
        }
        return 'task_table.`${order.field}` IS NULL, task_table.`${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
      }).join(', ')} ';
    }

    final baseQuery = '''
      SELECT 
        task_table.id,
        task_table.parent_task_id,
        task_table.title,
        task_table.description,
        task_table.priority,
        task_table.planned_date,
        task_table.deadline_date,
        task_table.estimated_time,
        task_table.completed_at,
        task_table.created_date,
        task_table.modified_date,
        task_table.deleted_date,
        task_table."order",
        task_table.planned_date_reminder_time,
        task_table.deadline_date_reminder_time,
        task_table.recurrence_type,
        task_table.recurrence_interval,
        task_table.recurrence_days_string,
        task_table.recurrence_start_date,
        task_table.recurrence_end_date,
        task_table.recurrence_count,
        task_table.recurrence_parent_id,
        COALESCE(SUM(task_time_record_table.duration), 0) as total_duration
      FROM ${table.actualTableName} task_table
      LEFT JOIN task_time_record_table ON task_table.id = task_time_record_table.task_id 
        AND task_time_record_table.deleted_date IS NULL
      ${whereClause ?? ''}
      GROUP BY task_table.id, task_table.parent_task_id, task_table.title, task_table.description, task_table.priority, task_table.planned_date, task_table.deadline_date, task_table.estimated_time, task_table.completed_at, task_table.created_date, task_table.modified_date, task_table.deleted_date, task_table."order", task_table.planned_date_reminder_time, task_table.deadline_date_reminder_time, task_table.recurrence_type, task_table.recurrence_interval, task_table.recurrence_days_string, task_table.recurrence_start_date, task_table.recurrence_end_date, task_table.recurrence_count, task_table.recurrence_parent_id
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

    final items = result.map((row) {
      final taskData = Map<String, dynamic>.from(row.data);
      final totalDuration = taskData['total_duration'] as int? ?? 0;
      taskData.remove('total_duration');

      final task = _mapTaskFromRow(taskData);
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
        deadlineDateReminderTime: task.deadlineDateReminderTime,
        createdDate: task.createdDate,
        modifiedDate: task.modifiedDate,
        deletedDate: task.deletedDate,
      );
    }).toList();

    return PaginatedList(
      items: items,
      pageIndex: pageIndex,
      pageSize: pageSize,
      totalItemCount: totalCount,
    );
  }

  @override
  Future<List<Task>> getByRecurrenceParentId(String recurrenceParentId) async {
    final result = await database.customSelect(
      'SELECT * FROM ${table.actualTableName} WHERE recurrence_parent_id = ? AND deleted_date IS NULL',
      variables: [Variable.withString(recurrenceParentId)],
      readsFrom: {table},
    ).get();

    return result.map((row) => _mapTaskFromRow(row.data)).toList();
  }

  @override
  Insertable<Task> toCompanion(Task entity) {
    // Ensure all DateTime values are in UTC format
    DateTime? plannedDate = entity.plannedDate?.toUtc();
    DateTime? deadlineDate = entity.deadlineDate?.toUtc();
    DateTime? recurrenceStartDate = entity.recurrenceStartDate?.toUtc();
    DateTime? recurrenceEndDate = entity.recurrenceEndDate?.toUtc();

    return TaskTableCompanion.insert(
      id: entity.id,
      parentTaskId: Value(entity.parentTaskId),
      title: entity.title,
      description: Value(entity.description),
      priority: Value(entity.priority),
      plannedDate: Value(plannedDate),
      deadlineDate: Value(deadlineDate),
      estimatedTime: Value(entity.estimatedTime),
      completedAt: Value(entity.completedAt),
      createdDate: entity.createdDate,
      modifiedDate: Value(entity.modifiedDate),
      deletedDate: Value(entity.deletedDate),
      order: Value(entity.order),
      plannedDateReminderTime: Value(entity.plannedDateReminderTime),
      deadlineDateReminderTime: Value(entity.deadlineDateReminderTime),
      recurrenceType: Value(entity.recurrenceType),
      recurrenceInterval: Value(entity.recurrenceInterval),
      recurrenceDaysString: Value(entity.recurrenceDaysString),
      recurrenceStartDate: Value(recurrenceStartDate),
      recurrenceEndDate: Value(recurrenceEndDate),
      recurrenceCount: Value(entity.recurrenceCount),
      recurrenceParentId: Value(entity.recurrenceParentId),
    );
  }

  /// Builds date filter conditions (planned and deadline dates).
  /// Returns tuple of (dateConditionString, List<Variable>).
  ({String condition, List<Variable> variables}) _buildDateCondition({
    DateTime? filterByPlannedStartDate,
    DateTime? filterByPlannedEndDate,
    DateTime? filterByDeadlineStartDate,
    DateTime? filterByDeadlineEndDate,
    required bool filterDateOr,
    required bool areParentAndSubTasksIncluded,
  }) {
    final dateParts = <String>[];
    final variables = <Variable>[];

    if (filterByPlannedStartDate != null || filterByPlannedEndDate != null) {
      if (areParentAndSubTasksIncluded) {
        // For parent and subtasks inclusion, check if the task itself or any of its subtasks or parent match the date filter
        final plannedCondition = '''(
          (task_table.planned_date >= ? AND task_table.planned_date <= ?)
          OR
          EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND (subtask.planned_date >= ? AND subtask.planned_date <= ?))
          OR
          EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND (parent.planned_date >= ? AND parent.planned_date <= ?))
        )''';
        dateParts.add(plannedCondition);
        // Add variables for: task_table, subtask, parent
        variables.add(Variable.withDateTime(filterByPlannedStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByPlannedEndDate ?? DateTime(9999)));
        variables.add(Variable.withDateTime(filterByPlannedStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByPlannedEndDate ?? DateTime(9999)));
        variables.add(Variable.withDateTime(filterByPlannedStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByPlannedEndDate ?? DateTime(9999)));
      } else {
        dateParts.add('task_table.planned_date >= ? AND task_table.planned_date <= ?');
        variables.add(Variable.withDateTime(filterByPlannedStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByPlannedEndDate ?? DateTime(9999)));
      }
    }

    if (filterByDeadlineStartDate != null || filterByDeadlineEndDate != null) {
      if (areParentAndSubTasksIncluded) {
        // For parent and subtasks inclusion, check if the task itself or any of its subtasks or parent match the date filter
        final deadlineCondition = '''(
          (task_table.deadline_date >= ? AND task_table.deadline_date <= ?)
          OR
          EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND (subtask.deadline_date >= ? AND subtask.deadline_date <= ?))
          OR
          EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND (parent.deadline_date >= ? AND parent.deadline_date <= ?))
        )''';
        dateParts.add(deadlineCondition);
        // Add variables for: task_table, subtask, parent
        variables.add(Variable.withDateTime(filterByDeadlineStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByDeadlineEndDate ?? DateTime(9999)));
        variables.add(Variable.withDateTime(filterByDeadlineStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByDeadlineEndDate ?? DateTime(9999)));
        variables.add(Variable.withDateTime(filterByDeadlineStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByDeadlineEndDate ?? DateTime(9999)));
      } else {
        dateParts.add('task_table.deadline_date >= ? AND task_table.deadline_date <= ?');
        variables.add(Variable.withDateTime(filterByDeadlineStartDate ?? DateTime(0)));
        variables.add(Variable.withDateTime(filterByDeadlineEndDate ?? DateTime(9999)));
      }
    }

    final condition = dateParts.isEmpty
        ? '1=1'
        : (dateParts.length == 1 ? dateParts[0] : '(${dateParts.join(filterDateOr ? ' OR ' : ' AND ')})');

    return (condition: condition, variables: variables);
  }

  /// Builds search filter condition.
  /// Returns tuple of (searchConditionString, List<Variable>).
  ({String condition, List<Variable> variables}) _buildSearchCondition({
    String? filterBySearch,
  }) {
    if (filterBySearch?.isNotEmpty ?? false) {
      return (
        condition: '''(task_table.title LIKE ? OR
            EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND subtask.title LIKE ?) OR
            EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.title LIKE ?))''',
        variables: [
          Variable.withString('%$filterBySearch%'),
          Variable.withString('%$filterBySearch%'),
          Variable.withString('%$filterBySearch%'),
        ],
      );
    }
    return (condition: '1=1', variables: <Variable>[]);
  }

  /// Builds completion status filter condition.
  /// Returns tuple of (conditionString, List<Variable>).
  ({String condition, List<Variable> variables}) _buildCompletionCondition({bool? filterByCompleted, required bool areParentAndSubTasksIncluded}) {
    final variables = <Variable>[];
    
    if (filterByCompleted == null) return (condition: '1=1', variables: variables);
    
    if (areParentAndSubTasksIncluded) {
      // For parent and subtasks inclusion, check if the task itself or any of its subtasks or parent is completed
      final condition = filterByCompleted
          ? '''(
            task_table.completed_at IS NOT NULL
            OR EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND subtask.completed_at IS NOT NULL)
            OR EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.completed_at IS NOT NULL)
          )'''
          : '''(
            task_table.completed_at IS NULL
            AND NOT EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND subtask.completed_at IS NOT NULL)
            AND NOT EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.completed_at IS NOT NULL)
          )''';
      
      return (condition: condition, variables: variables);
    } else {
      final condition = filterByCompleted ? 'task_table.completed_at IS NOT NULL' : 'task_table.completed_at IS NULL';
      return (condition: condition, variables: variables);
    }
  }

  /// Builds combined filter condition for parent and subtask queries.
  /// This method consolidates the complex logic for when areParentAndSubTasksIncluded is true.
  String _buildParentAndSubtaskFilterCondition({
    required String searchCondition,
    required String dateCondition,
    required String completedCondition,
    required List<Variable> searchVariables,
    required List<Variable> dateVariables,
    required List<Variable> completedVariables,
    required List<String>? filterByTags,
    required List<Variable> variables,
  }) {
    final conditions = [searchCondition, dateCondition, completedCondition];
    variables
      ..addAll(searchVariables)
      ..addAll(dateVariables)
      ..addAll(completedVariables);

    if (filterByTags != null && filterByTags.isNotEmpty) {
      final tagPlaceholders = List.filled(filterByTags.length, '?').join(',');
      conditions.add(
          '(SELECT COUNT(*) FROM task_tag_table WHERE task_id = task_table.id AND tag_id IN ($tagPlaceholders) AND deleted_date IS NULL) > 0');
      variables.addAll(filterByTags.map((tagId) => Variable.withString(tagId)));
    }

    return '(${conditions.join(' AND ')})';
  }
}
