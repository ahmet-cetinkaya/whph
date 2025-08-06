import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/utils/app_theme_helper.dart';

class BarChart extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color? barColor;
  final String? unit;
  final Widget? additionalWidget;
  final VoidCallback? onTap;
  final String title;
  final String Function(double value)? formatValue;

  const BarChart({
    super.key,
    required this.value,
    required this.maxValue,
    this.barColor,
    this.unit,
    this.additionalWidget,
    this.onTap,
    required this.title,
    this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    Color finalBarColor = barColor ?? AppThemeHelper.getRandomChartColor();

    // Calculate bar width safely
    final screenWidth = MediaQuery.sizeOf(context).width;
    final baseWidth = screenWidth - 100;

    // Use a minimum of 1.0 for maxValue to avoid division by zero
    final safeMaxValue = maxValue > 0 ? maxValue : 1.0;
    // Ensure ratio is between 0 and 1
    final ratio = (value / safeMaxValue).clamp(0.0, 1.0);
    final barWidth = baseWidth * ratio;

    return GestureDetector(
      onTap: onTap,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: finalBarColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: BoxConstraints(
                    minWidth: barWidth.isFinite ? barWidth : 0,
                    maxWidth: barWidth.isFinite ? barWidth : 0,
                    minHeight: 40,
                    maxHeight: 40,
                  ),
                ),
                SizedBox(
                  height: 40,
                  width: MediaQuery.sizeOf(context).width,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.size2XSmall),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.sizeSmall, vertical: AppTheme.size2XSmall / 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surface2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatValue?.call(value) ?? value.toStringAsFixed(1),
                                  style: AppTheme.bodySmall,
                                ),
                                if (unit != null)
                                  Text(
                                    " $unit",
                                    style: AppTheme.bodySmall,
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: AppTheme.sizeSmall),
                              child: Row(
                                children: [
                                  _buildTitle(context),
                                  if (additionalWidget != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: AppTheme.size2XSmall),
                                      child: additionalWidget!,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      title,
      style: AppTheme.bodySmall.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
