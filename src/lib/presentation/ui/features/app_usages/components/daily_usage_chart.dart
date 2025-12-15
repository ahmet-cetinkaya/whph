import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/acore.dart' hide Container;

/// Builds a daily usage bar chart with optional comparison data.
class DailyUsageChart extends StatelessWidget {
  final List<ChartDailyData> dailyData;
  final bool showComparison;
  final String Function(String) translate;

  const DailyUsageChart({
    super.key,
    required this.dailyData,
    required this.showComparison,
    required this.translate,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = _calculateMaxY();
    final locale = Localizations.localeOf(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: AppTheme.sizeXLarge),
            _buildChart(context, maxY, locale),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY() {
    double maxY = 0;
    for (var dayData in dailyData) {
      if (dayData.totalDuration > maxY) maxY = dayData.totalDuration.toDouble();
      if (showComparison && dayData.compareDuration != null && dayData.compareDuration! > maxY) {
        maxY = dayData.compareDuration!.toDouble();
      }
    }
    return maxY == 0 ? 100 : maxY * 1.1;
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.sizeSmall),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
          ),
          child: Icon(Icons.bar_chart, size: AppTheme.iconSizeMedium, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: AppTheme.sizeMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(translate('dailyUsage'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppTheme.size2XSmall),
              Text(translate('dailyUsageDescription'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, double maxY, Locale locale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth < 400 ? 200.0 : 240.0;
        return SizedBox(
          height: chartHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth < 400 ? 400 : constraints.maxWidth,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(AppTheme.sizeSmall),
                      tooltipMargin: AppTheme.sizeSmall,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String dayName = DateTimeHelper.getWeekday(group.x.toInt(), locale);
                        return BarTooltipItem(
                            '$dayName\n${DateTimeHelper.formatDuration(Duration(seconds: rod.toY.toInt()), locale)}',
                            const TextStyle(color: Colors.white));
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                            angle: 0,
                            space: 4,
                            meta: meta,
                            child: Text(DateTimeHelper.getWeekdayShort(value.toInt(), locale))),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                            angle: 0,
                            space: 4,
                            meta: meta,
                            child: Text(DateTimeHelper.formatDurationShort(Duration(seconds: value.toInt()), locale))),
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: dailyData
                      .map((d) => _createBarGroup(context, d.dayOfWeek, d.totalDuration.toDouble(),
                          showComparison ? d.compareDuration?.toDouble() : null))
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BarChartGroupData _createBarGroup(BuildContext context, int x, double y, double? compareY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
            toY: y, color: Theme.of(context).colorScheme.primary, width: 15, borderRadius: BorderRadius.circular(2)),
        if (compareY != null)
          BarChartRodData(
              toY: compareY,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              width: 15,
              borderRadius: BorderRadius.circular(2)),
      ],
    );
  }
}

/// Data model for daily usage in charts
class ChartDailyData {
  final int dayOfWeek;
  final int totalDuration;
  final int? compareDuration;

  ChartDailyData({required this.dayOfWeek, required this.totalDuration, this.compareDuration});
}
