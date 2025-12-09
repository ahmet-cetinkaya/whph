import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/components/label.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';

import 'package:whph/presentation/ui/shared/utils/tag_display_utils.dart';

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
