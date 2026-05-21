import 'package:flutter_test/flutter_test.dart';
import 'package:whph/infrastructure/persistence/features/tasks/repositories/task_repository/task_query_builder.dart';
import 'package:acore/acore.dart';

void main() {
  group('TaskQueryBuilder', () {
    final builder = TaskQueryBuilder();

    group('buildCompletionCondition', () {
      test('returns neutral condition when filterByCompleted is null', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: null,
          areParentAndSubTasksIncluded: false,
        );

        expect(result.condition, equals('1=1'));
        expect(result.variables, isEmpty);
      });

      test('filters completed tasks when areParentAndSubTasksIncluded is false', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: true,
          areParentAndSubTasksIncluded: false,
        );

        expect(result.condition, contains('task_table.completed_at IS NOT NULL'));
        expect(result.variables, isEmpty);
      });

      test('filters incomplete tasks when areParentAndSubTasksIncluded is false', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: false,
          areParentAndSubTasksIncluded: false,
        );

        expect(result.condition, contains('task_table.completed_at IS NULL'));
        expect(result.variables, isEmpty);
      });

      test('includes parent if any subtask is completed when filterByCompleted is true', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: true,
          areParentAndSubTasksIncluded: true,
        );

        expect(result.condition, contains('task_table.completed_at IS NOT NULL'));
        expect(result.condition, contains('EXISTS(SELECT 1 FROM task_table subtask'));
        expect(result.condition, contains('subtask.completed_at IS NOT NULL'));
        expect(result.condition, contains('EXISTS(SELECT 1 FROM task_table parent'));
      });

      test('excludes parent only when ALL subtasks are completed when filterByCompleted is false', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: false,
          areParentAndSubTasksIncluded: true,
        );

        // Parent must be incomplete
        expect(result.condition, contains('task_table.completed_at IS NULL'));
        // Parent should remain if it has NO subtasks
        expect(result.condition,
            contains('NOT EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id)'));
        // Parent should remain if it has at least one incomplete subtask
        expect(
            result.condition,
            contains(
                'EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND subtask.completed_at IS NULL)'));
        // Parent should be excluded if its parent is completed
        expect(
            result.condition,
            contains(
                'NOT EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.completed_at IS NOT NULL)'));
      });

      test('uses OR logic between no-subtasks and has-incomplete-subtask conditions', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: false,
          areParentAndSubTasksIncluded: true,
        );

        // The two conditions must be OR'd: a parent with no subtasks OR a parent with at least one incomplete subtask
        expect(result.condition, contains('OR'));
        // Both conditions are grouped together in parentheses
        expect(result.condition,
            contains('NOT EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id)'));
        expect(
            result.condition,
            contains(
                'EXISTS(SELECT 1 FROM task_table subtask WHERE subtask.parent_task_id = task_table.id AND subtask.completed_at IS NULL)'));
      });
    });

    test('buildOrderByClause generates default sort for tag when no custom order provided', () {
      final customOrder = [CustomOrder(field: 'tag', direction: SortDirection.asc)];
      final clause = builder.buildOrderByClause(customOrder, customTagSortOrder: null);

      expect(clause, contains('SELECT t.name'));
      expect(clause, contains('FROM task_tag_table tt'));
      expect(clause, contains('INNER JOIN tag_table t ON tt.tag_id = t.id'));
      expect(clause, contains('WHERE tt.task_id = task_table.id'));
      expect(clause, contains('AND tt.deleted_date IS NULL'));
      expect(clause, contains('ORDER BY tt.tag_order ASC, t.name COLLATE NOCASE ASC'));
      expect(clause, contains('LIMIT 1'));
    });

    test('buildOrderByClause generates CASE WHEN sort for tag with custom order', () {
      final customOrder = [CustomOrder(field: 'tag', direction: SortDirection.asc)];
      final customTagOrder = ['tag1', 'tag2', 'tag3'];
      final clause = builder.buildOrderByClause(customOrder, customTagSortOrder: customTagOrder);

      expect(clause, contains('SELECT MIN(CASE tt.tag_id'));
      expect(clause, contains("WHEN 'tag1' THEN 0"));
      expect(clause, contains("WHEN 'tag2' THEN 1"));
      expect(clause, contains("WHEN 'tag3' THEN 2"));
      expect(clause, contains('ELSE 999999'));
      expect(clause, contains('FROM task_tag_table tt'));
    });

    test('buildOrderByClause sanitizes IDs', () {
      final customOrder = [CustomOrder(field: 'tag', direction: SortDirection.asc)];
      final customTagOrder = ["bad'id"];
      final clause = builder.buildOrderByClause(customOrder, customTagSortOrder: customTagOrder);

      expect(clause, contains("WHEN 'badid' THEN 0")); // Quote removed
    });
  });
}
