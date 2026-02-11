import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/application/features/tags/models/tag_sort_fields.dart';
import 'package:whph/core/application/shared/utils/grouping_utils.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';

class TagGroupInfo {
  final String name;
  final bool isTranslatable;

  const TagGroupInfo({required this.name, required this.isTranslatable});
}

TagGroupInfo? getTagGroupInfo(TagListItem item, TagSortFields? sortField) {
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
    case TagSortFields.type:
      return TagGroupInfo(
        name: _getTypeTranslationKey(item.type),
        isTranslatable: true,
      );
  }
}

String _getTypeTranslationKey(TagType type) {
  switch (type) {
    case TagType.label:
      return TagTranslationKeys.typeLabelLabel;
    case TagType.context:
      return TagTranslationKeys.typeContext;
    case TagType.project:
      return TagTranslationKeys.typeProject;
  }
}
