import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_draft.dart';

void main() {
  group('TaskDraft', () {
    test('default-constructed draft is empty', () {
      const draft = TaskDraft();
      expect(draft.title, isNull);
      expect(draft.tagIds, isNull);
      expect(draft.plannedDate, isNull);
      expect(draft.deadlineDate, isNull);
      expect(draft.priority, isNull);
      expect(draft.estimatedTime, isNull);
      expect(draft.completed, isNull);
      expect(draft.parentTaskId, isNull);
      expect(draft.isEmpty, isTrue);
    });

    test('fully populated draft is not empty', () {
      final now = DateTime.utc(2026, 6, 5, 12, 0, 0);
      final draft = TaskDraft(
        title: 'Buy milk',
        tagIds: const ['tag-a'],
        plannedDate: now,
        deadlineDate: now.add(const Duration(days: 1)),
        priority: EisenhowerPriority.urgentImportant,
        estimatedTime: 30,
        completed: false,
        parentTaskId: 'parent-1',
      );
      expect(draft.isEmpty, isFalse);
      expect(draft.title, 'Buy milk');
      expect(draft.priority, EisenhowerPriority.urgentImportant);
    });

    test('explicit empty list counts as a value (clears filter)', () {
      const draft = TaskDraft(tagIds: []);
      expect(draft.isEmpty, isFalse);
      expect(draft.tagIds, isEmpty);
    });

    test('completed=false still counts as a value (avoids overriding default)', () {
      const draft = TaskDraft(completed: false);
      expect(draft.isEmpty, isFalse);
      expect(draft.completed, false);
    });

    test('statusId is nullable and does not affect isEmpty when null', () {
      const draft = TaskDraft(title: 'Test task');
      expect(draft.statusId, isNull);
      expect(draft.isEmpty, isFalse);
    });

    test('statusId with value counts as populated draft', () {
      const draft = TaskDraft(
        title: 'Test task',
        statusId: 'task-status-custom-inprogress',
      );
      expect(draft.statusId, 'task-status-custom-inprogress');
      expect(draft.isEmpty, isFalse);
    });
  });
}
