import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/queries/get_app_usage_statistics_query.dart';

import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';

import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/date_range_filter.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/components/persistent_list_options_base.dart';
import 'package:whph/presentation/ui/shared/components/save_button.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/features/app_usages/models/app_usage_statistics_settings.dart';
import 'package:acore/acore.dart' hide Container;

class AppUsageStatisticsView extends PersistentListOptionsBase {
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

class _AppUsageStatisticsViewState extends PersistentListOptionsBaseState<AppUsageStatisticsView> {
  // Date range state - initialized to Last Week
  DateFilterSetting? _dateFilterSetting;
  DateTime? _startDate;
  DateTime? _endDate;

  // Comparison state
  bool _showComparison = false;
  DateTime? _compareStartDate;
  DateTime? _compareEndDate;

  // Statistics data
  GetAppUsageStatisticsResponse? _statistics;

  bool _isLoading = false;
  String? _errorMessage;

  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();

    // Initialize with Last Week and auto-refresh enabled
    final now = DateTime.now();
    final lastWeekStart = now.subtract(const Duration(days: 7));

    _startDate = lastWeekStart;
    _endDate = now;

    _dateFilterSetting = DateFilterSetting.quickSelection(
      key: 'last_week',
      startDate: _startDate!,
      endDate: _endDate!,
      isAutoRefreshEnabled: true,
    );

    // Enable comparison by default
    _showComparison = true;
    _updateComparisonDates();

    // _fetchStatistics() will be called after settings are loaded or if defaults are used
    if (!isLoadingSettings) {
      _fetchStatistics();
    }
  }

  @override
  void initSettingKey() {
    settingKey = SettingKeys.appUsageStatisticsFilterSettings;
  }

  @override
  Future<void> loadSavedListOptionSettings() async {
    setState(() {
      isLoadingSettings = true;
    });

    final savedSettings = await filterSettingsManager.loadFilterSettings(
      settingKey: settingKey,
    );

    if (savedSettings != null) {
      final settings = AppUsageStatisticsSettings.fromJson(savedSettings);

      setState(() {
        if (settings.dateFilterSetting != null) {
          _dateFilterSetting = settings.dateFilterSetting;
          if (_dateFilterSetting!.isQuickSelection) {
            final currentRange = _dateFilterSetting!.calculateCurrentDateRange();
            _startDate = currentRange.startDate;
            _endDate = currentRange.endDate;
          } else {
            _startDate = _dateFilterSetting!.startDate;
            _endDate = _dateFilterSetting!.endDate;
          }
        }

        _showComparison = settings.showComparison;
        _updateComparisonDates();
      });
    }

    if (mounted) {
      setState(() {
        isSettingLoaded = true;
        isLoadingSettings = false;
        hasUnsavedChanges = false;
      });
      _fetchStatistics();
    }
  }

