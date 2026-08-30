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

  group('custom sort indicator preference', () {
    /// A sort-config payload whose indicator preference the caller controls, so
    /// the legacy default and an explicitly-hidden value can be told apart.
    Map<String, dynamic> sortConfigJson({bool? showCustomSortIndicator}) => <String, dynamic>{
          'orderOptions': [
            {'field': 'createdDate', 'direction': 'desc', 'translationKey': 'shared.created_date'},
          ],
          'useCustomOrder': true,
          'enableGrouping': false,
          if (showCustomSortIndicator != null) 'showCustomSortIndicator': showCustomSortIndicator,
        };

    test('TaskListOptionSettings defaults the missing preference to visible and round-trips false', () {
      final legacySettings = TaskListOptionSettings.fromJson(<String, dynamic>{
        'sortConfig': sortConfigJson(),
      });
      final hiddenSettings = TaskListOptionSettings.fromJson(<String, dynamic>{
        'sortConfig': sortConfigJson(showCustomSortIndicator: false),
      });

      expect(legacySettings.sortConfig!.showCustomSortIndicator, isTrue);
      expect(hiddenSettings.sortConfig!.showCustomSortIndicator, isFalse);
      // The preference must survive a full save/load cycle, not just the read.
      expect(
        TaskListOptionSettings.fromJson(hiddenSettings.toJson()).sortConfig!.showCustomSortIndicator,
        isFalse,
      );
    });

    test('HabitListOptionSettings defaults the missing preference to visible and round-trips false', () {
      final legacySettings = HabitListOptionSettings.fromJson(<String, dynamic>{
        'sortConfig': sortConfigJson(),
      });
      final hiddenSettings = HabitListOptionSettings.fromJson(<String, dynamic>{
        'sortConfig': sortConfigJson(showCustomSortIndicator: false),
      });

      expect(legacySettings.sortConfig!.showCustomSortIndicator, isTrue);
      expect(hiddenSettings.sortConfig!.showCustomSortIndicator, isFalse);
      expect(
        HabitListOptionSettings.fromJson(hiddenSettings.toJson()).sortConfig!.showCustomSortIndicator,
        isFalse,
      );
    });
  });
}
