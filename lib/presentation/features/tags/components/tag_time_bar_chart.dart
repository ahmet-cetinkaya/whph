import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/application/features/tags/queries/get_elements_by_time_query.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/features/tasks/pages/task_details_page.dart';
import 'package:whph/presentation/shared/components/bar_chart.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class TagTimeBarChart extends StatefulWidget {
  final List<String>? filterByTags;
  final DateTime startDate;
  final DateTime endDate;
  final double? height;
  final bool filterByIsArchived;
  final Set<TagTimeCategory> selectedCategories;

  const TagTimeBarChart({
    super.key,
    this.filterByTags,
    required this.startDate,
    required this.endDate,
    this.height,
    this.filterByIsArchived = false,
    this.selectedCategories = const {TagTimeCategory.all},
  });

  @override
  State<TagTimeBarChart> createState() => TagTimeBarChartState();
}

class TagTimeBarChartState extends State<TagTimeBarChart> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  GetElementsByTimeQueryResponse? _elementTimeData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(TagTimeBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterByTags != widget.filterByTags ||
        oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.filterByIsArchived != widget.filterByIsArchived ||
        oldWidget.selectedCategories != widget.selectedCategories) {
      _loadData();
    }
  }

  Future<void> refresh() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final query = GetElementsByTimeQuery(
        startDate: DateTimeHelper.toUtcDateTime(widget.startDate),
        endDate: DateTimeHelper.toUtcDateTime(widget.endDate),
        filterByTags: widget.filterByTags,
        filterByIsArchived: widget.filterByIsArchived,
        categories: widget.selectedCategories.contains(TagTimeCategory.all) ? null : widget.selectedCategories.toList(),
      );

      final result = await _mediator.send<GetElementsByTimeQuery, GetElementsByTimeQueryResponse>(query);

      if (mounted) {
        setState(() {
          _elementTimeData = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading element time data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_elementTimeData == null || _elementTimeData!.items.isEmpty) {
      return IconOverlay(
        icon: Icons.bar_chart,
        message: _translationService.translate(TagTranslationKeys.timeChartNoData),
        iconSize: 48,
      );
    }

    return ListView.builder(
      itemCount: _elementTimeData!.items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = _elementTimeData!.items[index];
        return _buildBarItem(item);
      },
    );
  }

  Widget _buildBarItem(ElementTimeData item) {
    // Find the maximum duration for scaling
    final maxDuration = _elementTimeData!.items.isNotEmpty ? _elementTimeData!.items.first.duration.toDouble() : 1.0;

    // Get color based on category or tag color
    Color barColor;
    if (item.color != null) {
      barColor = Color(int.parse('FF${item.color}', radix: 16));
    } else {
      barColor = _getCategoryColor(item.category);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sizeXSmall),
      child: BarChart(
        title: item.name,
        value: item.duration.toDouble(),
        maxValue: maxDuration,
        barColor: barColor,
        formatValue: (value) => SharedUiConstants.formatDurationHuman((value / 60).toInt(), _translationService),
        onTap: () => _openElementDetails(item),
        additionalWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TagUiConstants.getTagTimeCategoryIcon(item.category),
              size: AppTheme.iconSizeSmall,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openElementDetails(ElementTimeData item) async {
    if (!mounted) return;

    switch (item.category) {
      case TagTimeCategory.tasks:
        await ResponsiveDialogHelper.showResponsiveDialog(
          context: context,
          title: _translationService.translate(TagTranslationKeys.categoryTasks),
          child: TaskDetailsPage(
            taskId: item.id,
            hideSidebar: true,
          ),
        );
        break;
      case TagTimeCategory.habits:
        await ResponsiveDialogHelper.showResponsiveDialog(
          context: context,
          title: _translationService.translate(TagTranslationKeys.categoryHabits),
          child: HabitDetailsPage(
            habitId: item.id,
          ),
        );
        break;
      case TagTimeCategory.appUsage:
        await ResponsiveDialogHelper.showResponsiveDialog(
          context: context,
          title: _translationService.translate(TagTranslationKeys.categoryAppUsage),
          child: AppUsageDetailsPage(
            appUsageId: item.id,
          ),
        );
        break;
      default:
        break;
    }

    // Refresh data after the detail page is closed
    if (mounted) {
      refresh();
    }
  }

  Color _getCategoryColor(TagTimeCategory category) {
    switch (category) {
      case TagTimeCategory.tasks:
        return Colors.blue;
      case TagTimeCategory.appUsage:
        return Colors.purple;
      case TagTimeCategory.habits:
        return Colors.green;
      default:
        return AppTheme.primaryColor;
    }
  }
}
