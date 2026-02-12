import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';

/// Builds a title section with icon, text, and close button for dialogs
class TitleBuilder {
  static Widget build({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool showCloseButton = true,
    VoidCallback? onClose,
    bool isBottomSheet = false,
  }) {
    if (isBottomSheet) {
      // Mobile bottom sheet title with close button
      return Padding(
        padding: EdgeInsets.only(bottom: AppTheme.sizeMedium),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.sizeSmall),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (showCloseButton)
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: onClose ?? () => Navigator.of(context).pop(),
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      );
    } else {
      // Desktop dialog title with close button
      return Padding(
        padding: EdgeInsets.only(bottom: AppTheme.sizeMedium),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.sizeSmall),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (showCloseButton)
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: onClose ?? () => Navigator.of(context).pop(),
                padding: EdgeInsets.all(8),
                constraints: BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      );
    }
  }

  /// Builds a simple title section without close button
  static Widget buildSimple({
    required BuildContext context,
    required IconData icon,
    required String title,
    bool isBottomSheet = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.sizeSmall),
      child: Row(
        children: [
          Icon(
            icon,
            size: isBottomSheet ? 16 : 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: AppTheme.sizeSmall),
          Expanded(
            child: Text(
              title,
              style: isBottomSheet
                  ? Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      )
                  : Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
