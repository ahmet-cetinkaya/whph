import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:domain/features/tags/tag.dart';

class TagDisplayItem {
  final String name;
  final Color? color;
  final TagType type;

  const TagDisplayItem({
    required this.name,
    this.color,
    this.type = TagType.label,
  });
}

/// Utility class for tag display operations
class TagDisplayUtils {
  /// Convert a list of objects with name/color/type properties to TagDisplayItem objects
  static List<TagDisplayItem> objectsToDisplayItems(List<dynamic> objects, ITranslationService translationService) {
    return objects
        .map((obj) => TagDisplayItem(
              name: (obj.name as String?)?.isNotEmpty == true
                  ? obj.name as String
                  : translationService.translate(SharedTranslationKeys.untitled),
              color: (obj.color as String?) != null ? Color(int.parse('FF${obj.color}', radix: 16)) : null,
              type: (obj.type as TagType?) ?? TagType.label,
            ))
        .toList();
  }

  /// Convert a list of tag data with tagName/tagColor/tagType properties to TagDisplayItem objects
  static List<TagDisplayItem> tagDataToDisplayItems(List<dynamic> tagData, ITranslationService translationService) {
    return tagData
        .map((tag) => TagDisplayItem(
              name: (tag.tagName as String?)?.isNotEmpty == true
                  ? tag.tagName as String
                  : translationService.translate(SharedTranslationKeys.untitled),
              color: (tag.tagColor as String?) != null ? Color(int.parse('FF${tag.tagColor}', radix: 16)) : null,
              type: (tag.tagType as TagType?) ?? TagType.label,
            ))
        .toList();
  }
}
