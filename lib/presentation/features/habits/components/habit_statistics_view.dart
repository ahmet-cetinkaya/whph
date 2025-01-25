import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whph/presentation/features/habits/constants/habit_ui_constants.dart';

class HabitStatisticsView extends StatelessWidget {
  final HabitStatistics statistics;

  const HabitStatisticsView({super.key, required this.statistics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: 8),
        _buildStatisticsRow(),
        const SizedBox(height: 24),
        _buildScoreChart(),
        if (statistics.topStreaks.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildStreaksSection(),
        ],
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Icon(HabitUiConstants.statisticsIcon),
        ),
        Text(HabitUiConstants.statisticsLabel, style: AppTheme.bodyLarge),
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(HabitUiConstants.overallLabel, statistics.overallScore)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(HabitUiConstants.monthlyLabel, statistics.monthlyScore)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(HabitUiConstants.yearlyLabel, statistics.yearlyScore)),
        const SizedBox(width: 8),
        Expanded(
            child:
                _buildStatCard(HabitUiConstants.recordsCountLabel, statistics.totalRecords.toDouble(), isCount: true)),
      ],
    );
  }

  Widget _buildStatCard(String label, double value, {bool isCount = false}) {
    return Card(
      color: AppTheme.surface1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isCount ? HabitUiConstants.formatRecordCount(value.toInt()) : HabitUiConstants.formatScore(value),
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          HabitUiConstants.scoreTrendsLabel,
          style: AppTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text('${(value * 100).toInt()}%');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < statistics.monthlyScores.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MMM').format(statistics.monthlyScores[value.toInt()].key),
                              style: AppTheme.bodySmall,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: statistics.monthlyScores
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), double.parse(e.value.value.toStringAsFixed(2))))
                        .toList(),
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreaksSection() {
    int maxDays = statistics.topStreaks.first.days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            HabitUiConstants.topStreaksLabel,
            style: AppTheme.bodyLarge,
          ),
        ),
        ...statistics.topStreaks.take(5).map(
              (streak) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildStreakBar(streak, maxDays),
              ),
            ),
      ],
    );
  }

  Widget _buildStreakBar(HabitStreak streak, int maxDays) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Start date
          SizedBox(
            width: 60,
            child: Text(
              DateFormat('M/d').format(streak.startDate),
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 8),
          // Bar chart
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween<double>(begin: 0, end: streak.days / maxDays),
                          builder: (context, double value, child) {
                            return Container(
                              width: (constraints.maxWidth / 2) * value,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                              ),
                            );
                          },
                        ),
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween<double>(begin: 0, end: streak.days / maxDays),
                          builder: (context, double value, child) {
                            return Container(
                              width: (constraints.maxWidth / 2) * value,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    // Days text
                    Text(
                      HabitUiConstants.formatDayCount(streak.days),
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.surface1,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // End date
          SizedBox(
            width: 60,
            child: Text(
              DateFormat('M/d').format(streak.endDate),
              style: const TextStyle(fontSize: AppTheme.fontSizeSmall, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
