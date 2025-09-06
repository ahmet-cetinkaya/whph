import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/ui/shared/components/label.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class TagCard extends StatefulWidget {
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
  State<TagCard> createState() => _TagCardState();
}

class _TagCardState extends State<TagCard> {
  final _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    final spacing = widget.isDense ? AppTheme.size2XSmall : AppTheme.sizeSmall;

    return ListTile(
      tileColor: widget.transparent ? Colors.transparent : AppTheme.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
      ),
      visualDensity: widget.isDense ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: EdgeInsets.only(left: AppTheme.sizeMedium, right: 0),
      dense: widget.isDense,
      onTap: widget.onOpenDetails,
      leading: Icon(
        TagUiConstants.tagIcon,
        size: widget.isDense ? AppTheme.iconSizeSmall : AppTheme.fontSizeXLarge,
        color: widget.tag.color != null
            ? Color(int.parse('FF${widget.tag.color}', radix: 16))
            : AppTheme.secondaryTextColor,
      ),
      title: Text(
        widget.tag.name.isEmpty ? _translationService.translate(SharedTranslationKeys.untitled) : widget.tag.name,
        style: (widget.isDense ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: widget.isDense ? 1 : 2,
      ),
      subtitle: widget.tag.relatedTags.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(top: spacing),
              child: _buildRelatedTags(),
            )
          : null,
      trailing: widget.trailingButtons != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.trailingButtons!.map((btn) {
                if (btn is IconButton) {
                  return IconButton(
                    icon: btn.icon,
                    onPressed: btn.onPressed,
                    color: btn.color,
                    tooltip: btn.tooltip,
                    iconSize: widget.isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
                  );
                }
                return btn;
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
          values: widget.tag.relatedTags.map((relatedTag) => relatedTag.name).toList(),
          colors: widget.tag.relatedTags
              .map((relatedTag) => relatedTag.color != null
                  ? Color(int.parse('FF${relatedTag.color}', radix: 16))
                  : AppTheme.secondaryTextColor)
              .toList(),
          mini: widget.isDense,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
