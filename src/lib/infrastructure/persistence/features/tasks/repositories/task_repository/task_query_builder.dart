import 'package:drift/drift.dart';
import 'package:acore/acore.dart' show CustomOrder, SortDirection;
import 'package:whph/core/application/shared/utils/validation_utils.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

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
      task_table.status_id,
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

  String? buildOrderByClause(List<CustomOrder>? customOrder,
      {bool useCustomSort = false, List<String>? customTagSortOrder}) {
    if (customOrder == null || customOrder.isEmpty) return null;

    return ' ORDER BY ${customOrder.map((order) {
      if (order.field == 'total_duration') {
        return '`${order.field}` IS NULL, `${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
      }
      if (order.field == 'title') {
        return 'task_table.`${order.field}` IS NULL, task_table.`${order.field}` COLLATE NOCASE ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
      }
      if (order.field == 'status') {
        // Sort by status order: todo first, custom statuses by order, done last
        // For null status_id (legacy tasks), treat them as todo
        return '''CASE
          WHEN task_table.status_id IS NULL THEN 0
          WHEN task_table.status_id = 'task-status-builtin-todo' THEN 0
          WHEN task_table.status_id = 'task-status-builtin-done' THEN 9999
          ELSE (
            SELECT COALESCE(ss."order", 1000)
            FROM task_status_table ss
            WHERE ss.id = task_table.status_id
            AND ss.deleted_date IS NULL
            LIMIT 1
          )
        END ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}, task_table.id ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}''';
      }
      if (order.field == 'tag') {
        if (customTagSortOrder == null || customTagSortOrder.isEmpty) {
          // Default tag sort (alphabetical by name of first tag)
          // This subquery gets the name of the "first" tag (alphabetically)
          final tagSubquery = '''(
            SELECT t.name 
            FROM task_tag_table tt 
            INNER JOIN tag_table t ON tt.tag_id = t.id 
            WHERE tt.task_id = task_table.id 
            AND tt.deleted_date IS NULL
            ORDER BY tt.tag_order ASC, t.name COLLATE NOCASE ASC 
            LIMIT 1
          )''';
          return '$tagSubquery IS NULL, $tagSubquery ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
        } else {
          // Custom tag sort
          // Construct CASE statement for user defined order
          final caseStatements = StringBuffer();
          for (int i = 0; i < customTagSortOrder.length; i++) {
            try {
              // Validate and sanitize ID to prevent SQL injection
              final safeId = sanitizeAndValidateId(customTagSortOrder[i]);
              caseStatements.write("WHEN '$safeId' THEN $i ");
            } catch (e, stackTrace) {
              Logger.error(
                'Invalid tag ID at index $i: ${customTagSortOrder[i]}',
                error: e,
                stackTrace: stackTrace,
              );
            }
          }

          if (caseStatements.isEmpty) {
            Logger.warning('All custom tag IDs were invalid, falling back to default tag sort.');
            final tagSubquery = '''(
              SELECT t.name 
              FROM task_tag_table tt 
              INNER JOIN tag_table t ON tt.tag_id = t.id 
              WHERE tt.task_id = task_table.id 
              AND tt.deleted_date IS NULL
              ORDER BY tt.tag_order ASC, t.name COLLATE NOCASE ASC 
              LIMIT 1
            )''';
            return '$tagSubquery IS NULL, $tagSubquery ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
          }

          final customTagSubquery = '''(
            SELECT MIN(CASE tt.tag_id 
              $caseStatements
              ELSE 999999 
            END) 
            FROM task_tag_table tt 
            WHERE tt.task_id = task_table.id 
            AND tt.deleted_date IS NULL
          )''';
          return '$customTagSubquery IS NULL, $customTagSubquery ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
        }
      }
      return 'task_table.`${order.field}` IS NULL, task_table.`${order.field}` ${order.direction == SortDirection.asc ? 'ASC' : 'DESC'}';
    }).join(', ')} ';
  }

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

  QueryConditionResult buildCompletionCondition({
    bool? filterByCompleted,
    required bool areParentAndSubTasksIncluded,
  }) {
    final variables = <Variable>[];

    if (filterByCompleted == null) return (condition: '1=1', variables: variables);

    try {
      if (areParentAndSubTasksIncluded) {
        // When subtask view is enabled, a task's filter placement depends only on its own completedAt.
        // Subtasks whose parent is completed are also pulled into the completed list so
        // the tree stays together.
        final condition = filterByCompleted
            ? '''(
              task_table.completed_at IS NOT NULL
              OR EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.completed_at IS NOT NULL)
            )'''
            : '''(
              task_table.completed_at IS NULL
              AND NOT EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.completed_at IS NOT NULL)
            )''';

        return (condition: condition, variables: variables);
      } else {
        final condition = filterByCompleted ? 'task_table.completed_at IS NOT NULL' : 'task_table.completed_at IS NULL';
        return (condition: condition, variables: variables);
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to build completion condition', error: e, stackTrace: stackTrace);
      final condition = filterByCompleted ? 'task_table.completed_at IS NOT NULL' : 'task_table.completed_at IS NULL';
      return (condition: condition, variables: variables);
    }
  }

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
