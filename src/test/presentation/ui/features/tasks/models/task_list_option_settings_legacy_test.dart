import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_option_settings.dart';
import 'package:whph/presentation/ui/features/notes/models/note_list_option_settings.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_list_option_settings.dart';

/// `forceOriginalLayout` was removed in favour of `useCustomOrder` as the single
/// control. Settings persisted before that removal still carry the legacy key,
/// so deserialization must ignore it rather than throw, and serialization must
/// never write it back.
void main() {
  group('legacy forceOriginalLayout key', () {
    test('TaskListOptionSettings ignores the legacy key and never rewrites it', () {
      final legacyJson = <String, dynamic>{
        'showNoTagsFilter': false,
        'showCompletedTasks': false,
        'search': null,
        'forceOriginalLayout': true,
        'showSubTasks': false,
        'viewMode': 'list',
        'sortConfig': {
          'orderOptions': [
            {'field': 'createdDate', 'direction': 'desc', 'translationKey': 'shared.created_date'},
          ],
          'useCustomOrder': true,
          'enableGrouping': true,
          'groupOption': {'field': 'status', 'direction': 'asc', 'translationKey': 'tasks.status'},
        },
      };

      final settings = TaskListOptionSettings.fromJson(legacyJson);

      // The legacy key is not honoured: custom sort alone drives the reorder gate.
      expect(settings.sortConfig!.useCustomOrder, isTrue);
      expect(settings.toJson().containsKey('forceOriginalLayout'), isFalse);
    });

    test('HabitListOptionSettings ignores the legacy key and never rewrites it', () {
      final legacyJson = <String, dynamic>{
        'showNoTagsFilter': false,
        'filterByArchived': false,
        'search': null,
        'forceOriginalLayout': true,
        'habitListStyle': 'list',
        'sortConfig': {
          'orderOptions': [
            {'field': 'createdDate', 'direction': 'desc', 'translationKey': 'shared.created_date'},
          ],
          'useCustomOrder': true,
          'enableGrouping': false,
        },
      };

      final settings = HabitListOptionSettings.fromJson(legacyJson);

      expect(settings.sortConfig!.useCustomOrder, isTrue);
      expect(settings.toJson().containsKey('forceOriginalLayout'), isFalse);
    });

    test('NoteListOptionSettings ignores the legacy key and never rewrites it', () {
      final legacyJson = <String, dynamic>{
        'showNoTagsFilter': false,
        'search': null,
        'forceOriginalLayout': true,
      };

      final settings = NoteListOptionSettings.fromJson(legacyJson);

      expect(settings.toJson().containsKey('forceOriginalLayout'), isFalse);
    });
  });
}
