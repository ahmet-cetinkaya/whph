import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';

class TagGroupInfo {
  final String name;
  final bool isTranslatable;

  const TagGroupInfo({required this.name, required this.isTranslatable});
}

class TagGroupingHelper {
  static TagGroupInfo? getGroupInfo(TagListItem item, TagSortFields? sortField) {
    if (sortField == null) return null;

    switch (sortField) {
      case TagSortFields.name:
        final name = GroupingUtils.getTitleGroup(item.name);
        return TagGroupInfo(name: name, isTranslatable: false);
      case TagSortFields.createdDate:
        if (item.createdDate == null) return null;
        final name = GroupingUtils.getBackwardDateGroup(item.createdDate!);
        return TagGroupInfo(name: name, isTranslatable: true);
      case TagSortFields.modifiedDate:
        if (item.modifiedDate == null) return null;
        final name = GroupingUtils.getBackwardDateGroup(item.modifiedDate!);
        return TagGroupInfo(name: name, isTranslatable: true);
    }
  }
}
