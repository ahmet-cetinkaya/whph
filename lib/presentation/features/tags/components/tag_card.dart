import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/features/tags/components/tag_label.dart';

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
          padding: const EdgeInsets.all(AppTheme.sizeSmall),
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
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tag.relatedTags
                      .map((relatedTag) => TagLabel(
                            tagColor: relatedTag.color,
                            tagName: relatedTag.name,
                            mini: true,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
