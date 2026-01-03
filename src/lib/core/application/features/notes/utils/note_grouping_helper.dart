import 'package:whph/core/application/features/notes/models/note_list_item.dart';
import 'package:whph/core/application/features/notes/models/note_sort_fields.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';

class NoteGroupingHelper {
  static String? getGroupName(NoteListItem note, NoteSortFields? sortField, {DateTime? now}) {
    if (sortField == null) return null;

    switch (sortField) {
      case NoteSortFields.title:
        return GroupingUtils.getTitleGroup(note.title);
      case NoteSortFields.createdDate:
        return GroupingUtils.getBackwardDateGroup(note.createdDate, now: now);
      case NoteSortFields.modifiedDate:
        return GroupingUtils.getBackwardDateGroup(note.modifiedDate, now: now);
    }
  }
}
