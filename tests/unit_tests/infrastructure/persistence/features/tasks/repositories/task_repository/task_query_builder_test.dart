import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_persistence/features/tasks/repositories/task_repository/task_query_builder.dart';
import 'package:acore/acore.dart';

void main() {
  group('TaskQueryBuilder', () {
    final builder = TaskQueryBuilder();

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
