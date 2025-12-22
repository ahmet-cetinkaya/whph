import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_time_bar_chart.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';

import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

class TagStatisticsView extends StatefulWidget {
  final String tagId;

  const TagStatisticsView({
    super.key,
    required this.tagId,
  });

  @override
  State<TagStatisticsView> createState() => _TagStatisticsViewState();
}

class _TagStatisticsViewState extends State<TagStatisticsView> {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  final _barChartKey = GlobalKey<TagTimeBarChartState>();

  DateFilterSetting? _dateFilterSetting;
  DateTime? _startDate;
  DateTime? _endDate;
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.sizeMedium),
          child: Row(
            children: [
              Text(
                _translationService.translate(SharedTranslationKeys.statisticsLabel),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: AppTheme.sizeSmall),
              Expanded(
                child: TagTimeChartOptions(
                  dateFilterSetting: _dateFilterSetting,
                  selectedStartDate: _dateFilterSetting != null ? _startDate : null,
                  selectedEndDate: _dateFilterSetting != null ? _endDate : null,
                  selectedCategories: _selectedCategories,
                  onDateFilterChange: (start, end) {
                    if (start != null && end != null) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                        _barChartKey.currentState?.refresh();
                      });
                    }
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
                      _barChartKey.currentState?.refresh();
                    });
                  },
                  onCategoriesChanged: (categories) {
                    setState(() {
                      _selectedCategories = categories;
                      _barChartKey.currentState?.refresh();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Card(
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
                        Icons.bar_chart,
                        size: AppTheme.iconSizeMedium,
                        color: _themeService.primaryColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.sizeMedium),
                    Text(
                      _translationService.translate(TagTranslationKeys.timeRecords),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.sizeSmall),
                TagTimeBarChart(
                  key: _barChartKey,
                  filterByTags: [widget.tagId],
                  startDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                  endDate: _endDate ?? DateTime.now(),
                  selectedCategories: _selectedCategories,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
