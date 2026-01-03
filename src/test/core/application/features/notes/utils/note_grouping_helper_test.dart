import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/notes/models/note_list_item.dart';
import 'package:whph/core/application/features/notes/models/note_sort_fields.dart';
import 'package:whph/core/application/features/notes/utils/note_grouping_helper.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';

void main() {
  group('NoteGroupingHelper', () {
    test('getGroupName returns null when sortField is null', () {
      final note = NoteListItem(id: '1', title: 'Note', createdDate: DateTime.now());
      final result = NoteGroupingHelper.getGroupName(note, null);
      expect(result, isNull);
    });

    test('getGroupName groups by Title (First Letter)', () {
      final noteA = NoteListItem(id: '1', title: 'Apple', createdDate: DateTime.now());
      final noteB = NoteListItem(id: '2', title: 'Banana', createdDate: DateTime.now());
      final noteLowerA = NoteListItem(id: '3', title: 'apple', createdDate: DateTime.now());
      final noteSymbol = NoteListItem(id: '4', title: '@Note', createdDate: DateTime.now());
      final noteEmpty = NoteListItem(id: '5', title: '', createdDate: DateTime.now());

      expect(NoteGroupingHelper.getGroupName(noteA, NoteSortFields.title), 'A');
      expect(NoteGroupingHelper.getGroupName(noteB, NoteSortFields.title), 'B');
      expect(NoteGroupingHelper.getGroupName(noteLowerA, NoteSortFields.title), 'A');
      expect(NoteGroupingHelper.getGroupName(noteSymbol, NoteSortFields.title), '#');
      expect(NoteGroupingHelper.getGroupName(noteEmpty, NoteSortFields.title), '#');
    });

    test('getGroupName groups by Created Date', () {
      final now = DateTime(2023, 1, 10, 10, 0); // Fixed "now"

      final today = NoteListItem(id: '1', title: 'Today', createdDate: DateTime(2023, 1, 10, 9, 0));
      final yesterday = NoteListItem(id: '2', title: 'Yesterday', createdDate: DateTime(2023, 1, 9, 10, 0));
      final lastWeek = NoteListItem(id: '3', title: 'Last Week', createdDate: DateTime(2023, 1, 3, 10, 0));
      final older = NoteListItem(id: '4', title: 'Older', createdDate: DateTime(2023, 1, 1, 10, 0));

      expect(NoteGroupingHelper.getGroupName(today, NoteSortFields.createdDate, now: now), SharedTranslationKeys.today);
      expect(NoteGroupingHelper.getGroupName(yesterday, NoteSortFields.createdDate, now: now),
          SharedTranslationKeys.yesterday);
      expect(NoteGroupingHelper.getGroupName(lastWeek, NoteSortFields.createdDate, now: now),
          SharedTranslationKeys.last7Days);
      expect(NoteGroupingHelper.getGroupName(older, NoteSortFields.createdDate, now: now), SharedTranslationKeys.older);
    });

    test('getGroupName groups by Modified Date', () {
      final now = DateTime(2023, 1, 10, 10, 0);

      // Note: Modified Date logic is almost same as Created Date, testing basic case
      final today = NoteListItem(
          id: '1', title: 'Today', createdDate: DateTime(2023, 1, 1), modifiedDate: DateTime(2023, 1, 10, 9, 0));
      final none = NoteListItem(id: '2', title: 'None', createdDate: DateTime(2023, 1, 1)); // modifiedDate is null

      expect(
          NoteGroupingHelper.getGroupName(today, NoteSortFields.modifiedDate, now: now), SharedTranslationKeys.today);
      expect(
          NoteGroupingHelper.getGroupName(none, NoteSortFields.modifiedDate, now: now), SharedTranslationKeys.noDate);
    });
  });
}
