import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
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
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: TagUiConstants.tagCardPadding,
          child: Row(
            children: [
              Icon(
                TagUiConstants.tagIcon,
                size: TagUiConstants.tagIconSize,
                color: TagUiConstants.getTagColor(tag.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tag.name,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
