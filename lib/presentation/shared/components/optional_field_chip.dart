import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class OptionalFieldChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? backgroundColor;
  final Color? selectedColor;

  const OptionalFieldChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.backgroundColor,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Icon(Icons.add, size: AppTheme.iconSizeSmall),
        ],
      ),
      avatar: Icon(
        icon,
        size: AppTheme.iconSizeSmall,
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: backgroundColor,
      selectedColor: selectedColor ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}
