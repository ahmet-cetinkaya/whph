import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/features/app_usages/components/comparison_legend.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/acore.dart' hide Container;

/// Builds an hourly usage line chart with optional comparison data.
class HourlyUsageChart extends StatelessWidget {
  final List<ChartHourlyData> hourlyData;
  final bool showComparison;
  final String Function(String) translate;
  final String? currentDateRange;
  final String? previousDateRange;

  const HourlyUsageChart({
    super.key,
    required this.hourlyData,
    required this.showComparison,
    required this.translate,
    this.currentDateRange,
    this.previousDateRange,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = _calculateMaxY();
    final locale = Localizations.localeOf(context);
    final mainSpots = hourlyData.map((h) => FlSpot(h.hour.toDouble(), h.totalDuration.toDouble())).toList();
    final compareSpots = showComparison
        ? hourlyData.map((h) => FlSpot(h.hour.toDouble(), h.compareDuration?.toDouble() ?? 0)).toList()
        : <FlSpot>[];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: AppTheme.sizeXLarge),
            _buildChart(context, maxY, locale, mainSpots, compareSpots),
            if (showComparison) ...[
              const SizedBox(height: AppTheme.sizeMedium),
              _buildComparisonLegend(context),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateMaxY() {
    double maxY = 0;
    for (var hourData in hourlyData) {
      if (hourData.totalDuration > maxY) maxY = hourData.totalDuration.toDouble();
      if (showComparison && hourData.compareDuration != null && hourData.compareDuration! > maxY) {
        maxY = hourData.compareDuration!.toDouble();
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
          child: Icon(Icons.show_chart, size: AppTheme.iconSizeMedium, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: AppTheme.sizeMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(translate('hourlyUsage'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppTheme.size2XSmall),
              Text(translate('hourlyUsageDescription'),
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

  Widget _buildChart(
      BuildContext context, double maxY, Locale locale, List<FlSpot> mainSpots, List<FlSpot> compareSpots) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth < 400 ? 200.0 : 240.0;
        return SizedBox(
          height: chartHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: constraints.maxWidth < 400 ? 400 : constraints.maxWidth,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(AppTheme.sizeSmall),
                      tooltipMargin: AppTheme.sizeSmall,
                      getTooltipItems: (spots) => spots.map((spot) {
                        return LineTooltipItem(
                          '${DateTimeHelper.formatHour(spot.x.toInt(), locale)}\n${DateTimeHelper.formatDuration(Duration(seconds: spot.y.toInt()), locale)}',
                          const TextStyle(color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() % 4 != 0) return const SizedBox.shrink();
                          return SideTitleWidget(
                              angle: 0,
                              space: 4,
                              meta: meta,
                              child: Text(DateTimeHelper.formatHour(value.toInt(), locale)));
                        },
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
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
                    getDrawingVerticalLine: (value) =>
                        FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _createLineSeries(mainSpots, Theme.of(context).colorScheme.primary),
                    if (showComparison && compareSpots.isNotEmpty)
                      _createLineSeries(compareSpots, Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  ],
                  minX: 0,
                  maxX: 23,
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  LineChartBarData _createLineSeries(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.2)),
    );
  }

  Widget _buildComparisonLegend(BuildContext context) {
    return ComparisonLegend(
      currentDateRange: currentDateRange,
      previousDateRange: previousDateRange,
      showComparison: showComparison,
    );
  }
}

/// Data model for hourly usage in charts
class ChartHourlyData {
  final int hour;
  final int totalDuration;
  final int? compareDuration;

  ChartHourlyData({required this.hour, required this.totalDuration, this.compareDuration});
}
