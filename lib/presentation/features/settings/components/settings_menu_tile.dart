import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class SettingsMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final double? iconSize;
  final String? subtitle;

  const SettingsMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconSize = AppTheme.fontSizeLarge,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: iconSize),
        title: Text(
          title,
          style: AppTheme.bodyMedium,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppTheme.bodySmall,
              )
            : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: AppTheme.fontSizeLarge),
        onTap: onTap,
      ),
    );
  }
}
