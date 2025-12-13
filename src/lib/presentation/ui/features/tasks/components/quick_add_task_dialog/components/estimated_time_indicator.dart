import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';

/// Widget that displays estimated time as a badge or icon.
class EstimatedTimeIndicator extends StatelessWidget {
  final int? estimatedTime;
  final bool isExplicitlySet;

  const EstimatedTimeIndicator({
    super.key,
    required this.estimatedTime,
    required this.isExplicitlySet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (estimatedTime != null && estimatedTime! > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isExplicitlySet ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          estimatedTime.toString(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: isExplicitlySet ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    } else {
      return Icon(
        TaskUiConstants.estimatedTimeIcon,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      );
    }
  }
}
