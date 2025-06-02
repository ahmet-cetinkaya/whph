import 'package:flutter/material.dart';
import 'package:whph/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/presentation/features/notes/constants/note_ui_constants.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/border_fade_overlay.dart';
import 'package:whph/presentation/shared/components/label.dart';
import 'package:whph/presentation/shared/components/markdown_renderer.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';

class NoteCard extends StatelessWidget {
  final NoteListItem note;
  final VoidCallback? onOpenDetails;
  final bool transparentCard;
  final bool isDense;

  const NoteCard({
    super.key,
    required this.note,
    this.onOpenDetails,
    this.transparentCard = false,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    final previewHeight = isDense ? 60.0 : 80.0;

    return ListTile(
      tileColor: transparentCard ? Theme.of(context).cardColor.withValues(alpha: 0.8) : Theme.of(context).cardColor,
      visualDensity: isDense ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: EdgeInsets.only(left: AppTheme.sizeMedium, right: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
      ),
      onTap: onOpenDetails,
      leading: Icon(
        NoteUiConstants.noteIcon,
        size: isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
        color: Colors.white,
      ),
      title: Text(
        note.title,
        style: isDense ? AppTheme.bodyLarge : AppTheme.headlineSmall,
        overflow: TextOverflow.ellipsis,
        maxLines: isDense ? 1 : 2,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note content preview
          if (note.content != null && note.content!.isNotEmpty) ...[
            SizedBox(height: isDense ? 2 : AppTheme.size2XSmall),
            BorderFadeOverlay(
              fadeBorders: {FadeBorder.bottom},
              backgroundColor: AppTheme.surface1,
              child: SizedBox(
                height: previewHeight,
                child: MarkdownRenderer(
                  data: note.content!,
                ),
              ),
            ),
          ],
          // Tags and last updated time
          if (note.tags.isNotEmpty || note.updatedAt != null) ...[
            SizedBox(height: isDense ? 2 : AppTheme.size2XSmall),
            DefaultTextStyle(
              style: AppTheme.bodySmall,
              child: Wrap(
                spacing: AppTheme.sizeSmall,
                runSpacing: AppTheme.size2XSmall,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (note.tags.isNotEmpty)
                    Label.multipleColored(
                      icon: TagUiConstants.tagIcon,
                      color: Colors.grey,
                      values: note.tags.map((tag) => tag.tagName).toList(),
                      colors: note.tags
                          .map((tag) =>
                              tag.tagColor != null ? Color(int.parse('FF${tag.tagColor}', radix: 16)) : Colors.grey)
                          .toList(),
                      mini: true,
                    ),
                  if (note.updatedAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.update,
                          size: AppTheme.iconSizeXSmall,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: AppTheme.size3XSmall),
                        Text(
                          _formatDateTime(note.updatedAt!),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final localDateTime = DateTimeHelper.toLocalDateTime(dateTime);
    final difference = now.difference(localDateTime);

    if (difference.inDays == 0) {
      // Today, show time
      return 'Today ${DateTimeHelper.formatTime(localDateTime)}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week
      final weekday = _getWeekdayName(localDateTime.weekday);
      return weekday;
    } else {
      // Older than a week
      return DateTimeHelper.formatDate(localDateTime);
    }
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
}
