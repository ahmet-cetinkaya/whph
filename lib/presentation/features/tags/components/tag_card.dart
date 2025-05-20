import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/shared/components/label.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';

class TagCard extends StatelessWidget {
  final TagListItem tag;
  final VoidCallback onOpenDetails;

  const TagCard({
    super.key,
    required this.tag,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: AppTheme.sizeXSmall,
        horizontal: AppTheme.sizeXSmall,
      ),
      elevation: 2,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(AppTheme.sizeXSmall),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tag name row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    TagUiConstants.tagIcon,
                    size: AppTheme.iconSizeSmall,
                  ),
                  const SizedBox(width: AppTheme.sizeXSmall),
                  Expanded(
                    child: Text(
                      tag.name,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),

              // Related tags
              if (tag.relatedTags.isNotEmpty) ...[
                const SizedBox(height: AppTheme.sizeXSmall),
                Label.multipleColored(
                  icon: TagUiConstants.tagIcon,
                  color: Colors.grey, // Default color for icon and commas
                  values: tag.relatedTags.map((relatedTag) => relatedTag.name).toList(),
                  colors: tag.relatedTags
                      .map((relatedTag) =>
                          relatedTag.color != null ? Color(int.parse('FF${relatedTag.color}', radix: 16)) : Colors.grey)
                      .toList(),
                  mini: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
