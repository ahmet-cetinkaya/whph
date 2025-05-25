import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_statistics_query.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';

class AppUsageStatisticsView extends StatefulWidget {
  final String appUsageId;
  final Function(String)? onError;

  const AppUsageStatisticsView({
    super.key,
    required this.appUsageId,
    this.onError,
  });

  @override
  State<AppUsageStatisticsView> createState() => _AppUsageStatisticsViewState();
}

class _AppUsageStatisticsViewState extends State<AppUsageStatisticsView> {
  // Date range state
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Comparison state
  bool _showComparison = false;
  DateTime? _compareStartDate;
  DateTime? _compareEndDate;

  // Statistics data
  GetAppUsageStatisticsResponse? _statistics;
  GetAppUsageQueryResponse? _appUsage;
  bool _isLoading = false;
  String? _errorMessage;

  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  Color get _appUsageColor =>
      _appUsage?.color != null ? AppUsageUiConstants.getTagColor(_appUsage!.color) : Colors.blue;

  @override
  void initState() {
    super.initState();
    _fetchAppUsage();
    _fetchStatistics();
  }

  @override
  void didUpdateWidget(AppUsageStatisticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appUsageId != widget.appUsageId) {
      _fetchAppUsage();
      _fetchStatistics();
    }
  }

  Future<void> _fetchAppUsage() async {
    if (!mounted) return;

    await AsyncErrorHandler.execute(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getUsageError),
      operation: () async {
        final query = GetAppUsageQuery(id: widget.appUsageId);
        return await _mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(query);
      },
      onSuccess: (response) {
        setState(() {
          _appUsage = response;
        });
      },
    );
  }

  Future<void> _fetchStatistics() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await AsyncErrorHandler.execute(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.statisticsError),
      operation: () async {
        final query = GetAppUsageStatisticsQuery(
          appUsageId: widget.appUsageId,
          startDate: DateTimeHelper.toUtcDateTime(_startDate),
          endDate: DateTimeHelper.toUtcDateTime(_endDate),
          compareStartDate: _showComparison ? DateTimeHelper.toUtcDateTime(_compareStartDate!) : null,
          compareEndDate: _showComparison ? DateTimeHelper.toUtcDateTime(_compareEndDate!) : null,
        );

        return await _mediator.send<GetAppUsageStatisticsQuery, GetAppUsageStatisticsResponse>(query);
      },
      onSuccess: (response) {
        setState(() {
          _statistics = response;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DateRangeFilter(
              selectedStartDate: _startDate,
              selectedEndDate: _endDate,
              onDateFilterChange: (startDate, endDate) {
                setState(() {
                  _startDate = startDate ?? DateTime.now().subtract(const Duration(days: 7));
                  _endDate = endDate ?? DateTime.now();
                  _updateComparisonDates();
                });
                _fetchStatistics();
              },
            ),
            Row(
              children: [
                Text(_translationService.translate(SharedTranslationKeys.compareWithPreviousLabel)),
                const SizedBox(width: 8),
                Switch(
                  value: _showComparison,
                  onChanged: (value) {
                    setState(() {
                      _showComparison = value;
                      _updateComparisonDates();
                      _fetchStatistics();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        if (_showComparison) _buildComparisonLegend(),
        const SizedBox(height: AppTheme.sizeMedium),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_errorMessage != null)
          Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
        else if (_statistics != null) ...[
          _buildDailyUsageChart(),
          const SizedBox(height: AppTheme.sizeLarge),
          _buildHourlyUsageChart(),
        ],
      ],
    );
  }

  Widget _buildComparisonLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _appUsageColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
          Text(_formatDateRange(_startDate, _endDate)),
          const SizedBox(width: 16),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _appUsageColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
          Text(_formatDateRange(_compareStartDate!, _compareEndDate!)),
        ],
      ),
    );
  }

  Widget _buildDailyUsageChart() {
    // Find maximum value for y-axis scaling
    final dailyData = _statistics!.dailyUsage;
    double maxY = 0;

    for (var dayData in dailyData) {
      if (dayData.totalDuration > maxY) {
        maxY = dayData.totalDuration.toDouble();
      }
      if (_showComparison && dayData.compareDuration != null && dayData.compareDuration! > maxY) {
        maxY = dayData.compareDuration!.toDouble();
      }
    }

    // Add 10% buffer to max Y for better visualization
    maxY = maxY * 1.1;
    if (maxY == 0) maxY = 100; // Default if no usage data

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _translationService.translate(SharedTranslationKeys.dailyUsage),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.sizeXSmall),
        Text(
          _translationService.translate(SharedTranslationKeys.dailyUsageDescription),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppTheme.sizeLarge),
        SizedBox(
          height: 200,
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
                    String dayName = _getDayNameFromIndex(group.x.toInt());
                    return BarTooltipItem(
                      '$dayName\n${_formatDuration(rod.toY.toInt())}',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return SideTitleWidget(
                        angle: 0,
                        space: 4,
                        meta: meta,
                        child: Text(_getDayShortName(value.toInt())),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return SideTitleWidget(
                        angle: 0,
                        space: 4,
                        meta: meta,
                        child: Text(_formatDurationShort(value.toInt())),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: _statistics!.dailyUsage
                  .map((dayData) => _createBarGroup(
                        dayData.dayOfWeek,
                        dayData.totalDuration.toDouble(),
                        _showComparison ? dayData.compareDuration?.toDouble() : null,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyUsageChart() {
    // Find maximum value for y-axis scaling
    final hourlyData = _statistics!.hourlyUsage;
    double maxY = 0;

    for (var hourData in hourlyData) {
      if (hourData.totalDuration > maxY) {
        maxY = hourData.totalDuration.toDouble();
      }
      if (_showComparison && hourData.compareDuration != null && hourData.compareDuration! > maxY) {
        maxY = hourData.compareDuration!.toDouble();
      }
    }

    // Add 10% buffer to max Y for better visualization
    maxY = maxY * 1.1;
    if (maxY == 0) maxY = 100; // Default if no usage data

    // Convert hourly data to chart spots
    final mainSpots = _statistics!.hourlyUsage
        .map((hourData) => FlSpot(hourData.hour.toDouble(), hourData.totalDuration.toDouble()))
        .toList();

    final compareSpots = _showComparison
        ? _statistics!.hourlyUsage
            .map((hourData) => FlSpot(
                  hourData.hour.toDouble(),
                  hourData.compareDuration?.toDouble() ?? 0,
                ))
            .toList()
        : <FlSpot>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _translationService.translate(SharedTranslationKeys.hourlyUsage),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTheme.sizeXSmall),
        Text(
          _translationService.translate(SharedTranslationKeys.hourlyUsageDescription),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppTheme.sizeLarge),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipPadding: const EdgeInsets.all(AppTheme.sizeSmall),
                  tooltipMargin: AppTheme.sizeSmall,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final hour = spot.x.toInt();
                      final formattedHour = _formatHour(hour);
                      return LineTooltipItem(
                        '$formattedHour\n${_formatDuration(spot.y.toInt())}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      // Only show every 4 hours for better readability
                      if (value.toInt() % 4 != 0) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        angle: 0,
                        space: 4,
                        meta: meta,
                        child: Text(_formatHour(value.toInt())),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return SideTitleWidget(
                        angle: 0,
                        space: 4,
                        meta: meta,
                        child: Text(_formatDurationShort(value.toInt())),
                      );
                    },
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
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
                getDrawingVerticalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.2),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _createLineSeries(mainSpots, _appUsageColor),
                if (_showComparison && compareSpots.isNotEmpty)
                  _createLineSeries(compareSpots, _appUsageColor.withValues(alpha: 0.5)),
              ],
              minX: 0,
              maxX: 23,
              minY: 0,
              maxY: maxY,
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods for charts
  BarChartGroupData _createBarGroup(int x, double y, double? compareY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: _appUsageColor,
          width: 15,
          borderRadius: BorderRadius.circular(2),
        ),
        if (compareY != null)
          BarChartRodData(
            toY: compareY,
            color: _appUsageColor.withValues(alpha: 0.5),
            width: 15,
            borderRadius: BorderRadius.circular(2),
          ),
      ],
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
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.2),
      ),
    );
  }

  void _updateComparisonDates() {
    if (_showComparison) {
      // Set comparison period to the same length but immediately before current period
      final periodLength = _endDate.difference(_startDate);
      _compareEndDate = _startDate;
      _compareStartDate = _startDate.subtract(periodLength);
    } else {
      _compareStartDate = null;
      _compareEndDate = null;
    }
  }

  // Formatting helpers
  String _formatDateRange(DateTime start, DateTime end) {
    // Convert dates to local time zone and format them with locale
    final locale = Localizations.localeOf(context);
    final localStart = DateTimeHelper.toLocalDateTime(start);
    final localEnd = DateTimeHelper.toLocalDateTime(end);
    return '${DateTimeHelper.formatDate(localStart, locale: locale)} - ${DateTimeHelper.formatDate(localEnd, locale: locale)}';
  }

  String _getDayNameFromIndex(int index) {
    final locale = Localizations.localeOf(context);
    return DateTimeHelper.getWeekday(index, locale);
  }

  String _getDayShortName(int index) {
    final locale = Localizations.localeOf(context);
    return DateTimeHelper.getWeekdayShort(index, locale);
  }

  String _formatHour(int hour) {
    final locale = Localizations.localeOf(context);
    return DateTimeHelper.formatHour(hour, locale);
  }

  String _formatDuration(int seconds) {
    final locale = Localizations.localeOf(context);
    final duration = Duration(seconds: seconds);
    return DateTimeHelper.formatDuration(duration, locale);
  }

  String _formatDurationShort(int seconds) {
    final locale = Localizations.localeOf(context);
    final duration = Duration(seconds: seconds);
    return DateTimeHelper.formatDurationShort(duration, locale);
  }
}
