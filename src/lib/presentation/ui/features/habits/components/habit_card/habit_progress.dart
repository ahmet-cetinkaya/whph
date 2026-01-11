import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/core/domain/features/habits/habit_record_status.dart';

class HabitProgress extends StatelessWidget {
  final int currentCount;
  final int dailyTarget;
  final bool isDisabled;
  final VoidCallback? onTap;
  final bool useLargeSize;
  final bool isThreeStateEnabled;
  final HabitRecordStatus status;

  const HabitProgress({
    super.key,
    required this.currentCount,
    required this.dailyTarget,
    required this.isDisabled,
    required this.onTap,
    this.useLargeSize = false,
    this.isThreeStateEnabled = false,
    this.status = HabitRecordStatus.skipped,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = currentCount >= dailyTarget;
    final double iconSize = useLargeSize ? 24.0 : AppTheme.iconSizeMedium;

    // Determine icon and color based on status and count
    IconData mainIcon;
    Color mainColor;
    Color badgeColor;

    if (isDisabled) {
      mainIcon = Icons.close;
      mainColor = AppTheme.textColor.withValues(alpha: 0.3);
      badgeColor = AppTheme.textColor.withValues(alpha: 0.3);
    } else if (status == HabitRecordStatus.notDone) {
      mainIcon = Icons.close;
      mainColor = Colors.red.withValues(alpha: 0.7);
      badgeColor = Colors.transparent; // Hide badge for NotDone
    } else if (isComplete) {
      mainIcon = Icons.link;
      mainColor = Colors.green;
      badgeColor = Colors.green;
    } else if (currentCount > 0) {
      mainIcon = Icons.add;
      mainColor = Colors.blue;
      badgeColor = Colors.orange;
    } else {
      // Skipped status - Check 3-state setting
      if (isThreeStateEnabled) {
        mainIcon = Icons.question_mark;
        mainColor = Colors.grey;
        badgeColor = Colors.grey;
      } else {
        // If 3-state disabled, Skipped/Empty acts like Not Done (visual only)
        mainIcon = Icons.close;
        mainColor = Colors.red.withValues(alpha: 0.7);
        badgeColor = Colors.transparent;
      }
    }

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
                mainIcon,
                size: iconSize,
                color: mainColor,
              ),
              // Count badge in bottom right
              if (currentCount > 0 && badgeColor != Colors.transparent)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
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
