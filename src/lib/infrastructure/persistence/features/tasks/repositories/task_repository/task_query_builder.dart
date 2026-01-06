import 'package:drift/drift.dart';
import 'package:acore/acore.dart' show CustomOrder, SortDirection;

/// Result type for query condition builders.
typedef QueryConditionResult = ({String condition, List<Variable> variables});

/// Builds SQL query conditions for task filtering operations.
class TaskQueryBuilder {
  /// Common SELECT clause for task queries with total duration.
  static const String selectClauseWithDuration = '''
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
      task_table.planned_date_reminder_custom_offset,
      task_table.deadline_date_reminder_time,
      task_table.deadline_date_reminder_custom_offset,
      task_table.recurrence_type,
      task_table.recurrence_interval,
      task_table.recurrence_days_string,
      task_table.recurrence_start_date,
      task_table.recurrence_end_date,
      task_table.recurrence_count,
      task_table.recurrence_parent_id,
      (SELECT COALESCE(SUM(task_time_record_table.duration), 0)
       FROM task_time_record_table
       WHERE task_time_record_table.task_id = task_table.id
       AND task_time_record_table.deleted_date IS NULL) as total_duration
    FROM task_table
  ''';

  /// Builds ORDER BY clause from custom order list.
  String? buildOrderByClause(List<CustomOrder>? customOrder, {bool useCustomSort = false}) {
    if (customOrder == null || customOrder.isEmpty) return null;

    return ' ORDER BY ${customOrder.map((order) {
      // Handle total_duration which is an alias, not a table column
      if (order.field == 'total_duration') {
        return '`${order.field}` IS NULL, `${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
      }
      if (order.field == 'title') {
        return 'task_table.`${order.field}` IS NULL, task_table.`${order.field}` COLLATE NOCASE ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
      }
      return 'task_table.`${order.field}` IS NULL, task_table.`${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
    }).join(', ')} ';
  }

  /// Builds date filter conditions (planned and deadline dates).
  /// Builds date filter conditions (planned and deadline dates).
  QueryConditionResult buildDateCondition({
    DateTime? filterByPlannedStartDate,
    DateTime? filterByPlannedEndDate,
    DateTime? filterByDeadlineStartDate,
    DateTime? filterByDeadlineEndDate,
    required bool filterDateOr,
    required bool areParentAndSubTasksIncluded,
    bool includeNullDates = false,
  }) {
    final dateParts = <String>[];
    final variables = <Variable>[];

    // Determine strict null handling: if filtering by MULTIPLE fields with OR,
    // "No Date" means ALL of them must be null.
    // If filtering by single field, matching null is lenient (IS NULL).
    final hasPlannedFilter = filterByPlannedStartDate != null || filterByPlannedEndDate != null;
    final hasDeadlineFilter = filterByDeadlineStartDate != null || filterByDeadlineEndDate != null;
    final isMultiFieldOrFilter = hasPlannedFilter && hasDeadlineFilter && filterDateOr;

    // Use "lenient" null checks for individual fields only if we are NOT in the special multi-field OR mode
    // If we ARE in multi-field OR mode, we will append a separate "ALL NULL" condition at the end.
    final bool useIndividualNullCheck = includeNullDates && !isMultiFieldOrFilter;

    if (hasPlannedFilter) {
      if (areParentAndSubTasksIncluded) {
        final plannedCondition = '''(
          ((task_table.planned_date >= ? AND task_table.planned_date <= ?)${useIndividualNullCheck ? ' OR task_table.planned_date IS NULL' : ''})
          OR
          EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND (
            (subtask.planned_date >= ? AND subtask.planned_date <= ?)${useIndividualNullCheck ? ' OR subtask.planned_date IS NULL' : ''}
          ))
          OR
          EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND (
            (parent.planned_date >= ? AND parent.planned_date <= ?)${useIndividualNullCheck ? ' OR parent.planned_date IS NULL' : ''}
          ))
        )''';
        dateParts.add(plannedCondition);
        // Add variables for: task_table, subtask, parent
        final startVar = Variable.withDateTime(filterByPlannedStartDate ?? DateTime(0));
        final endVar = Variable.withDateTime(filterByPlannedEndDate ?? DateTime(9999));
        variables.addAll([startVar, endVar, startVar, endVar, startVar, endVar]);
      } else {
        dateParts.add(useIndividualNullCheck
            ? '(task_table.planned_date IS NULL OR (task_table.planned_date >= ? AND task_table.planned_date <= ?))'
            : 'task_table.planned_date >= ? AND task_table.planned_date <= ?');
        variables.addAll([
          Variable.withDateTime(filterByPlannedStartDate ?? DateTime(0)),
          Variable.withDateTime(filterByPlannedEndDate ?? DateTime(9999))
        ]);
      }
    }

    if (hasDeadlineFilter) {
      if (areParentAndSubTasksIncluded) {
        final deadlineCondition = '''(
          ((task_table.deadline_date >= ? AND task_table.deadline_date <= ?)${useIndividualNullCheck ? ' OR task_table.deadline_date IS NULL' : ''})
          OR
          EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND (
            (subtask.deadline_date >= ? AND subtask.deadline_date <= ?)${useIndividualNullCheck ? ' OR subtask.deadline_date IS NULL' : ''}
          ))
          OR
          EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND (
            (parent.deadline_date >= ? AND parent.deadline_date <= ?)${useIndividualNullCheck ? ' OR parent.deadline_date IS NULL' : ''}
          ))
        )''';
        dateParts.add(deadlineCondition);
        // Add variables for: task_table, subtask, parent
        final startVar = Variable.withDateTime(filterByDeadlineStartDate ?? DateTime(0));
        final endVar = Variable.withDateTime(filterByDeadlineEndDate ?? DateTime(9999));
        variables.addAll([startVar, endVar, startVar, endVar, startVar, endVar]);
      } else {
        dateParts.add(useIndividualNullCheck
            ? '(task_table.deadline_date IS NULL OR (task_table.deadline_date >= ? AND task_table.deadline_date <= ?))'
            : 'task_table.deadline_date >= ? AND task_table.deadline_date <= ?');
        variables.addAll([
          Variable.withDateTime(filterByDeadlineStartDate ?? DateTime(0)),
          Variable.withDateTime(filterByDeadlineEndDate ?? DateTime(9999))
        ]);
      }
    }

    String condition;
    if (dateParts.isEmpty) {
      condition = '1=1';
    } else {
      if (isMultiFieldOrFilter) {
        // Special case: Planned OR Deadline.
        // If includeNullDates is true, we want (PlannedInRange) OR (DeadlineInRange) OR (Planned IS NULL AND Deadline IS NULL).
        final joinedParts = dateParts.join(' OR ');

        if (includeNullDates) {
          if (areParentAndSubTasksIncluded) {
            // For strict null check with hierarchy, valid "Null Task" is one where NEITHER field matches,
            // implying we check if BOTH are null on the SAME entity.
            // This gets complicated with subtasks/parents.
            // Simplification: We add "OR BOTH NULL" for the main task.
            // For subtasks/parents, we assume the same strictness applies.

            // Strict null condition for main task
            const strictNullSelf = '(task_table.planned_date IS NULL AND task_table.deadline_date IS NULL)';

            // Strict null condition for subtasks
            const strictNullSub =
                'EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND subtask.planned_date IS NULL AND subtask.deadline_date IS NULL)';

            // Strict null condition for parent
            const strictNullParent =
                'EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.planned_date IS NULL AND parent.deadline_date IS NULL)';

            condition = '($joinedParts OR $strictNullSelf OR $strictNullSub OR $strictNullParent)';
          } else {
            condition = '($joinedParts OR (task_table.planned_date IS NULL AND task_table.deadline_date IS NULL))';
          }
        } else {
          condition = '($joinedParts)';
        }
      } else {
        // Standard behavior (Single filter OR multiple with AND)
        condition = dateParts.length == 1 ? dateParts[0] : '(${dateParts.join(filterDateOr ? ' OR ' : ' AND ')})';
      }
    }

    return (condition: condition, variables: variables);
  }

  /// Builds search filter condition.
  QueryConditionResult buildSearchCondition({
    String? filterBySearch,
    bool areParentAndSubTasksIncluded = false,
  }) {
    if (filterBySearch?.isNotEmpty ?? false) {
      final searchVar = Variable.withString('%$filterBySearch%');

      if (areParentAndSubTasksIncluded) {
        return (
          condition: '''(task_table.title LIKE ? OR
              EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND subtask.title LIKE ?) OR
              EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.title LIKE ?))''',
          variables: [searchVar, searchVar, searchVar],
        );
      }

      return (
        condition: 'task_table.title LIKE ?',
        variables: [searchVar],
      );
    }
    return (condition: '1=1', variables: <Variable>[]);
  }

  /// Builds completion status filter condition.
  QueryConditionResult buildCompletionCondition({
    bool? filterByCompleted,
    required bool areParentAndSubTasksIncluded,
  }) {
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
  QueryConditionResult buildParentAndSubtaskFilterCondition({
    required String searchCondition,
    required String dateCondition,
    required String completedCondition,
    required List<Variable> searchVariables,
    required List<Variable> dateVariables,
    required List<Variable> completedVariables,
    required List<String>? filterByTags,
  }) {
    final conditions = [searchCondition, dateCondition, completedCondition];
    final variables = <Variable>[...searchVariables, ...dateVariables, ...completedVariables];

    if (filterByTags != null && filterByTags.isNotEmpty) {
      final tagPlaceholders = List.filled(filterByTags.length, '?').join(',');
      conditions.add(
          '(SELECT COUNT(*) FROM task_tag_table WHERE task_id = task_table.id AND tag_id IN ($tagPlaceholders) AND deleted_date IS NULL) > 0');
      variables.addAll(filterByTags.map((tagId) => Variable.withString(tagId)));
    }

    return (condition: '(${conditions.join(' AND ')})', variables: variables);
  }

  /// Builds tag filter condition.
  QueryConditionResult buildTagCondition({
    List<String>? filterByTags,
    bool filterNoTags = false,
  }) {
    final conditions = <String>[];
    final variables = <Variable>[];

    if (filterByTags != null && filterByTags.isNotEmpty) {
      final placeholders = List.filled(filterByTags.length, '?').join(',');
      conditions.add(
          '(SELECT COUNT(*) FROM task_tag_table WHERE task_id = task_table.id AND tag_id IN ($placeholders) AND deleted_date IS NULL) > 0');
      variables.addAll(filterByTags.map((tagId) => Variable.withString(tagId)));
    }

    if (filterNoTags) {
      conditions
          .add('(SELECT COUNT(*) FROM task_tag_table WHERE task_id = task_table.id AND deleted_date IS NULL) = 0');
    }

    if (conditions.isEmpty) {
      return (condition: '1=1', variables: variables);
    }

    return (condition: conditions.join(' AND '), variables: variables);
  }

  /// Builds archived tag visibility condition.
  String buildArchivedTagVisibilityCondition() {
    return '''
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
    ''';
  }

  /// Builds completed date range filter condition.
  QueryConditionResult buildCompletedDateRangeCondition({
    DateTime? filterByCompletedStartDate,
    DateTime? filterByCompletedEndDate,
  }) {
    final conditions = <String>[];
    final variables = <Variable>[];

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

    if (conditions.isEmpty) {
      return (condition: '1=1', variables: variables);
    }

    return (condition: conditions.join(' AND '), variables: variables);
  }
}
