import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/shared/components/label.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';

class TagCard extends StatelessWidget {
  final TagListItem tag;
  final VoidCallback onOpenDetails;
  final bool isDense;
  final bool transparent;
  final List<Widget>? trailingButtons;

  const TagCard({
    super.key,
    required this.tag,
    required this.onOpenDetails,
    this.isDense = false,
    this.transparent = false,
    this.trailingButtons,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = isDense ? 4.0 : 8.0;
    final padding = isDense
        ? const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall)
        : const EdgeInsets.symmetric(horizontal: AppTheme.sizeLarge, vertical: AppTheme.sizeSmall);

    return Card(
      color: transparent ? Colors.transparent : null,
      elevation: transparent ? 0 : null,
      // Card margin removed to match TaskCard
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(AppTheme.sizeXSmall),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainContent(),
              if (tag.relatedTags.isNotEmpty) ...[
                SizedBox(height: spacing),
                _buildRelatedTags(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tag icon and name
        Icon(
          TagUiConstants.tagIcon,
          size: isDense ? AppTheme.iconSizeSmall : AppTheme.fontSizeXLarge,
          color: tag.color != null ? Color(int.parse('FF${tag.color}', radix: 16)) : AppTheme.secondaryTextColor,
        ),
        SizedBox(width: isDense ? AppTheme.sizeXSmall : AppTheme.sizeSmall),
        Expanded(
          child: Text(
            tag.name,
            style: (isDense ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: isDense ? 1 : 2,
          ),
        ),

        // Trailing buttons
        if (trailingButtons != null)
          ...trailingButtons!.map((widget) {
            if (widget is IconButton) {
              return IconButton(
                icon: widget.icon,
                onPressed: widget.onPressed,
                color: widget.color,
                tooltip: widget.tooltip,
                iconSize: isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
              );
            }
            return widget;
          }),
      ],
    );
  }

  Widget _buildRelatedTags() {
    return Label.multipleColored(
      icon: TagUiConstants.tagIcon,
      color: AppTheme.secondaryTextColor,
      values: tag.relatedTags.map((relatedTag) => relatedTag.name).toList(),
      colors: tag.relatedTags
          .map((relatedTag) => relatedTag.color != null
              ? Color(int.parse('FF${relatedTag.color}', radix: 16))
              : AppTheme.secondaryTextColor)
          .toList(),
      mini: isDense,
      overflow: TextOverflow.ellipsis,
    );
  }
}
