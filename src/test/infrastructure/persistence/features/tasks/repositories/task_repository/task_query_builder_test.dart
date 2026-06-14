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

      test('includes task if it or its parent is completed when filterByCompleted is true', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: true,
          areParentAndSubTasksIncluded: true,
        );

        expect(result.condition, contains('task_table.completed_at IS NOT NULL'));
        expect(result.condition, contains('EXISTS(SELECT 1 FROM task_table parent'));
        expect(result.condition, contains('parent.id = task_table.parent_task_id'));
        expect(result.condition, contains('parent.completed_at IS NOT NULL'));
      });

      test('excludes task when its parent is completed when filterByCompleted is false', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: false,
          areParentAndSubTasksIncluded: true,
        );

        // Task itself must be incomplete
        expect(result.condition, contains('task_table.completed_at IS NULL'));
        // Task should be excluded if its parent is completed
        expect(
            result.condition,
            contains(
                'NOT EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.completed_at IS NOT NULL)'));
      });

      test('uses AND logic to exclude children of completed parents when filterByCompleted is false', () {
        final result = builder.buildCompletionCondition(
          filterByCompleted: false,
          areParentAndSubTasksIncluded: true,
        );

        // Task must be incomplete AND parent must not be completed
        expect(result.condition, contains('task_table.completed_at IS NULL'));
        expect(result.condition, contains('AND'));
        expect(
            result.condition,
            contains(
                'NOT EXISTS(SELECT 1 FROM task_table parent WHERE parent.id = task_table.parent_task_id AND parent.completed_at IS NOT NULL)'));
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
