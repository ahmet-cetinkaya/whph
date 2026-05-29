import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

/// A flexible overlay component that displays an icon with an optional message.
/// Used to show empty states or completion indicators throughout the app.
class IconOverlay extends StatelessWidget {
  final IconData icon;

  final String? message;

  final double iconSize;

  final Color? iconColor;

  final TextStyle? messageStyle;

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
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? defaultColor,
          ),
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
