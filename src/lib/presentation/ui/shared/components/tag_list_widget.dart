import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/label.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class TagDisplayItem {
  final String name;
  final Color? color;

  const TagDisplayItem({required this.name, this.color});
}

/// Utility class for tag display operations
class TagDisplayUtils {
  /// Convert a list of objects with name/color properties to TagDisplayItem objects
  static List<TagDisplayItem> objectsToDisplayItems(List<dynamic> objects, ITranslationService translationService) {
    return objects
        .map((obj) => TagDisplayItem(
              name: (obj.name as String?)?.isNotEmpty == true
                  ? obj.name as String
                  : translationService.translate(SharedTranslationKeys.untitled),
              color: (obj.color as String?) != null ? Color(int.parse('FF${obj.color}', radix: 16)) : null,
            ))
        .toList();
  }

  /// Convert a list of tag data with tagName/tagColor properties to TagDisplayItem objects
  static List<TagDisplayItem> tagDataToDisplayItems(List<dynamic> tagData, ITranslationService translationService) {
    return tagData
        .map((tag) => TagDisplayItem(
              name: (tag.tagName as String?)?.isNotEmpty == true
                  ? tag.tagName as String
                  : translationService.translate(SharedTranslationKeys.untitled),
              color: (tag.tagColor as String?) != null ? Color(int.parse('FF${tag.tagColor}', radix: 16)) : null,
            ))
        .toList();
  }
}

class TagListWidget extends StatelessWidget {
  final List<TagDisplayItem> items;
  final bool mini;

  const TagListWidget({super.key, required this.items, this.mini = true});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    const int maxTagsToShow = 5;
    const int maxTagNameLength = 20;
    const int truncatedTagNameLength = 17;

    final bool hasMoreTags = items.length > maxTagsToShow;
    final tagsToProcess = hasMoreTags ? items.take(maxTagsToShow) : items;

    final List<String> tagNames = tagsToProcess
        .map((item) =>
            item.name.length > maxTagNameLength ? '${item.name.substring(0, truncatedTagNameLength)}...' : item.name)
        .toList();

    if (hasMoreTags) {
      final int extraCount = items.length - maxTagsToShow;
      tagNames.add('+$extraCount more');
    }

    final List<Color> tagColors = tagsToProcess.map((item) => item.color ?? Colors.grey).toList();

    if (hasMoreTags) {
      tagColors.add(Colors.grey);
    }

    return Label.multipleColored(
      icon: TagUiConstants.tagIcon,
      color: Colors.grey,
      values: tagNames,
      colors: tagColors,
      mini: mini,
    );
  }
}
