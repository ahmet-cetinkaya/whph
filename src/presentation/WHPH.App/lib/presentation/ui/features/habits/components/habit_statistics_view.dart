import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'dart:async';
import 'package:whph/core/application/features/habits/queries/get_habit_query.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habit_records_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:acore/acore.dart' show DateTimeHelper;
import 'package:whph/presentation/ui/shared/components/section_header.dart';

class HabitStatisticsView extends StatefulWidget {
  final String habitId;

  const HabitStatisticsView({
    super.key,
    required this.habitId,
  });

  @override
  State<HabitStatisticsView> createState() => _HabitStatisticsViewState();
}

class _HabitStatisticsViewState extends State<HabitStatisticsView> {
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();
  final _mediator = container.resolve<Mediator>();
  final _themeService = container.resolve<IThemeService>();

  GetHabitQueryResponse? _habit;
  GetListHabitRecordsQueryResponse? _habitRecords;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _loadData();
  }

  @override
  void dispose() {
    _removeEventListeners();
    _refreshDebounce?.cancel();
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
    _debouncedLoadData();
  }

  void _handleHabitRecordChanged() {
    if (!mounted) return;
    String? habitId = _habitsService.onHabitRecordAdded.value ?? _habitsService.onHabitRecordRemoved.value;
    if (habitId != widget.habitId) return;
    _debouncedLoadData();
  }

  void _debouncedLoadData() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    await _getHabit();
    await _getHabitRecords();
  }

  Future<void> _getHabit() async {
    await AsyncErrorHandler.execute<GetHabitQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingDetailsError),
      operation: () async {
        final query = GetHabitQuery(id: widget.habitId);
        return await _mediator.send<GetHabitQuery, GetHabitQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            _habit = result;
          });
        }
      },
    );
  }

  Future<void> _getHabitRecords() async {
    await AsyncErrorHandler.execute<GetListHabitRecordsQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(HabitTranslationKeys.loadingRecordsError),
      operation: () async {
        // Get all records by using a wide date range
        final now = DateTime.now();
        final startDate = DateTime(2020, 1, 1); // Far past date
        final endDate = DateTime(now.year + 1, 12, 31); // Far future date
        final query = GetListHabitRecordsQuery(
          habitId: widget.habitId,
          startDate: startDate,
          endDate: endDate,
          pageIndex: 0,
          pageSize: 1000,
        );
        return await _mediator.send<GetListHabitRecordsQuery, GetListHabitRecordsQueryResponse>(query);
      },
      onSuccess: (result) {
        if (mounted) {
          setState(() {
            _habitRecords = result;
          });
        }
      },
    );
  }

  Widget _buildStatusBanner() {
    final firstRecordDate = _habitRecords!.items.isNotEmpty
        ? _habitRecords!.items.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b)
        : _habit!.createdDate;

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
              _translationService.translate(HabitTranslationKeys.statisticsArchivedWarning, namedArgs: {
                'startDate': DateTimeHelper.formatDate(firstRecordDate),
                'archivedDate': DateTimeHelper.formatDate(DateTimeHelper.toLocalDateTime(_habit!.archivedDate!))
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
    if (_habit == null || _habitRecords == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: _translationService.translate(HabitTranslationKeys.statisticsLabel),
        ),
        const SizedBox(height: AppTheme.sizeSmall),
        if (_habit!.archivedDate != null) ...[
          _buildStatusBanner(),
          const SizedBox(height: AppTheme.sizeSmall),
        ],
        _buildStatisticsRow(),
        const SizedBox(height: AppTheme.sizeSmall),
        _buildScoreChart(),
        const SizedBox(height: AppTheme.sizeSmall),
        _buildStreaksSection(),
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildStatCard(_translationService.translate(HabitTranslationKeys.overall),
                          _habit!.statistics.overallScore)),
                  const SizedBox(width: 8),
                  if (_habit!.hasGoal && _habit!.statistics.goalSuccessRate != null) ...[
                    Expanded(
                      child: _buildStatCard(
                        _translationService.translate(HabitTranslationKeys.currentGoal),
                        _habit!.statistics.goalSuccessRate!,
                        customValue: "${_habit!.statistics.daysGoalMet}/${_habit!.statistics.totalDaysWithGoal}",
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                      child: _buildStatCard(_translationService.translate(HabitTranslationKeys.monthly),
                          _habit!.statistics.monthlyScore)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildStatCard(
                          _translationService.translate(HabitTranslationKeys.yearly), _habit!.statistics.yearlyScore)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildStatCard(_translationService.translate(HabitTranslationKeys.records),
                          _habit!.statistics.totalRecords.toDouble(),
                          isCount: true)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, double value, {bool isCount = false, String? subtitle, String? customValue}) {
    // Calculate percentage for the background bar
    double percentage = isCount ? 0 : value.clamp(0.0, 1.0);

    return Card(
      color: AppTheme.surface1,
      child: Stack(
        children: [
          // Background bar showing progress (only for non-count values)
          if (!isCount)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    flex: (percentage * 100).toInt(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _themeService.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - percentage) * 100).toInt(),
                    child: const SizedBox(),
                  ),
                ],
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeMedium, horizontal: AppTheme.sizeSmall),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.size2XSmall),
                  Text(
                    customValue ??
                        (isCount
                            ? HabitUiConstants.formatRecordCount(value.toInt())
                            : HabitUiConstants.formatScore(value)),
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChart() {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.sizeSmall),
                  decoration: BoxDecoration(
                    color: _themeService.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
                  ),
                  child: Icon(
                    Icons.show_chart,
                    size: AppTheme.iconSizeMedium,
                    color: _themeService.primaryColor,
                  ),
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Text(
                  _translationService.translate(HabitTranslationKeys.scoreTrends),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeXLarge),
            SizedBox(
              height: 300,
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
                          if (value.toInt() >= 0 && value.toInt() < _habit!.statistics.monthlyScores.length) {
                            final date = _habit!.statistics.monthlyScores[value.toInt()].key;
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
                      spots: _habit!.statistics.monthlyScores
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), double.parse(e.value.value.toStringAsFixed(2))))
                          .toList(),
                      isCurved: true,
                      color: _themeService.primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _themeService.primaryColor.withAlpha((255 * 0.2).toInt()),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreaksSection() {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.sizeSmall),
                  decoration: BoxDecoration(
                    color: _themeService.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    size: AppTheme.iconSizeMedium,
                    color: _themeService.primaryColor,
                  ),
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Text(
                  _translationService.translate(HabitTranslationKeys.topStreaks),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeXLarge),
            if (_habit!.statistics.topStreaks.isNotEmpty) ...[
              ..._buildStreakBars(),
            ] else ...[
              _buildNoStreaksMessage(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStreakBars() {
    int maxDays = _habit!.statistics.topStreaks.first.days;
    return _habit!.statistics.topStreaks
        .take(5)
        .map(
          (streak) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildStreakBar(streak, maxDays, _habit!.hasGoal),
          ),
        )
        .toList();
  }

  Widget _buildNoStreaksMessage() {
    return Card(
      color: AppTheme.surface1,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.timeline,
                size: 48,
                color: _themeService.primaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppTheme.sizeSmall),
              Text(
                _translationService.translate(HabitTranslationKeys.noStreaksYet),
                style: AppTheme.bodyMedium.copyWith(
                  color: _themeService.primaryColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBar(HabitStreak streak, int maxDays, bool hasGoal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Start date
          SizedBox(
            width: 60,
            child: Text(
              DateTimeHelper.formatDate(streak.startDate, format: 'M/d'),
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
                                color: _themeService.primaryColor,
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
                                color: _themeService.primaryColor,
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    // Display text with appropriate unit
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasGoal && streak.completions != null
                            ? '${streak.completions} ${_translationService.translate(HabitTranslationKeys.completions)}'
                            : '${streak.days} ${_translationService.translate(SharedTranslationKeys.days)}',
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
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
              DateTimeHelper.formatDate(streak.endDate, format: 'M/d'),
              style: const TextStyle(fontSize: AppTheme.fontSizeSmall, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
