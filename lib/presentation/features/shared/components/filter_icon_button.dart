import 'package:flutter/material.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';

class FilterIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;
  final Color? color;
  final String? tooltip;

  const FilterIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconSize = 20,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: IconButton(
        icon: Icon(icon),
        iconSize: iconSize,
        color: color ?? Colors.grey,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        hoverColor: AppTheme.surface1,
      ),
    );
  }
}
