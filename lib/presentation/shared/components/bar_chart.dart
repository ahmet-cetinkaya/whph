import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';

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
    double barWidth = (MediaQuery.of(context).size.width - 100) * (value / maxValue);

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
                    minWidth: barWidth,
                    maxWidth: barWidth,
                    minHeight: 40,
                    maxHeight: 40,
                  ),
                ),
                SizedBox(
                  height: 40,
                  width: MediaQuery.of(context).size.width,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.sizeXSmall),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.sizeSmall, vertical: AppTheme.sizeXSmall / 2),
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
                                  _buildTitle(Colors.white),
                                  if (additionalWidget != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: AppTheme.sizeXSmall),
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

  Widget _buildTitle(Color textColor) {
    return Text(
      title,
      style: AppTheme.bodySmall.copyWith(
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }
}
