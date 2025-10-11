import 'package:flutter/material.dart';
import 'package:whph/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_ui_constants.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/label.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:acore/acore.dart';

class NoteCard extends StatefulWidget {
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
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  final _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      tileColor: widget.transparentCard ? theme.cardColor.withValues(alpha: 0.8) : theme.cardColor,
      visualDensity: widget.isDense ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: EdgeInsets.only(left: AppTheme.sizeMedium, right: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
      ),
      onTap: widget.onOpenDetails,
      leading: Icon(
        NoteUiConstants.noteIcon,
        size: widget.isDense ? AppTheme.iconSizeSmall : AppTheme.iconSizeMedium,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        widget.note.title.isEmpty ? _translationService.translate(SharedTranslationKeys.untitled) : widget.note.title,
        style: widget.isDense ? AppTheme.bodySmall : AppTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
        maxLines: widget.isDense ? 1 : 2,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags and last updated time
          if (widget.note.tags.isNotEmpty || widget.note.updatedAt != null) ...[
            SizedBox(height: widget.isDense ? 2 : AppTheme.size2XSmall),
            DefaultTextStyle(
              style: AppTheme.bodySmall,
              child: Wrap(
                spacing: AppTheme.sizeSmall,
                runSpacing: AppTheme.size2XSmall,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.note.tags.isNotEmpty) _buildNoteTagsWidget(),
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
                        _formatDateTime(widget.note.updatedAt ?? widget.note.createdDate, context),
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

  Widget _buildNoteTagsWidget() {
    if (widget.note.tags.isEmpty) {
      return const SizedBox.shrink();
    }

    const int maxTagsToShow = 5;
    const int maxTagNameLength = 20;
    const int truncatedTagNameLength = 17;

    final bool hasMoreTags = widget.note.tags.length > maxTagsToShow;
    final tagsToProcess = hasMoreTags ? widget.note.tags.take(maxTagsToShow) : widget.note.tags;

    final List<String> tagNames = tagsToProcess
        .map((tag) => tag.tagName.isNotEmpty
            ? (tag.tagName.length > maxTagNameLength ? '${tag.tagName.substring(0, truncatedTagNameLength)}...' : tag.tagName)
            : _translationService.translate(SharedTranslationKeys.untitled))
        .toList();

    // Add a "+X more" indicator if there are more than 5 tags
    if (hasMoreTags) {
      final int extraCount = widget.note.tags.length - maxTagsToShow;
      tagNames.add('+$extraCount more');
    }

    final List<Color> tagColors = tagsToProcess
        .map((tag) => tag.tagColor != null ? Color(int.parse('FF${tag.tagColor}', radix: 16)) : Colors.grey)
        .toList();

    if (hasMoreTags) {
      tagColors.add(Colors.grey); // color for "+X more" text
    }

    return Label.multipleColored(
      icon: TagUiConstants.tagIcon,
      color: Colors.grey,
      values: tagNames,
      colors: tagColors,
      mini: true,
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
