import 'package:flutter/material.dart';
import 'package:whph/src/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/src/presentation/ui/features/notes/constants/note_ui_constants.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/components/label.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/acore.dart';

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
    final theme = Theme.of(context);

    return ListTile(
      tileColor: transparentCard ? theme.cardColor.withValues(alpha: 0.8) : theme.cardColor,
      visualDensity: isDense ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: EdgeInsets.only(left: AppTheme.sizeMedium, right: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
      ),
      onTap: onOpenDetails,
      leading: Icon(
        NoteUiConstants.noteIcon,
        size: isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.update,
                        size: AppTheme.iconSizeXSmall,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: AppTheme.size3XSmall),
                      Text(
                        _formatDateTime(note.updatedAt ?? note.createdDate, context),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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

  String _formatDateTime(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final localDateTime = DateTimeHelper.toLocalDateTime(dateTime);
    final difference = now.difference(localDateTime);
    final locale = Localizations.localeOf(context);

    if (difference.inDays == 0) {
      // Today, show time
      return 'Today ${DateTimeHelper.formatTime(localDateTime, locale: locale)}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - use localized weekday name
      return DateTimeHelper.getWeekday(localDateTime.weekday, locale);
    } else {
      // Older than a week
      return DateTimeHelper.formatDate(localDateTime, locale: locale);
    }
  }
}
