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
    final cardPadding = isDense ? const EdgeInsets.all(AppTheme.sizeSmall) : const EdgeInsets.all(AppTheme.sizeMedium);
    final cardMargin = isDense
        ? const EdgeInsets.symmetric(vertical: 2, horizontal: AppTheme.sizeXSmall)
        : const EdgeInsets.symmetric(vertical: AppTheme.sizeXSmall, horizontal: AppTheme.sizeXSmall);
    final previewHeight = isDense ? 60.0 : 80.0;

    return Card(
      margin: cardMargin,
      elevation: 2,
      color: transparentCard ? Theme.of(context).cardColor.withValues(alpha: 0.8) : Theme.of(context).cardColor,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(AppTheme.sizeXSmall),
        child: Padding(
          padding: cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Note icon
                  Icon(
                    NoteUiConstants.noteIcon,
                    size: isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
                    color: Colors.white,
                  ),
                  SizedBox(width: isDense ? 4 : AppTheme.sizeXSmall),
                  // Note title
                  Expanded(
                    child: Text(
                      note.title,
                      style: isDense ? AppTheme.bodyLarge : AppTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: isDense ? 1 : 2,
                    ),
                  ),
                ],
              ),
              // Note content preview
              if (note.content != null && note.content!.isNotEmpty) ...[
                SizedBox(height: isDense ? 2 : AppTheme.sizeXSmall),
                Padding(
                  padding: EdgeInsets.only(left: isDense ? AppTheme.sizeSmall : AppTheme.sizeMedium),
                  child: BorderFadeOverlay(
                    fadeBorders: {FadeBorder.bottom},
                    backgroundColor: AppTheme.surface1,
                    child: SizedBox(
                      height: previewHeight,
                      child: MarkdownRenderer(
                        data: note.content!,
                      ),
                    ),
                  ),
                ),
              ],
              // Tags and last updated time in the same row
              if (note.tags.isNotEmpty || note.updatedAt != null) ...[
                SizedBox(height: isDense ? 2 : AppTheme.sizeXSmall),
                DefaultTextStyle(
                  style: AppTheme.bodySmall,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (note.tags.isNotEmpty)
                        Flexible(
                          child: Label.multipleColored(
                            icon: TagUiConstants.tagIcon,
                            color: Colors.grey, // Default color for icon and commas
                            values: note.tags.map((tag) => tag.tagName).toList(),
                            colors: note.tags
                                .map((tag) => tag.tagColor != null
                                    ? Color(int.parse('FF${tag.tagColor}', radix: 16))
                                    : Colors.grey)
                                .toList(),
                            mini: true,
                          ),
                        ),
                      if (note.tags.isNotEmpty && note.updatedAt != null) const SizedBox(width: 8),
                      if (note.updatedAt != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.update,
                                size: AppTheme.iconSizeXSmall,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 2),
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
        ),
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
