import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

class HabitProgress extends StatelessWidget {
  final int currentCount;
  final int dailyTarget;
  final bool isDisabled;
  final VoidCallback? onTap;
  final bool useLargeSize;

  const HabitProgress({
    super.key,
    required this.currentCount,
    required this.dailyTarget,
    required this.isDisabled,
    required this.onTap,
    this.useLargeSize = false,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = currentCount >= dailyTarget;
    final double iconSize = useLargeSize ? 24.0 : AppTheme.iconSizeMedium;

    return SizedBox(
      width: 36, // Fixed width
      height: 36, // Fixed height
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main icon in center
              Icon(
                isDisabled
                    ? Icons.close
                    : isComplete
                        ? Icons.link
                        : currentCount > 0
                            ? Icons.add
                            : Icons.close,
                size: iconSize,
                color: isDisabled
                    ? AppTheme.textColor.withValues(alpha: 0.3)
                    : isComplete
                        ? Colors.green
                        : currentCount > 0
                            ? Colors.blue
                            : Colors.red.withValues(alpha: 0.7),
              ),
              // Count badge in bottom right
              if (currentCount > 0)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDisabled
                          ? AppTheme.textColor.withValues(alpha: 0.3)
                          : isComplete
                              ? Colors.green
                              : currentCount > 0
                                  ? Colors.orange
                                  : Colors.red.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$currentCount',
                      style: TextStyle(
                        fontSize: useLargeSize ? 10 : 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
