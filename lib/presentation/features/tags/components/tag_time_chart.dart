import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whph/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';

class TagTimeChart extends StatefulWidget {
  final List<String>? filterByTags;
  final DateTime startDate;
  final DateTime endDate;
  final double? height;
  final double? width;
  final bool filterByIsArchived;

  const TagTimeChart({
    super.key,
    this.filterByTags,
    required this.startDate,
    required this.endDate,
    this.height = 300,
    this.width = 300,
    this.filterByIsArchived = false,
  });

  @override
  State<TagTimeChart> createState() => TagTimeChartState();
}

class TagTimeChartState extends State<TagTimeChart> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  GetTopTagsByTimeQueryResponse? _tagTimes;
  final bool _isLoading = false;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(TagTimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.filterByTags != widget.filterByTags ||
        oldWidget.filterByIsArchived != widget.filterByIsArchived) {
      refresh();
    }
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
    if (_tagTimes == null || _tagTimes!.items.isEmpty) {
      return SizedBox(
        height: 100,
        child: IconOverlay(
          icon: Icons.pie_chart,
          message: _translationService.translate(TagTranslationKeys.timeChartNoData),
          iconSize: 48,
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
      // No loading indicator since local DB is fast
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
    return _tagTimes!.items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isTouched = index == _touchedIndex;

      final percent = (item.duration / _tagTimes!.totalDuration * 100);

      return PieChartSectionData(
        color: item.tagColor != null
            ? Color(int.parse('FF${item.tagColor}', radix: 16))
            : Colors.primaries[index % Colors.primaries.length],
        value: item.duration.toDouble(),
        title: '${item.tagName}\n${percent.toStringAsFixed(1)}%',
        radius: isTouched ? 110 : 100,
        titleStyle: AppTheme.bodySmall.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}
