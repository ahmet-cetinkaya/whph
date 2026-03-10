import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class OptionalFieldChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? backgroundColor;
  final Color? selectedColor;
  final String? tooltip;

  const OptionalFieldChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.backgroundColor,
    this.selectedColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: AppTheme.size2XSmall),
          Icon(Icons.add, size: AppTheme.iconSizeSmall),
        ],
      ),
      avatar: Icon(
        icon,
        size: AppTheme.iconSizeSmall,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.size2XSmall, vertical: AppTheme.size2XSmall),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: backgroundColor,
      selectedColor: selectedColor ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );

    // Wrap with tooltip if provided
    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: chip,
      );
    }

    return chip;
  }
}
