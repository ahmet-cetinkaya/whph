import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/services/habits_service.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whph/presentation/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';

class HabitStatisticsView extends StatefulWidget {
  final HabitStatistics statistics;
  final String habitId;
  final DateTime? archivedDate;
  final DateTime firstRecordDate;

  const HabitStatisticsView({
    super.key,
    required this.statistics,
    required this.habitId,
    required this.firstRecordDate,
    this.archivedDate,
  });

  @override
  State<HabitStatisticsView> createState() => _HabitStatisticsViewState();
}

class _HabitStatisticsViewState extends State<HabitStatisticsView> {
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  void _setupEventListeners() {
    _habitsService.onHabitUpdated.addListener(_handleHabitChanged);
    _habitsService.onHabitRecordAdded.addListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.addListener(_handleHabitRecordChanged);
  }

  void _removeEventListeners() {
    _habitsService.onHabitUpdated.removeListener(_handleHabitChanged);
    _habitsService.onHabitRecordAdded.removeListener(_handleHabitRecordChanged);
    _habitsService.onHabitRecordRemoved.removeListener(_handleHabitRecordChanged);
  }

  void _handleHabitChanged() {
    if (!mounted || _habitsService.onHabitUpdated.value != widget.habitId) return;
    setState(() {});
  }

  void _handleHabitRecordChanged() {
    if (!mounted) return;
    String? habitId = _habitsService.onHabitRecordAdded.value ?? _habitsService.onHabitRecordRemoved.value;
    if (habitId != widget.habitId) return;
    setState(() {});
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Icon(HabitUiConstants.statisticsIcon),
        ),
        Text(_translationService.translate(HabitTranslationKeys.statisticsLabel), style: AppTheme.bodyLarge),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final dateFormatter = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.archivedDate != null
                  ? _translationService.translate(HabitTranslationKeys.statisticsArchivedWarning, namedArgs: {
                      'startDate': dateFormatter.format(widget.firstRecordDate),
                      'archivedDate': dateFormatter.format(widget.archivedDate!)
                    })
                  : _translationService.translate(HabitTranslationKeys.statisticsActiveNote, namedArgs: {
                      'startDate': dateFormatter.format(widget.firstRecordDate),
                      'currentDate': dateFormatter.format(DateTime.now())
                    }),
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: 16),
        _buildStatusBanner(),
        _buildStatisticsRow(),
        const SizedBox(height: 24),
        _buildScoreChart(),
        if (widget.statistics.topStreaks.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildStreaksSection(),
        ],
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard(
                _translationService.translate(HabitTranslationKeys.overall), widget.statistics.overallScore)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard(
                _translationService.translate(HabitTranslationKeys.monthly), widget.statistics.monthlyScore)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard(
                _translationService.translate(HabitTranslationKeys.yearly), widget.statistics.yearlyScore)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard(
                _translationService.translate(HabitTranslationKeys.records), widget.statistics.totalRecords.toDouble(),
                isCount: true)),
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
          _translationService.translate(HabitTranslationKeys.scoreTrends),
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
                        if (value.toInt() >= 0 && value.toInt() < widget.statistics.monthlyScores.length) {
                          final date = widget.statistics.monthlyScores[value.toInt()].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _translationService.translate(SharedTranslationKeys.getShortMonthKey(date.month)),
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
                    spots: widget.statistics.monthlyScores
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
                      color: AppTheme.primaryColor.withAlpha((255 * 0.2).toInt()),
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
    int maxDays = widget.statistics.topStreaks.first.days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            _translationService.translate(HabitTranslationKeys.topStreaks),
            style: AppTheme.bodyLarge,
          ),
        ),
        ...widget.statistics.topStreaks.take(5).map(
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
                      '${streak.days} ${_translationService.translate(SharedTranslationKeys.days)}',
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
