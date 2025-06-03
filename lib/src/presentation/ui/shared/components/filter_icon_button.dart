import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';

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
    final effectiveColor = color ?? Colors.grey;

    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onPressed,
          hoverColor: AppTheme.surface1,
          customBorder: const CircleBorder(),
          child: Container(
            width: iconSize * 2,
            height: iconSize * 2,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: iconSize,
              color: effectiveColor,
            ),
          ),
        ),
      ),
    );
  }
}
