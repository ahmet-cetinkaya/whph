import 'package:flutter/material.dart';
import 'package:acore/acore.dart' hide Container;
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:application/shared/constants/shared_translation_keys.dart';

/// Enum representing the type of item to create from shared text
enum ShareItemType {
  task,
  note,
}

/// Result callback type for share disambiguation
typedef ShareItemResultCallback = Future<bool> Function(ShareItemType type);

/// Dialog component for selecting what type of item to create from shared text
/// Allows users to choose between creating a Task or a Note
class ShareDisambiguationDialog extends StatelessWidget {
  final String sharedText;
  final String? sharedSubject;
  final ITranslationService translationService;
  final ThemeData theme;
  final ShareItemResultCallback onItemSelected;

  const ShareDisambiguationDialog({
    super.key,
    required this.sharedText,
    this.sharedSubject,
    required this.translationService,
    required this.theme,
    required this.onItemSelected,
  });

  /// Shows the disambiguation dialog and handles the item creation
  /// Returns true if an item was successfully created, false if dialog was dismissed or creation failed
  static Future<bool> show({
    required BuildContext context,
    required String sharedText,
    String? sharedSubject,
    required ITranslationService translationService,
    required ShareItemResultCallback onItemSelected,
  }) async {
    bool itemCreated = false;

    await ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      child: Builder(
        builder: (context) => ShareDisambiguationDialog(
          sharedText: sharedText,
          sharedSubject: sharedSubject,
          translationService: translationService,
          theme: Theme.of(context),
          onItemSelected: (type) async {
            // Execute the callback first (which creates item and shows notification)
            // while dialog context (and Overlay) is still available
            final result = await onItemSelected(type);
            itemCreated = result;
            // Close the dialog after callback completes
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            return result;
          },
        ),
      ),
    );
    return itemCreated;
  }

  @override
  Widget build(BuildContext context) {
    // Extract preview of the shared text
    final previewText = sharedText.length > 100 ? '${sharedText.substring(0, 100)}...' : sharedText;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.containerBorderRadius)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            AppBar(
              automaticallyImplyLeading: false,
              title: Text(translationService.translate(SharedTranslationKeys.shareDialogTitle)),
              actions: [
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // Shared text preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.share,
                      size: 20,
                      color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                    ),
                    SizedBox(width: AppTheme.sizeSmall),
                    Expanded(
                      child: Text(
                        previewText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.9),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppTheme.sizeLarge),

            // Task option
            _buildOptionTile(
              context: context,
              icon: Icons.check_circle_outline,
              iconColor: AppTheme.primaryColor,
              title: translationService.translate(SharedTranslationKeys.shareCreateTask),
              description: translationService.translate(SharedTranslationKeys.shareCreateTaskDescription),
              onTap: () => onItemSelected(ShareItemType.task),
            ),

            SizedBox(height: AppTheme.sizeSmall),

            // Note option
            _buildOptionTile(
              context: context,
              icon: Icons.note_outlined,
              iconColor: AppTheme.infoColor,
              title: translationService.translate(SharedTranslationKeys.shareCreateNote),
              description: translationService.translate(SharedTranslationKeys.shareCreateNoteDescription),
              onTap: () => onItemSelected(ShareItemType.note),
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
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
