import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/main.dart';

enum TagOptionsResult { removeTag, openDetails }

class TagOptionsDialog extends StatelessWidget {
  final TagListItem tag;
  final ITranslationService translationService;
  final ThemeData theme;

  const TagOptionsDialog({
    super.key,
    required this.tag,
    required this.translationService,
    required this.theme,
  });

  static Future<TagOptionsResult?> show({
    required BuildContext context,
    required TagListItem tag,
  }) async {
    final translationService = container.resolve<ITranslationService>();

    return ResponsiveDialogHelper.showResponsiveDialog<TagOptionsResult>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      child: Builder(
        builder: (context) => TagOptionsDialog(
          tag: tag,
          translationService: translationService,
          theme: Theme.of(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagColor = TagUiConstants.getTagColor(tag.color);
    final tagIcon = TagUiConstants.getTagTypeIcon(tag.type);
    final tagName = tag.name.isNotEmpty ? tag.name : translationService.translate(SharedTranslationKeys.untitled);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.containerBorderRadius)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: Text(translationService.translate('shared.options')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: Row(
                  children: [
                    Icon(tagIcon, size: 24, color: tagColor),
                    const SizedBox(width: AppTheme.sizeSmall),
                    Expanded(
                      child: Text(
                        tagName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: tagColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppTheme.sizeLarge),
            _buildOptionTile(
              context: context,
              icon: Icons.remove_circle_outline,
              title: translationService.translate(TagTranslationKeys.removeTagTooltip),
              onTap: () => Navigator.of(context).pop(TagOptionsResult.removeTag),
            ),
            SizedBox(height: AppTheme.sizeSmall),
            _buildOptionTile(
              context: context,
              icon: Icons.open_in_new,
              title: translationService.translate(TagTranslationKeys.openDetailsTooltip),
              onTap: () => Navigator.of(context).pop(TagOptionsResult.openDetails),
            ),
            SizedBox(height: AppTheme.sizeLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
