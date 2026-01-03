import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/features/tasks/utils/task_grouping_helper.dart';
import 'package:whph/core/application/features/tasks/models/task_list_item.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/domain/features/tasks/task.dart';

void main() {
  group('TaskGroupingHelper', () {
    final baseTask = TaskListItem(
      id: '1',
      title: 'Test Task',
      priority: EisenhowerPriority.notUrgentNotImportant,
      isCompleted: false,
    );

    test('returns null when sortField is null', () {
      expect(TaskGroupingHelper.getGroupName(baseTask, null), isNull);
    });

    group('Date Grouping', () {
      test('returns Overdue for past dates', () {
        final task = baseTask.copyWith(
          plannedDate: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(
            TaskGroupingHelper.getGroupName(task, TaskSortFields.plannedDate), equals(SharedTranslationKeys.overdue));
      });

      test('returns Today for today', () {
        final task = baseTask.copyWith(
          plannedDate: DateTime.now(),
        );
        expect(TaskGroupingHelper.getGroupName(task, TaskSortFields.plannedDate), equals(SharedTranslationKeys.today));
      });

      test('returns Tomorrow for tomorrow', () {
        final task = baseTask.copyWith(
          plannedDate: DateTime.now().add(const Duration(days: 1)),
        );
        expect(
            TaskGroupingHelper.getGroupName(task, TaskSortFields.plannedDate), equals(SharedTranslationKeys.tomorrow));
      });

      test('returns Next 7 Days for dates within week', () {
        final task = baseTask.copyWith(
          plannedDate: DateTime.now().add(const Duration(days: 3)),
        );
        expect(
            TaskGroupingHelper.getGroupName(task, TaskSortFields.plannedDate), equals(SharedTranslationKeys.next7Days));
      });

      test('returns Future for distant future dates', () {
        final task = baseTask.copyWith(
          plannedDate: DateTime.now().add(const Duration(days: 10)),
        );
        expect(TaskGroupingHelper.getGroupName(task, TaskSortFields.plannedDate), equals(SharedTranslationKeys.future));
      });

      test('returns No Date when date is null', () {
        final task = baseTask.copyWith(plannedDate: null);
        expect(TaskGroupingHelper.getGroupName(task, TaskSortFields.plannedDate), equals(SharedTranslationKeys.noDate));
      });
    });

    group('Priority Grouping', () {
      test('returns correct priority keys', () {
        expect(
          TaskGroupingHelper.getGroupName(
            baseTask.copyWith(priority: EisenhowerPriority.urgentImportant),
            TaskSortFields.priority,
          ),
          equals(TaskTranslationKeys.priorityUrgentImportant),
        );

        expect(
          TaskGroupingHelper.getGroupName(
            baseTask.copyWith(priority: EisenhowerPriority.notUrgentNotImportant),
            TaskSortFields.priority,
          ),
          equals(TaskTranslationKeys.priorityNotUrgentNotImportant),
        );
      });
    });

    group('Title Grouping', () {
      test('returns first letter for titles', () {
        expect(
          TaskGroupingHelper.getGroupName(
            baseTask.copyWith(title: 'Apple'),
            TaskSortFields.title,
          ),
          equals('A'),
        );
      });

      test('returns # for non-letter titles', () {
        expect(
          TaskGroupingHelper.getGroupName(
            baseTask.copyWith(title: '123 Task'),
            TaskSortFields.title,
          ),
          equals('#'),
        );
      });
    });
  });
}
