import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whph/src/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/src/core/application/features/tags/models/tag_time_data.dart';
import 'package:whph/src/core/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/components/icon_overlay.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/presentation/ui/features/tags/services/tags_service.dart';

class TagTimeChart extends StatefulWidget {
  final List<String>? filterByTags;
  final DateTime startDate;
  final DateTime endDate;
  final double? height;
  final double? width;
  final bool filterByIsArchived;
  final Set<TagTimeCategory> selectedCategories;

  const TagTimeChart({
    super.key,
    this.filterByTags,
    required this.startDate,
    required this.endDate,
    this.height = 300,
    this.width = 300,
    this.filterByIsArchived = false,
    this.selectedCategories = const {TagTimeCategory.all},
  });

  @override
  State<TagTimeChart> createState() => TagTimeChartState();
}

class TagTimeChartState extends State<TagTimeChart> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _tagsService = container.resolve<TagsService>();
  GetTopTagsByTimeQueryResponse? _tagTimes;
  final bool _isLoading = false;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    refresh();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  @override
  void didUpdateWidget(TagTimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.filterByTags != widget.filterByTags ||
        oldWidget.filterByIsArchived != widget.filterByIsArchived ||
        !CollectionUtils.areSetsEqual(oldWidget.selectedCategories, widget.selectedCategories)) {
      refresh();
    }
  }

  void _setupEventListeners() {
    _tagsService.onTagCreated.addListener(_onTagUpdated);
    _tagsService.onTagUpdated.addListener(_onTagUpdated);
    _tagsService.onTagDeleted.addListener(_onTagUpdated);
  }

  void _removeEventListeners() {
    _tagsService.onTagCreated.removeListener(_onTagUpdated);
    _tagsService.onTagUpdated.removeListener(_onTagUpdated);
    _tagsService.onTagDeleted.removeListener(_onTagUpdated);
  }

  void _onTagUpdated() {
    if (!mounted) return;

    // Check which event was triggered and get the relevant tag ID
    String? updatedTagId;
    if (_tagsService.onTagUpdated.value != null) {
      updatedTagId = _tagsService.onTagUpdated.value;
    } else if (_tagsService.onTagCreated.value != null) {
      updatedTagId = _tagsService.onTagCreated.value;
    } else if (_tagsService.onTagDeleted.value != null) {
      updatedTagId = _tagsService.onTagDeleted.value;
    }

    // Only refresh if the updated tag is relevant to this chart
    if (updatedTagId != null && _shouldRefreshForTag(updatedTagId)) {
      refresh();
    }
  }

  bool _shouldRefreshForTag(String updatedTagId) {
    // If we're filtering by specific tags, only refresh if the updated tag is in our filter
    if (widget.filterByTags != null && widget.filterByTags!.isNotEmpty) {
      return widget.filterByTags!.contains(updatedTagId);
    }

    // If we're showing all tags, check if the updated tag is in our current chart data
    if (_tagTimes?.items != null) {
      return _tagTimes!.items.any((item) => item.tagId == updatedTagId);
    }

    // If we don't have data yet or no specific filters, refresh to be safe
    return true;
  }

  Future<void> refresh() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final query = GetTopTagsByTimeQuery(
      startDate: widget.startDate,
      endDate: widget.endDate,
      limit: 10,
      filterByTags: widget.filterByTags,
      filterByIsArchived: widget.filterByIsArchived,
      categories: widget.selectedCategories.contains(TagTimeCategory.all) ? null : widget.selectedCategories.toList(),
    );

    final result = await _mediator.send<GetTopTagsByTimeQuery, GetTopTagsByTimeQueryResponse>(query);

    if (mounted) {
      setState(() {
        _tagTimes = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tagTimes?.items.isEmpty ?? true) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: IconOverlay(
          icon: Icons.pie_chart,
          message: _translationService.translate(TagTranslationKeys.timeChartNoData),
          iconSize: AppTheme.iconSizeXLarge,
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: _buildChart(),
    );
  }

  Widget _buildChart() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              _touchedIndex = pieTouchResponse?.touchedSection?.touchedSectionIndex;
            });
          },
        ),
        sections: _buildSections(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    // Calculate percentages for each item
    final itemsWithPercentage = _tagTimes!.items.map((item) {
      final percent = (item.duration / _tagTimes!.totalDuration * 100);
      return (item, percent);
    }).toList();

    // Separate items into regular tags (>=5%) and small tags (<5%)
    final regularTags = <(TagTimeData, double)>[];
    final smallTags = <(TagTimeData, double)>[];

    for (final itemWithPercent in itemsWithPercentage) {
      if (itemWithPercent.$2 < 5.0) {
        smallTags.add(itemWithPercent);
      } else {
        regularTags.add(itemWithPercent);
      }
    }

    // Create sections for regular tags
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < regularTags.length; i++) {
      final item = regularTags[i].$1;
      final percent = regularTags[i].$2;
      final isTouched = i == _touchedIndex;

      final sectionColor = item.tagColor != null
          ? Color(int.parse('FF${item.tagColor!}', radix: 16))
          : Colors.primaries[i % Colors.primaries.length];

      final titleColor = ColorHelper.getContrastingTextColor(sectionColor);

      sections.add(PieChartSectionData(
        color: sectionColor,
        value: item.duration.toDouble(),
        title: '${item.tagName}\n${percent.toStringAsFixed(1)}%',
        radius: isTouched ? 110 : 100,
        titleStyle: AppTheme.bodySmall.copyWith(
          fontWeight: FontWeight.bold,
          color: titleColor,
        ),
      ));
    }

    // Add "Other" section if there are small tags
    if (smallTags.isNotEmpty) {
      final otherIndex = sections.length;
      final isTouched = otherIndex == _touchedIndex;

      // Calculate total duration and percentage for "Other" category
      final otherDuration = smallTags.fold<double>(0, (sum, item) => sum + item.$1.duration);
      final otherPercent = smallTags.fold<double>(0, (sum, item) => sum + item.$2);

      const otherSectionColor = Colors.grey;
      final otherTitleColor = ColorHelper.getContrastingTextColor(otherSectionColor);

      sections.add(PieChartSectionData(
        color: otherSectionColor,
        value: otherDuration,
        title:
            '${_translationService.translate(TagTranslationKeys.otherCategory)}\n${otherPercent.toStringAsFixed(1)}%',
        radius: isTouched ? 110 : 100,
        titleStyle: AppTheme.bodySmall.copyWith(
          fontWeight: FontWeight.bold,
          color: otherTitleColor,
        ),
      ));
    }

    return sections;
  }
}
