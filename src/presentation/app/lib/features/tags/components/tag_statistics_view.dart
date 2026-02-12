import 'package:flutter/material.dart';
import 'package:application/features/tags/models/tag_time_category.dart';
import 'package:whph/features/tags/components/tag_time_bar_chart.dart';
import 'package:whph/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/models/date_filter_setting.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/shared/components/section_header.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';

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
  final _barChartKey = GlobalKey<TagTimeBarChartState>();

  DateFilterSetting? _dateFilterSetting;
  DateTime? _startDate;
  DateTime? _endDate;
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: _translationService.translate(SharedTranslationKeys.statisticsLabel),
          expandTrailing: true,
          trailing: TagTimeChartOptions(
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
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
                      ),
                      child: Icon(
                        Icons.bar_chart,
                        size: AppTheme.iconSizeMedium,
                        color: primaryColor,
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
