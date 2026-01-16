import 'package:flutter_test/flutter_test.dart';
import 'package:whph/core/application/features/notes/models/note_list_item.dart';
import 'package:whph/core/application/features/notes/models/note_sort_fields.dart';
import 'package:whph/core/application/features/notes/utils/note_grouping_helper.dart';
import 'package:whph/core/application/shared/constants/shared_translation_keys.dart';

void main() {
  group('NoteGroupingHelper', () {
    test('getGroupInfo returns null when sortField is null', () {
      final note = NoteListItem(id: '1', title: 'Note', createdDate: DateTime.now());
      final result = NoteGroupingHelper.getGroupInfo(note, null);
      expect(result, isNull);
    });

    test('getGroupInfo groups by Title (First Letter)', () {
      final noteA = NoteListItem(id: '1', title: 'Apple', createdDate: DateTime.now());
      final noteB = NoteListItem(id: '2', title: 'Banana', createdDate: DateTime.now());
      final noteLowerA = NoteListItem(id: '3', title: 'apple', createdDate: DateTime.now());
      final noteSymbol = NoteListItem(id: '4', title: '@Note', createdDate: DateTime.now());
      final noteEmpty = NoteListItem(id: '5', title: '', createdDate: DateTime.now());

      expect(NoteGroupingHelper.getGroupInfo(noteA, NoteSortFields.title)?.name, 'A');
      expect(NoteGroupingHelper.getGroupInfo(noteB, NoteSortFields.title)?.name, 'B');
      expect(NoteGroupingHelper.getGroupInfo(noteLowerA, NoteSortFields.title)?.name, 'A');
      expect(NoteGroupingHelper.getGroupInfo(noteSymbol, NoteSortFields.title)?.name, '#');
      expect(NoteGroupingHelper.getGroupInfo(noteEmpty, NoteSortFields.title)?.name, '#');
    });

    test('getGroupInfo groups by Created Date', () {
      final now = DateTime(2023, 1, 10, 10, 0); // Fixed "now"

      final today = NoteListItem(id: '1', title: 'Today', createdDate: DateTime(2023, 1, 10, 9, 0));
      final yesterday = NoteListItem(id: '2', title: 'Yesterday', createdDate: DateTime(2023, 1, 9, 10, 0));
      final lastWeek = NoteListItem(id: '3', title: 'Last Week', createdDate: DateTime(2023, 1, 3, 10, 0));
      final older = NoteListItem(id: '4', title: 'Older', createdDate: DateTime(2023, 1, 1, 10, 0));

      expect(NoteGroupingHelper.getGroupInfo(today, NoteSortFields.createdDate, now: now)?.name,
          SharedTranslationKeys.today);
      expect(NoteGroupingHelper.getGroupInfo(yesterday, NoteSortFields.createdDate, now: now)?.name,
          SharedTranslationKeys.yesterday);
      expect(NoteGroupingHelper.getGroupInfo(lastWeek, NoteSortFields.createdDate, now: now)?.name,
          SharedTranslationKeys.last7Days);
      expect(NoteGroupingHelper.getGroupInfo(older, NoteSortFields.createdDate, now: now)?.name,
          SharedTranslationKeys.older);
    });

    test('getGroupInfo groups by Modified Date', () {
      final now = DateTime(2023, 1, 10, 10, 0);

      // Note: Modified Date logic is almost same as Created Date, testing basic case
      final today = NoteListItem(
          id: '1', title: 'Today', createdDate: DateTime(2023, 1, 1), modifiedDate: DateTime(2023, 1, 10, 9, 0));
      final none = NoteListItem(id: '2', title: 'None', createdDate: DateTime(2023, 1, 1)); // modifiedDate is null

      expect(NoteGroupingHelper.getGroupInfo(today, NoteSortFields.modifiedDate, now: now)?.name,
          SharedTranslationKeys.today);
      expect(NoteGroupingHelper.getGroupInfo(none, NoteSortFields.modifiedDate, now: now)?.name,
          SharedTranslationKeys.noDate);
    });
    test('getGroupInfo groups by Tag', () {
      final noteWithTag = NoteListItem(
        id: '1',
        title: 'Tagged',
        createdDate: DateTime.now(),
        tags: [const TagListItem(tagId: 't1', tagName: 'Work', tagColor: null)],
      );
      final noteNoTag = NoteListItem(
        id: '2',
        title: 'No Tag',
        createdDate: DateTime.now(),
        tags: [],
      );

      final groupWithTag = NoteGroupingHelper.getGroupInfo(noteWithTag, NoteSortFields.tag);
      expect(groupWithTag?.name, 'Work');
      expect(groupWithTag?.isTranslatable, isFalse);

      final groupNoTag = NoteGroupingHelper.getGroupInfo(noteNoTag, NoteSortFields.tag);
      expect(groupNoTag?.name, SharedTranslationKeys.none);
      expect(groupNoTag?.isTranslatable, isTrue);
    });
  });
}
