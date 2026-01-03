import 'package:whph/core/application/features/notes/models/note_list_item.dart';
import 'package:whph/core/application/features/notes/models/note_sort_fields.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';

class NoteGroupInfo {
  final String name;
  final bool isTranslatable;

  const NoteGroupInfo({required this.name, required this.isTranslatable});
}

class NoteGroupingHelper {
  static NoteGroupInfo? getGroupInfo(NoteListItem note, NoteSortFields? sortField, {DateTime? now}) {
    if (sortField == null) return null;

    switch (sortField) {
      case NoteSortFields.title:
        final name = GroupingUtils.getTitleGroup(note.title);
        return NoteGroupInfo(name: name, isTranslatable: false);
      case NoteSortFields.createdDate:
        final name = GroupingUtils.getBackwardDateGroup(note.createdDate, now: now);
        return NoteGroupInfo(name: name, isTranslatable: true);
      case NoteSortFields.modifiedDate:
        final name = GroupingUtils.getBackwardDateGroup(note.modifiedDate, now: now);
        return NoteGroupInfo(name: name, isTranslatable: true);
    }
  }
}
