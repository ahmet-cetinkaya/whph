import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whph/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';

class TagTimeChart extends StatefulWidget {
  final _translationService = container.resolve<ITranslationService>();
  final Mediator _mediator = container.resolve<Mediator>();
  final List<String>? filterByTags;
  final DateTime startDate;
  final DateTime endDate;
  final double? height;
  final double? width;

  TagTimeChart({
    super.key,
    this.filterByTags,
    required this.startDate,
    required this.endDate,
    this.height = 300,
    this.width = 300,
  });

  @override
  State<TagTimeChart> createState() => TagTimeChartState();
}

class TagTimeChartState extends State<TagTimeChart> {
  GetTopTagsByTimeQueryResponse? _tagTimes;
  bool _isLoading = false;
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
        oldWidget.filterByTags != widget.filterByTags) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final query = GetTopTagsByTimeQuery(
        startDate: widget.startDate,
        endDate: widget.endDate,
        limit: 10,
        filterByTags: widget.filterByTags,
      );

      final result = await widget._mediator.send<GetTopTagsByTimeQuery, GetTopTagsByTimeQueryResponse>(query);

      if (mounted) {
        setState(() {
          _tagTimes = result;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tagTimes == null || _tagTimes!.items.isEmpty) {
      return Center(
        child: Text(widget._translationService.translate(TagTranslationKeys.timeChartNoData)),
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
      return const Center(child: CircularProgressIndicator());
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