  @override
  Future<void> saveFilterSettings() async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.savingError),
      operation: () async {
        final settings = AppUsageStatisticsSettings(
          dateFilterSetting: _dateFilterSetting,
          showComparison: _showComparison,
        );

        await filterSettingsManager.saveFilterSettings(
          settingKey: settingKey,
          filterSettings: settings.toJson(),
        );

        if (mounted) {
          setState(() {
            hasUnsavedChanges = false;
          });
          showSavedMessageTemporarily();
        }
      },
    );
  }

  @override
  Future<void> checkForUnsavedChanges() async {
    final currentSettings = AppUsageStatisticsSettings(
      dateFilterSetting: _dateFilterSetting,
      showComparison: _showComparison,
    ).toJson();

    final hasChanges = await filterSettingsManager.hasUnsavedChanges(
      settingKey: settingKey,
      currentSettings: currentSettings,
    );

    if (mounted && hasUnsavedChanges != hasChanges) {
      setState(() {
        hasUnsavedChanges = hasChanges;
      });
    }
  }

  @override
  void didUpdateWidget(AppUsageStatisticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appUsageId != widget.appUsageId) {
      _fetchStatistics();
    }
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
        // Only fetch statistics if dates are available
        if (_startDate == null || _endDate == null) {
          setState(() {
            _statistics = null;
            _isLoading = false;
          });
          return null; // No error, just no data to fetch
        }

        final query = GetAppUsageStatisticsQuery(
          appUsageId: widget.appUsageId,
          startDate: DateTimeHelper.toUtcDateTime(_startDate!),
          endDate: DateTimeHelper.toUtcDateTime(_endDate!),
          compareStartDate:
              _showComparison && _compareStartDate != null ? DateTimeHelper.toUtcDateTime(_compareStartDate!) : null,
          compareEndDate:
              _showComparison && _compareEndDate != null ? DateTimeHelper.toUtcDateTime(_compareEndDate!) : null,
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.sizeMedium,
        children: [
          // Header Section - Filter Options with Comparison Toggle
          Row(
            children: [
              DateRangeFilter(
                dateFilterSetting: _dateFilterSetting,
                selectedStartDate: _dateFilterSetting != null ? _startDate : null,
                selectedEndDate: _dateFilterSetting != null ? _endDate : null,
                onDateFilterChange: (startDate, endDate) {
                  setState(() {
                    _startDate = startDate;
                    _endDate = endDate;
                    _updateComparisonDates();
                    handleFilterChange();
                  });
                  _fetchStatistics();
                },
                onDateFilterSettingChange: (dateFilterSetting) {
                  setState(() {
                    _dateFilterSetting = dateFilterSetting;
                    if (dateFilterSetting?.isQuickSelection == true) {
                      final currentRange = dateFilterSetting!.calculateCurrentDateRange();
                      _startDate = currentRange.startDate;
                      _endDate = currentRange.endDate;
                    } else if (dateFilterSetting != null) {
                      _startDate = dateFilterSetting.startDate;
                      _endDate = dateFilterSetting.endDate;
                    } else {
                      // Clear operation
                      _startDate = null;
                      _endDate = null;
                    }
                    _updateComparisonDates();
                    handleFilterChange();
                  });
                  _fetchStatistics();
                },
              ),
              const SizedBox(width: AppTheme.sizeSmall),
              _buildComparisonToggle(),
              const SizedBox(width: AppTheme.sizeSmall),
              SaveButton(
                hasUnsavedChanges: hasUnsavedChanges,
                showSavedMessage: showSavedMessage,
                onSave: saveFilterSettings,
                tooltip: _translationService.translate(SharedTranslationKeys.saveListOptions),
              ),
            ],
          ),
          // Loading
          if (_isLoading)
            _buildLoadingState()
          // Error
          else if (_errorMessage != null)
            _buildErrorState()
          // Empty state
          else if (_startDate == null || _endDate == null)
            _buildEmptyState()
          // General Statistics
          else if (_statistics != null) ...[
            _buildSummaryCards(),
            if (_showComparison &&
                _startDate != null &&
                _endDate != null &&
                _compareStartDate != null &&
                _compareEndDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
                child: _buildComparisonLegend(),
              ),
            _buildDailyUsageChart(),
            _buildHourlyUsageChart(),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonToggle() {
    return IconButton(
      icon: Icon(Icons.compare_arrows),
      color: _showComparison ? Theme.of(context).colorScheme.primary : null,
      tooltip: _translationService.translate(SharedTranslationKeys.compareWithPreviousLabel),
      onPressed: () {
        setState(() {
          _showComparison = !_showComparison;
          _updateComparisonDates();
          handleFilterChange();
        });
        _fetchStatistics();
      },
    );
  }

  Widget _buildComparisonLegend() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 500;

        if (isNarrowScreen) {
          // Stack legend items vertically on narrow screens
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(
                Theme.of(context).colorScheme.primary,
                _formatDateRange(_startDate!, _endDate!),
              ),
              const SizedBox(height: AppTheme.sizeSmall),
              _buildLegendItem(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                _formatDateRange(_compareStartDate!, _compareEndDate!),
              ),
            ],
          );
        } else {
          // Side by side layout for wider screens
          return Wrap(
            spacing: AppTheme.sizeLarge,
            runSpacing: AppTheme.sizeSmall,
            children: [
              _buildLegendItem(
                Theme.of(context).colorScheme.primary,
                _formatDateRange(_startDate!, _endDate!),
              ),
              _buildLegendItem(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                _formatDateRange(_compareStartDate!, _compareEndDate!),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTheme.size2XSmall),
          ),
        ),
        const SizedBox(width: AppTheme.sizeSmall),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.size4XLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppTheme.sizeLarge),
            Text(
              _translationService.translate(SharedTranslationKeys.loadingMessage),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: AppTheme.iconSizeXLarge,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.sizeMedium),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.size4XLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range,
              size: AppTheme.iconSizeXLarge,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.sizeLarge),
            Text(
              _translationService.translate(SharedTranslationKeys.selectDateRangeMessage),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            Text(
              _translationService.translate(SharedTranslationKeys.selectDateRangeDescription),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_statistics == null) return const SizedBox.shrink();

    // Calculate summary statistics
    final totalSeconds = _statistics!.dailyUsage.fold<int>(
      0,
      (sum, day) => sum + day.totalDuration,
    );
    final dayCount = _statistics!.dailyUsage.where((day) => day.totalDuration > 0).length;
    final avgDailySeconds = dayCount > 0 ? totalSeconds ~/ dayCount : 0;

    // Find peak hour
    var peakHour = 0;
    var peakDuration = 0;
    for (var hourData in _statistics!.hourlyUsage) {
      if (hourData.totalDuration > peakDuration) {
        peakDuration = hourData.totalDuration;
        peakHour = hourData.hour;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;

        if (isNarrowScreen) {
          return Column(
            children: [
              _buildSummaryCard(
                label: _translationService.translate(SharedTranslationKeys.totalUsageLabel),
                value: _formatDuration(totalSeconds),
              ),
              const SizedBox(height: AppTheme.sizeMedium),
              _buildSummaryCard(
                label: _translationService.translate(SharedTranslationKeys.averageDailyLabel),
                value: _formatDuration(avgDailySeconds),
              ),
              const SizedBox(height: AppTheme.sizeMedium),
              _buildSummaryCard(
                label: _translationService.translate(SharedTranslationKeys.peakHourLabel),
                value: _formatHour(peakHour),
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  label: _translationService.translate(SharedTranslationKeys.totalUsageLabel),
                  value: _formatDuration(totalSeconds),
                ),
              ),
              const SizedBox(width: AppTheme.sizeMedium),
              Expanded(
                child: _buildSummaryCard(
                  label: _translationService.translate(SharedTranslationKeys.averageDailyLabel),
                  value: _formatDuration(avgDailySeconds),
                ),
              ),
              const SizedBox(width: AppTheme.sizeMedium),
              Expanded(
                child: _buildSummaryCard(
                  label: _translationService.translate(SharedTranslationKeys.peakHourLabel),
                  value: _formatHour(peakHour),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
  }) {
    return Card(
      color: AppTheme.surface1,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.sizeMedium,
          horizontal: AppTheme.sizeSmall,
        ),
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
                value,
                style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
                  ),
                  child: Icon(
                    Icons.bar_chart,
                    size: AppTheme.iconSizeMedium,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _translationService.translate(SharedTranslationKeys.dailyUsage),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppTheme.size2XSmall),
                      Text(
                        _translationService.translate(SharedTranslationKeys.dailyUsageDescription),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeXLarge),
            // Daily Usage Chart - Responsive Container
            LayoutBuilder(
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
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
                  ),
                  child: Icon(
                    Icons.show_chart,
                    size: AppTheme.iconSizeMedium,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.sizeMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _translationService.translate(SharedTranslationKeys.hourlyUsage),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppTheme.size2XSmall),
                      Text(
                        _translationService.translate(SharedTranslationKeys.hourlyUsageDescription),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sizeXLarge),
            // Hourly Usage Chart - Responsive Container
            LayoutBuilder(
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
                            _createLineSeries(mainSpots, Theme.of(context).colorScheme.primary),
                            if (_showComparison && compareSpots.isNotEmpty)
                              _createLineSeries(
                                  compareSpots, Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
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
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for charts
  BarChartGroupData _createBarGroup(int x, double y, double? compareY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: Theme.of(context).colorScheme.primary,
          width: 15,
          borderRadius: BorderRadius.circular(2),
        ),
        if (compareY != null)
          BarChartRodData(
            toY: compareY,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
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
    if (_showComparison && _startDate != null && _endDate != null) {
      // Set comparison period to the same length but immediately before current period
      final periodLength = _endDate!.difference(_startDate!);
      _compareEndDate = _startDate;
      _compareStartDate = _startDate!.subtract(periodLength);
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
