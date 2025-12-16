import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class ComparisonLegend extends StatelessWidget {
  final String? currentDateRange;
  final String? previousDateRange;
  final bool showComparison;

  const ComparisonLegend({
    super.key,
    required this.currentDateRange,
    required this.previousDateRange,
    this.showComparison = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showComparison) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final items = <Widget>[
          if (currentDateRange != null)
            _buildLegendItem(context, Theme.of(context).colorScheme.primary, currentDateRange!),
          if (previousDateRange != null)
            _buildLegendItem(context, Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), previousDateRange!),
        ];

        if (items.isEmpty) return const SizedBox.shrink();

        return constraints.maxWidth < 400
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.length > 1 ? [items[0], const SizedBox(height: AppTheme.sizeSmall), items[1]] : items,
              )
            : Wrap(spacing: AppTheme.sizeLarge, runSpacing: AppTheme.sizeSmall, children: items);
      },
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppTheme.size2XSmall))),
        const SizedBox(width: AppTheme.sizeSmall),
        Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
