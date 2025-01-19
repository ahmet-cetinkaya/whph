import 'package:flutter/material.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/app_theme_helper.dart';

class BarChart extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color? barColor;
  final String unit;
  final Widget? additionalWidget;
  final VoidCallback? onTap;
  final String title;

  const BarChart({
    super.key,
    required this.value,
    required this.maxValue,
    this.barColor,
    this.unit = "",
    this.additionalWidget,
    this.onTap,
    required this.title,
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
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                  value.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  " $unit",
                                  style: const TextStyle(fontSize: AppTheme.fontSizeSmall),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Row(
                                children: [
                                  _buildTitle(Colors.white),
                                  if (additionalWidget != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
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
      style: TextStyle(
        fontSize: 13, // Reduced from 16
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }
}
