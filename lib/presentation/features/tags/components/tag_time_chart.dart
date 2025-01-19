import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whph/application/features/tags/queries/get_top_tags_by_time_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

class TagTimeChart extends StatefulWidget {
  final Mediator _mediator = container.resolve<Mediator>();
  final List<String>? filterByTags;
  final DateTime startDate;
  final DateTime endDate;

  TagTimeChart({
    super.key,
    this.filterByTags,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<TagTimeChart> createState() => _TagTimeChartState();
}

class _TagTimeChartState extends State<TagTimeChart> {
  GetTopTagsByTimeQueryResponse? _tagTimes;
  bool _isLoading = true;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(TagTimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate ||
        oldWidget.filterByTags != widget.filterByTags) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final query = GetTopTagsByTimeQuery(
        startDate: widget.startDate,
        endDate: widget.endDate,
        limit: 10,
        filterByTags: widget.filterByTags, // Pass filter to query
      );

      final result = await widget._mediator.send<GetTopTagsByTimeQuery, GetTopTagsByTimeQueryResponse>(query);

      if (mounted) {
        setState(() {
          _tagTimes = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: "Error loading tag times");
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildChart();
  }

  Widget _buildChart() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tagTimes == null || _tagTimes!.items.isEmpty) {
      return const Center(child: Text('No data available'));
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
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}
