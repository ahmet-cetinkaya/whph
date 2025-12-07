import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

class SettingsMenuTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final VoidCallback onTap;
  final double? iconSize;
  final String? subtitle;
  final Widget? trailing;
  final Widget? customLeading;
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
