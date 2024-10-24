import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_times_data_query.dart';
import 'package:whph/main.dart';
import 'package:fl_chart/fl_chart.dart';

class TagTimeChart extends StatefulWidget {
  final Mediator mediator = container.resolve<Mediator>();

  TagTimeChart({super.key});

  @override
  State<TagTimeChart> createState() => _TagTimeChartState();
}

class _TagTimeChartState extends State<TagTimeChart> {
  GetListTagsQueryResponse? _tags;
  final Map<String, int> _tagTimes = {};

  @override
  void initState() {
    super.initState();
    _getTags();
  }

  Future<void> _getTags() async {
    var query = GetListTagsQuery(pageIndex: 0, pageSize: 100);
    _tags = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
    for (TagListItem tag in _tags!.items) {
      int time = await _getTagTimes(tag.id);
      if (mounted) {
        setState(() {
          _tagTimes[tag.name] = time;
        });
      }
    }
  }

  Future<int> _getTagTimes(String tagId) async {
    var query = GetTagTimesDataQuery(tagId: tagId);
    var result = await widget.mediator.send<GetTagTimesDataQuery, GetTagTimesDataQueryResponse>(query);
    return result.time;
  }

  @override
  Widget build(BuildContext context) {
    List<PieChartSectionData> sections = _tagTimes.entries.map((entry) {
      double timeInMinutes = (entry.value.toDouble() / 60).roundToDouble();
      return PieChartSectionData(
        value: timeInMinutes,
        title: '${entry.key}: $timeInMinutes',
        color: Colors.primaries[_tagTimes.keys.toList().indexOf(entry.key) % Colors.primaries.length],
        titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 100,
      );
    }).toList();

    return _tagTimes.isEmpty
        ? CircularProgressIndicator()
        : PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  // Handle touch events if needed
                },
              ),
            ),
          );
  }
}
