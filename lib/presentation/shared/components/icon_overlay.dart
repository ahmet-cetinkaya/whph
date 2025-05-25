import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

/// A flexible overlay component that displays an icon with an optional message.
/// Used to show empty states or completion indicators throughout the app.
class IconOverlay extends StatelessWidget {
  /// The icon to display in the overlay. Required.
  final IconData icon;

  /// Optional message to display below the icon
  final String? message;

  /// Size of the icon
  final double iconSize;

  /// Color of the icon (defaults to surface3 if not provided)
  final Color? iconColor;

  /// Style for the message text
  final TextStyle? messageStyle;

  /// Optional text size for the message
  final double? textSize;

  const IconOverlay({
    super.key,
    required this.icon,
    this.message,
    this.iconSize = 48,
    this.iconColor,
    this.messageStyle,
    this.textSize,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = AppTheme.surface3;
    final defaultStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: textSize,
        );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? defaultColor,
          ),

          //
          if (message != null) ...[
            const SizedBox(height: AppTheme.sizeSmall),
            Text(
              message!,
              style: messageStyle ?? defaultStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
