import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class StyledIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final double? size;

  const StyledIcon(
    this.icon, {
    required this.isActive,
    this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.1) : AppTheme.surface2,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: size,
        color: isActive ? theme.colorScheme.primary : AppTheme.textColor.withValues(alpha: 0.5),
      ),
    );
  }
}
