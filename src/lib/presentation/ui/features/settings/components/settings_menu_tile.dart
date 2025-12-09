import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

/// A menu tile component designed for settings pages.
///
/// Provides a consistent look and feel for settings menu items with:
/// - Icon or custom leading widget
/// - Title and optional subtitle
/// - Active/inactive state styling
/// - Custom trailing widgets
/// - Card-based design for better visual separation
class SettingsMenuTile extends StatelessWidget {
  /// Icon to display as the leading widget. Required if customLeading is not provided
  final IconData? icon;

  /// The title text for the menu item
  final String title;

  /// Callback when the tile is tapped
  final VoidCallback onTap;

  /// Size for the icon. Defaults to 24.0
  final double? iconSize;

  /// Optional subtitle text for additional context
  final String? subtitle;

  /// Optional widget to display on the right side (defaults to chevron icon)
  final Widget? trailing;

  /// Custom leading widget to use instead of an icon
  final Widget? customLeading;

  /// Whether this menu item is currently active/selected
  final bool isActive;

  const SettingsMenuTile({
    super.key,
    this.icon,
    required this.title,
    required this.onTap,
    this.iconSize = 24.0, // Medium icon size
    this.subtitle,
    this.trailing,
    this.customLeading,
    this.isActive = false,
  }) : assert(icon != null || customLeading != null, 'Either icon or customLeading must be provided');

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: customLeading ??
            StyledIcon(
              icon!,
              isActive: isActive,
              size: iconSize,
            ),
        title: Text(
          title,
          style: AppTheme.bodyMedium,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              )
            : null,
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 24.0),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sizeLarge,
          vertical: AppTheme.size2XSmall,
        ),
      ),
    );
  }
}
