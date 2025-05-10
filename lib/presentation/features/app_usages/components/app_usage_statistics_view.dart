import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_statistics_query.dart';
import 'package:whph/application/features/app_usages/queries/get_app_usage_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';

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

    try {
      final query = GetAppUsageQuery(id: widget.appUsageId);
      final response = await _mediator.send<GetAppUsageQuery, GetAppUsageQueryResponse>(query);

      if (mounted) {
        setState(() {
          _appUsage = response;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.getUsageError),
        );
      }
    }
  }

  Future<void> _fetchStatistics() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = GetAppUsageStatisticsQuery(
        appUsageId: widget.appUsageId,
        startDate: _startDate,
        endDate: _endDate,
        compareStartDate: _showComparison ? _compareStartDate : null,
        compareEndDate: _showComparison ? _compareEndDate : null,
      );

      final response = await _mediator.send<GetAppUsageStatisticsQuery, GetAppUsageStatisticsResponse>(query);

      if (mounted) {
        setState(() {
          _statistics = response;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _translationService.translate(AppUsageTranslationKeys.statisticsError);
        });

        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.statisticsError),
        );

        widget.onError?.call(_errorMessage!);
      }
    }
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
    final dateFormat = DateFormat('MMM d');
    return '${dateFormat.format(start)} - ${dateFormat.format(end)}';
  }

  String _getDayNameFromIndex(int index) {
    String translationKey = 'shared.calendar.week_days.';

    switch (index) {
      case 1:
        translationKey += 'mon';
        break;
      case 2:
        translationKey += 'tue';
        break;
      case 3:
        translationKey += 'wed';
        break;
      case 4:
        translationKey += 'thu';
        break;
      case 5:
        translationKey += 'fri';
        break;
      case 6:
        translationKey += 'sat';
        break;
      case 7:
        translationKey += 'sun';
        break;
      default:
        return '';
    }

    return _translationService.translate(translationKey);
  }

  String _getDayShortName(int index) {
    return _getDayNameFromIndex(index);
  }

  String _formatHour(int hour) {
    return '${hour % 12 == 0 ? 12 : hour % 12}${hour < 12 ? 'am' : 'pm'}';
  }

  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours h ${minutes > 0 ? '$minutes m' : ''}';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '${duration.inSeconds} sec';
    }
  }

  String _formatDurationShort(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
