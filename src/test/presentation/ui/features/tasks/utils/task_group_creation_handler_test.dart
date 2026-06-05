import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_group_creation_handler.dart';

void main() {
  group('TaskGroupCreationHandler.draftForGroup', () {
    const baseInput = TaskGroupCreationInput(
      groupKey: '',
      groupField: null,
      searchQuery: 'searched title',
    );

    test('priority group maps to Eisenhower priority', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.priority, EisenhowerPriority.urgentImportant);
      expect(draft.title, 'searched title');
    });

    test('priority group falls through to null priority on unknown key', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'bogus',
        groupField: TaskSortFields.priority,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.priority, isNull);
    });

    test('planned date group maps to plannedDate', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.today,
        groupField: TaskSortFields.plannedDate,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.plannedDate, isNotNull);
    });

    test('planned date group returns null on unrecognized key', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'mystery-bucket',
        groupField: TaskSortFields.plannedDate,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('deadline date group maps to deadlineDate', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.tomorrow,
        groupField: TaskSortFields.deadlineDate,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.deadlineDate, isNotNull);
    });

    test('deadline date group returns null on unrecognized key', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'who-knows',
        groupField: TaskSortFields.deadlineDate,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('completedDate group maps completed flag', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.today,
        groupField: TaskSortFields.completedDate,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.completed, isNotNull);
    });

    test('estimatedTime group maps minutes', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.durationLessThan15Min,
        groupField: TaskSortFields.estimatedTime,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.estimatedTime, isNotNull);
    });

    test('estimatedTime group returns null on unrecognized key', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'eternity',
        groupField: TaskSortFields.estimatedTime,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('tag "None" group yields an empty-tags draft', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: SharedTranslationKeys.none,
        groupField: TaskSortFields.tag,
        input: baseInput,
      );
      expect(draft, isNotNull);
      expect(draft!.tagIds, isEmpty);
    });

    test('tag named group returns null (caller must use async path)', () {
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: 'Inbox',
        groupField: TaskSortFields.tag,
        input: baseInput,
      );
      expect(draft, isNull);
    });

    test('showNoTagsFilter forces empty tagIds for non-tag groups', () {
      const input = TaskGroupCreationInput(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        searchQuery: null,
        defaultTagIds: const ['fallback'],
        showNoTagsFilter: true,
      );
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        input: input,
      );
      expect(draft, isNotNull);
      expect(draft!.tagIds, isEmpty);
    });

    test('parentTaskId is propagated', () {
      const input = TaskGroupCreationInput(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        parentTaskId: 'parent-7',
      );
      final draft = TaskGroupCreationHandler.draftForGroup(
        groupKey: TaskTranslationKeys.priorityUrgentImportant,
        groupField: TaskSortFields.priority,
        input: input,
      );
      expect(draft, isNotNull);
      expect(draft!.parentTaskId, 'parent-7');
    });

    test('title/created/modified groups are unsupported and return null', () {
      for (final field in [
        TaskSortFields.title,
        TaskSortFields.createdDate,
        TaskSortFields.modifiedDate,
        TaskSortFields.totalDuration,
      ]) {
        final draft = TaskGroupCreationHandler.draftForGroup(
          groupKey: 'anything',
          groupField: field,
          input: baseInput,
        );
        expect(draft, isNull, reason: 'field=$field should yield null draft');
      }
    });
  });
}
