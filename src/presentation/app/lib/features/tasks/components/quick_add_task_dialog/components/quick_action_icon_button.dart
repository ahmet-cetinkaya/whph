import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';

/// Reusable icon button styled for quick action bars.
class QuickActionIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color? color;
  final VoidCallback onPressed;
  final String tooltip;
  final double iconSize;

  const QuickActionIconButton({
    super.key,
    this.icon,
    this.iconWidget,
    this.color,
    required this.onPressed,
    required this.tooltip,
    this.iconSize = AppTheme.iconSizeMedium,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: iconWidget ?? Icon(icon, color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: iconSize,
      style: getQuickActionButtonStyle(theme),
    );
  }

  /// Shared style for quick action buttons.
  static ButtonStyle getQuickActionButtonStyle(ThemeData theme) {
    return IconButton.styleFrom(
      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2), width: 0.5),
      ),
      padding: EdgeInsets.zero,
      minimumSize: const Size(32, 32),
    );
  }
}
