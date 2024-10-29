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
        title: Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            // Bar
            Stack(
              children: [
                Container(
                  height: 60,
                  width: barWidth,
                  decoration: BoxDecoration(
                    color: finalBarColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(
                  height: 60,
                  width: MediaQuery.of(context).size.width,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min, // Add this line
                        children: [
                          // Label
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.surface2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  value.toStringAsFixed(1),
                                ),
                                Text(
                                  " $unit",
                                  style: const TextStyle(fontSize: AppTheme.fontSizeSmall),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: additionalWidget == null
                                ? _buildTitle()
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title
                                      _buildTitle(),
                                      // Additional Widget
                                      additionalWidget!,
                                    ],
                                  ),
                          ),
                        ],
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

  Widget _buildTitle() {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
