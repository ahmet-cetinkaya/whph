import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/ui/shared/components/label.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';

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
    final spacing = isDense ? AppTheme.size2XSmall : AppTheme.sizeSmall;

    return ListTile(
      tileColor: transparent ? Colors.transparent : AppTheme.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
      ),
      visualDensity: isDense ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: EdgeInsets.only(left: AppTheme.sizeMedium, right: 0),
      dense: isDense,
      onTap: onOpenDetails,
      leading: Icon(
        TagUiConstants.tagIcon,
        size: isDense ? AppTheme.iconSizeSmall : AppTheme.fontSizeXLarge,
        color: tag.color != null ? Color(int.parse('FF${tag.color}', radix: 16)) : AppTheme.secondaryTextColor,
      ),
      title: Text(
        tag.name,
        style: (isDense ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: isDense ? 1 : 2,
      ),
      subtitle: tag.relatedTags.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(top: spacing),
              child: _buildRelatedTags(),
            )
          : null,
      trailing: trailingButtons != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: trailingButtons!.map((widget) {
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
              }).toList(),
            )
          : null,
    );
  }

  Widget _buildRelatedTags() {
    return Wrap(
      spacing: AppTheme.size2XSmall,
      runSpacing: AppTheme.size3XSmall,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Label.multipleColored(
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
        ),
      ],
    );
  }
}
