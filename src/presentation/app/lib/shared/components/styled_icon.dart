import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';

class StyledIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final double? size;
  final bool isRounded;

  const StyledIcon(
    this.icon, {
    required this.isActive,
    this.size,
    this.isRounded = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.1) : AppTheme.surface2,
        shape: isRounded ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isRounded ? BorderRadius.circular(AppTheme.sizeSmall) : null,
      ),
      child: Icon(
        icon,
        size: size,
        color: isActive ? theme.colorScheme.primary : AppTheme.textColor.withValues(alpha: 0.5),
      ),
    );
  }
}
