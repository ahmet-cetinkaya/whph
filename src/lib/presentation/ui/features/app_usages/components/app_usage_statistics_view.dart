import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/queries/get_app_usage_statistics_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/features/app_usages/components/daily_usage_chart.dart';
import 'package:whph/presentation/ui/features/app_usages/components/hourly_usage_chart.dart';
import 'package:whph/presentation/ui/features/app_usages/components/statistics_summary_cards.dart';
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

  const AppUsageStatisticsView({super.key, required this.appUsageId, this.onError});

  @override
  State<AppUsageStatisticsView> createState() => _AppUsageStatisticsViewState();
}

class _AppUsageStatisticsViewState extends PersistentListOptionsBaseState<AppUsageStatisticsView> {
  DateFilterSetting? _dateFilterSetting;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showComparison = false;
  DateTime? _compareStartDate;
  DateTime? _compareEndDate;
  GetAppUsageStatisticsResponse? _statistics;
  bool _isLoading = false;
  String? _errorMessage;

  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 7));
    _endDate = now;
    _dateFilterSetting = DateFilterSetting.quickSelection(
        key: 'last_week', startDate: _startDate!, endDate: _endDate!, isAutoRefreshEnabled: true);
    _showComparison = true;
    _updateComparisonDates();
    if (!isLoadingSettings) _fetchStatistics();
  }

  @override
  void initSettingKey() => settingKey = SettingKeys.appUsageStatisticsFilterSettings;

  @override
  Future<void> loadSavedListOptionSettings() async {
    setState(() => isLoadingSettings = true);
    final saved = await filterSettingsManager.loadFilterSettings(settingKey: settingKey);
    if (saved != null) {
      final settings = AppUsageStatisticsSettings.fromJson(saved);
      setState(() {
        if (settings.dateFilterSetting != null) {
          _dateFilterSetting = settings.dateFilterSetting;
          if (_dateFilterSetting!.isQuickSelection) {
            final range = _dateFilterSetting!.calculateCurrentDateRange();
            _startDate = range.startDate;
            _endDate = range.endDate;
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
        await filterSettingsManager.saveFilterSettings(
          settingKey: settingKey,
          filterSettings:
              AppUsageStatisticsSettings(dateFilterSetting: _dateFilterSetting, showComparison: _showComparison)
                  .toJson(),
        );
        if (mounted) {
          setState(() => hasUnsavedChanges = false);
          showSavedMessageTemporarily();
        }
      },
    );
  }

  @override
  Future<void> checkForUnsavedChanges() async {
    final hasChanges = await filterSettingsManager.hasUnsavedChanges(
      settingKey: settingKey,
      currentSettings:
          AppUsageStatisticsSettings(dateFilterSetting: _dateFilterSetting, showComparison: _showComparison).toJson(),
    );
    if (mounted && hasUnsavedChanges != hasChanges) setState(() => hasUnsavedChanges = hasChanges);
  }

  @override
  void didUpdateWidget(AppUsageStatisticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appUsageId != widget.appUsageId) _fetchStatistics();
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
        if (_startDate == null || _endDate == null) {
          setState(() {
            _statistics = null;
            _isLoading = false;
          });
          return null;
        }
        return await _mediator
            .send<GetAppUsageStatisticsQuery, GetAppUsageStatisticsResponse>(GetAppUsageStatisticsQuery(
          appUsageId: widget.appUsageId,
          startDate: DateTimeHelper.toUtcDateTime(_startDate!),
          endDate: DateTimeHelper.toUtcDateTime(_endDate!),
          compareStartDate:
              _showComparison && _compareStartDate != null ? DateTimeHelper.toUtcDateTime(_compareStartDate!) : null,
          compareEndDate:
              _showComparison && _compareEndDate != null ? DateTimeHelper.toUtcDateTime(_compareEndDate!) : null,
        ));
      },
      onSuccess: (response) => setState(() {
        _statistics = response;
        _isLoading = false;
      }),
    );
  }

  void _updateComparisonDates() {
    if (_showComparison && _startDate != null && _endDate != null) {
      final length = _endDate!.difference(_startDate!);
      _compareEndDate = _startDate;
      _compareStartDate = _startDate!.subtract(length);
    } else {
      _compareStartDate = null;
      _compareEndDate = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.sizeMedium,
        children: [
          _buildHeaderRow(),
          if (_isLoading)
            _buildLoadingState()
          else if (_errorMessage != null)
            _buildErrorState()
          else if (_startDate == null || _endDate == null)
            _buildEmptyState()
          else if (_statistics != null) ...[
            _buildSummaryCards(),
            if (_showComparison &&
                _startDate != null &&
                _endDate != null &&
                _compareStartDate != null &&
                _compareEndDate != null)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall), child: _buildComparisonLegend()),
            _buildDailyChart(),
            _buildHourlyChart(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        DateRangeFilter(
          dateFilterSetting: _dateFilterSetting,
          selectedStartDate: _dateFilterSetting != null ? _startDate : null,
          selectedEndDate: _dateFilterSetting != null ? _endDate : null,
          onDateFilterChange: (start, end) {
            setState(() {
              _startDate = start;
              _endDate = end;
              _updateComparisonDates();
              handleFilterChange();
            });
            _fetchStatistics();
          },
          onDateFilterSettingChange: (setting) {
            setState(() {
              _dateFilterSetting = setting;
              if (setting?.isQuickSelection == true) {
                final range = setting!.calculateCurrentDateRange();
                _startDate = range.startDate;
                _endDate = range.endDate;
              } else if (setting != null) {
                _startDate = setting.startDate;
                _endDate = setting.endDate;
              } else {
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
        IconButton(
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
        ),
        const SizedBox(width: AppTheme.sizeSmall),
        SaveButton(
            hasUnsavedChanges: hasUnsavedChanges,
            showSavedMessage: showSavedMessage,
            onSave: saveFilterSettings,
            tooltip: _translationService.translate(SharedTranslationKeys.saveListOptions)),
      ],
    );
  }

  Widget _buildComparisonLegend() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          _buildLegendItem(Theme.of(context).colorScheme.primary, _formatDateRange(_startDate!, _endDate!)),
          _buildLegendItem(Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              _formatDateRange(_compareStartDate!, _compareEndDate!)),
        ];
        return constraints.maxWidth < 500
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [items[0], const SizedBox(height: AppTheme.sizeSmall), items[1]])
            : Wrap(spacing: AppTheme.sizeLarge, runSpacing: AppTheme.sizeSmall, children: items);
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
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppTheme.size2XSmall))),
        const SizedBox(width: AppTheme.sizeSmall),
        Flexible(child: Text(text, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildLoadingState() => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppTheme.size4XLarge),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppTheme.sizeLarge),
            Text(_translationService.translate(SharedTranslationKeys.loadingMessage),
                style: Theme.of(context).textTheme.bodyMedium)
          ])));

  Widget _buildErrorState() => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: AppTheme.iconSizeXLarge, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: AppTheme.sizeMedium),
            Text(_errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center)
          ])));

  Widget _buildEmptyState() => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppTheme.size4XLarge),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.date_range,
                size: AppTheme.iconSizeXLarge, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: AppTheme.sizeLarge),
            Text(_translationService.translate(SharedTranslationKeys.selectDateRangeMessage),
                style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.sizeSmall),
            Text(_translationService.translate(SharedTranslationKeys.selectDateRangeDescription),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
                textAlign: TextAlign.center)
          ])));

  Widget _buildSummaryCards() {
    final totalSeconds = _statistics!.dailyUsage.fold<int>(0, (sum, d) => sum + d.totalDuration);
    final dayCount = _statistics!.dailyUsage.where((d) => d.totalDuration > 0).length;
    final avgDaily = dayCount > 0 ? totalSeconds ~/ dayCount : 0;
    var peakHour = 0, peakDuration = 0;
    for (var h in _statistics!.hourlyUsage) {
      if (h.totalDuration > peakDuration) {
        peakDuration = h.totalDuration;
        peakHour = h.hour;
      }
    }
    return StatisticsSummaryCards(
      totalUsage: _formatDuration(totalSeconds),
      averageDaily: _formatDuration(avgDaily),
      peakHour: _formatHour(peakHour),
      totalUsageLabel: _translationService.translate(SharedTranslationKeys.totalUsageLabel),
      averageDailyLabel: _translationService.translate(SharedTranslationKeys.averageDailyLabel),
      peakHourLabel: _translationService.translate(SharedTranslationKeys.peakHourLabel),
    );
  }

  Widget _buildDailyChart() => DailyUsageChart(
        dailyData: _statistics!.dailyUsage
            .map((d) => ChartDailyData(
                dayOfWeek: d.dayOfWeek, totalDuration: d.totalDuration, compareDuration: d.compareDuration))
            .toList(),
        showComparison: _showComparison,
        translate: (key) => _translationService.translate(
            key == 'dailyUsage' ? SharedTranslationKeys.dailyUsage : SharedTranslationKeys.dailyUsageDescription),
      );

  Widget _buildHourlyChart() => HourlyUsageChart(
        hourlyData: _statistics!.hourlyUsage
            .map((h) =>
                ChartHourlyData(hour: h.hour, totalDuration: h.totalDuration, compareDuration: h.compareDuration))
            .toList(),
        showComparison: _showComparison,
        translate: (key) => _translationService.translate(
            key == 'hourlyUsage' ? SharedTranslationKeys.hourlyUsage : SharedTranslationKeys.hourlyUsageDescription),
      );

  String _formatDateRange(DateTime start, DateTime end) {
    final locale = Localizations.localeOf(context);
    return '${DateTimeHelper.formatDate(DateTimeHelper.toLocalDateTime(start), locale: locale)} - ${DateTimeHelper.formatDate(DateTimeHelper.toLocalDateTime(end), locale: locale)}';
  }

  String _formatHour(int hour) => DateTimeHelper.formatHour(hour, Localizations.localeOf(context));
  String _formatDuration(int seconds) =>
      DateTimeHelper.formatDuration(Duration(seconds: seconds), Localizations.localeOf(context));
}
