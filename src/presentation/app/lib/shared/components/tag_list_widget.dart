import 'package:flutter/material.dart';
import 'package:whph/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/shared/constants/app_theme.dart';

import 'package:whph/shared/utils/tag_display_utils.dart';

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

    // Build individual tag widgets with type-specific icons
    final List<Widget> tagWidgets = tagsToProcess.map((item) {
      final typeIcon = TagUiConstants.getTagTypeIcon(item.type);
      final typePrefix = TagUiConstants.getTagTypePrefix(item.type);

      final displayName =
          item.name.length > maxTagNameLength ? '${item.name.substring(0, truncatedTagNameLength)}...' : item.name;

      return _buildSingleTag(
        context: context,
        icon: typeIcon,
        prefix: typePrefix,
        name: displayName,
        color: item.color ?? Colors.grey,
      );
    }).toList();

    // Add "more" indicator if needed
    if (hasMoreTags) {
      final int extraCount = items.length - maxTagsToShow;
      tagWidgets.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz,
              size: mini ? AppTheme.fontSizeSmall : AppTheme.fontSizeMedium,
              color: Colors.grey,
            ),
            if (mini) const SizedBox(width: 2),
            if (!mini)
              Text(
                '+$extraCount',
                style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: mini ? 4 : 8,
      runSpacing: mini ? 2 : 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: tagWidgets,
    );
  }

  Widget _buildSingleTag({
    required BuildContext context,
    required IconData icon,
    required String prefix,
    required String name,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mini ? 2 : 4,
        vertical: 0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(mini ? 4 : 6),
      ),
      child: Text(
        '$prefix$name',
        style: AppTheme.bodySmall.copyWith(
          color: color,
          fontSize: mini ? AppTheme.fontSizeSmall : AppTheme.fontSizeMedium,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
