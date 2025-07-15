import 'package:drift/drift.dart';
import 'package:whph/src/core/application/features/tasks/services/abstraction/i_task_repository.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/src/core/domain/features/tasks/models/task_with_total_duration.dart';
import 'package:whph/src/infrastructure/persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:whph/src/infrastructure/persistence/shared/repositories/drift/drift_base_repository.dart';

@UseRowClass(Task)
class TaskTable extends Table {
  TextColumn get id => text()();
  TextColumn get parentTaskId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get priority => intEnum<EisenhowerPriority>().nullable()();
  DateTimeColumn get plannedDate => dateTime().nullable()();
  DateTimeColumn get deadlineDate => dateTime().nullable()();
  IntColumn get estimatedTime => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
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

    final result = await database.customSelect(
      'SELECT * FROM ${table.actualTableName} WHERE $whereClause',
      variables: [Variable.withString(id.toString())],
      readsFrom: {table},
    ).getSingleOrNull();

    if (result == null) return null;

    return _mapTaskFromRow(result.data);
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

    // Helper function to convert to bool
    bool convertToBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
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
      isCompleted: convertToBool(data['is_completed']),
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
      if (customWhereFilter != null) "(${customWhereFilter.query})",
      if (!includeDeleted) 'task_table.deleted_date IS NULL',
    ];
    String? whereClause = whereClauses.isNotEmpty ? " WHERE ${whereClauses.join(' AND ')} " : null;

    String? orderByClause = customOrder?.isNotEmpty == true
        ? ' ORDER BY ${customOrder!.map((order) => '`${order.field}` IS NULL, `${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}').join(', ')} '
        : null;

    final baseQuery = '''
      SELECT 
        task_table.*,
        COALESCE(SUM(task_time_record_table.duration), 0) as total_duration
      FROM ${table.actualTableName} task_table
      LEFT JOIN task_time_record_table ON task_table.id = task_time_record_table.task_id 
        AND task_time_record_table.deleted_date IS NULL
      ${whereClause ?? ''}
      GROUP BY task_table.id
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
        isCompleted: task.isCompleted,
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
      isCompleted: Value(entity.isCompleted),
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
}
