import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class CustomTabItem {
  final IconData icon;
  final String label;

  const CustomTabItem({
    required this.icon,
    required this.label,
  });
}

class CustomTabBar extends StatelessWidget {
  final List<CustomTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const CustomTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(items.length, (index) {
          return Expanded(
            child: _buildTabButton(
              context: context,
              index: index,
              item: items[index],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabButton({
    required BuildContext context,
    required int index,
    required CustomTabItem item,
  }) {
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius - 4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 18,
              color: isSelected ? theme.colorScheme.onPrimary : AppTheme.textColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                item.label,
                style: TextStyle(
                  color: isSelected ? theme.colorScheme.onPrimary : AppTheme.textColor.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
