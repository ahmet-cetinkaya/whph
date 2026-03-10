import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

/// Server mode toggle card widget for Android platform.
class ServerModeToggle extends StatelessWidget {
  final bool isServerMode;
  final VoidCallback onToggle;
  final String title;
  final String subtitle;

  const ServerModeToggle({
    super.key,
    required this.isServerMode,
    required this.onToggle,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: SwitchListTile.adaptive(
        value: isServerMode,
        onChanged: (_) => onToggle(),
        title: Text(
          title,
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: AppTheme.bodySmall,
        ),
        secondary: StyledIcon(
          isServerMode ? Icons.wifi_tethering : Icons.wifi_tethering_off,
          isActive: isServerMode,
        ),
      ),
    );
  }
}
