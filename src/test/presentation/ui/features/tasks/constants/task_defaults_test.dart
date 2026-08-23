import 'package:acore/acore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_defaults.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_view_mode.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';

SortConfig<TaskSortFields> _listConfig({
  required bool useCustomOrder,
  TaskSortFields? groupField,
}) =>
    SortConfig<TaskSortFields>(
      orderOptions: const [
        SortOptionWithTranslationKey(
          field: TaskSortFields.plannedDate,
          direction: SortDirection.asc,
          translationKey: 'tasks.planned_date',
        ),
      ],
      useCustomOrder: useCustomOrder,
      enableGrouping: groupField != null,
      groupOption: groupField == null
          ? null
          : SortOptionWithTranslationKey(
              field: groupField,
              direction: SortDirection.asc,
              translationKey: 'group.$groupField',
            ),
    );

void main() {
  group('TaskDefaults.sortConfigForViewMode entering board', () {
    test('forces status grouping when the list config had no grouping', () {
      final board = TaskDefaults.sortConfigForViewMode(
        TaskViewMode.board,
        _listConfig(useCustomOrder: false),
      );

      expect(board.enableGrouping, isTrue);
      expect(board.groupOption?.field, TaskSortFields.status);
    });

    test('replaces an enabled NON-status grouping with status grouping', () {
      // Board columns are statuses by definition; a priority grouping carried
      // into board mode would render priority columns instead.
      final board = TaskDefaults.sortConfigForViewMode(
        TaskViewMode.board,
        _listConfig(useCustomOrder: false, groupField: TaskSortFields.priority),
      );

      expect(board.enableGrouping, isTrue);
      expect(board.groupOption?.field, TaskSortFields.status);
    });

    test('replaces a non-status grouping while still preserving custom sort', () {
      final board = TaskDefaults.sortConfigForViewMode(
        TaskViewMode.board,
        _listConfig(useCustomOrder: true, groupField: TaskSortFields.tag),
      );

      expect(board.groupOption?.field, TaskSortFields.status);
      expect(board.useCustomOrder, isTrue);
    });

    test('carries custom sort forward instead of silently switching it off', () {
      final board = TaskDefaults.sortConfigForViewMode(
        TaskViewMode.board,
        _listConfig(useCustomOrder: true),
      );

      // The wholesale boardSorting default hardcodes useCustomOrder: false, which
      // is exactly the silent switch-off this must not reintroduce.
      expect(TaskDefaults.boardSorting.useCustomOrder, isFalse);
      expect(board.useCustomOrder, isTrue);
    });

    test('leaves custom sort off when it was already off', () {
      final board = TaskDefaults.sortConfigForViewMode(
        TaskViewMode.board,
        _listConfig(useCustomOrder: false),
      );

      expect(board.useCustomOrder, isFalse);
    });
  });

  group('TaskDefaults.sortConfigForViewMode leaving board', () {
    test('list mode keeps the user configuration untouched', () {
      final list = _listConfig(useCustomOrder: true, groupField: TaskSortFields.priority);

      expect(TaskDefaults.sortConfigForViewMode(TaskViewMode.list, list), same(list));
    });

    test('calendar mode keeps the user configuration untouched', () {
      final list = _listConfig(useCustomOrder: false);

      expect(TaskDefaults.sortConfigForViewMode(TaskViewMode.calendar, list), same(list));
    });
  });

  group('TaskDefaults.sortConfigForViewMode round trips', () {
    test('list -> board -> list preserves custom sort', () {
      final list = _listConfig(useCustomOrder: true);

      final board = TaskDefaults.sortConfigForViewMode(TaskViewMode.board, list);
      final backToList = TaskDefaults.sortConfigForViewMode(TaskViewMode.list, board);

      expect(backToList.useCustomOrder, isTrue);
    });

    test('list -> board -> list from a non-status grouping preserves custom sort', () {
      final list = _listConfig(useCustomOrder: true, groupField: TaskSortFields.priority);

      final board = TaskDefaults.sortConfigForViewMode(TaskViewMode.board, list);
      final backToList = TaskDefaults.sortConfigForViewMode(TaskViewMode.list, board);

      expect(board.groupOption?.field, TaskSortFields.status);
      expect(backToList.useCustomOrder, isTrue);
    });
  });
}
