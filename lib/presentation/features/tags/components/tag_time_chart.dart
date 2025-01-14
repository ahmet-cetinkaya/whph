import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/application/features/tags/queries/get_tag_times_data_query.dart';
import 'package:whph/main.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';

class TagTimeChart extends StatefulWidget {
  final Mediator mediator = container.resolve<Mediator>();

  final List<String>? filterByTags;

  TagTimeChart({super.key, this.filterByTags});

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
    var query = GetListTagsQuery(pageIndex: 0, pageSize: 100, filterByTags: widget.filterByTags);
    _tags = await widget.mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);
    for (TagListItem tag in _tags!.items) {
      int time = await _getTagTimes(tag.id);
      if (time > 0) {
        if (!mounted) return;
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
    if (_tags == null) {
      return const SizedBox.shrink();
    }

    int totalTime = _tagTimes.values.fold(0, (sum, time) => sum + time);

    if (_tagTimes.isEmpty) {
      return const Center(
        child: Text('No time data available'),
      );
    }

    List<PieChartSectionData> sections = _tagTimes.entries.map((entry) {
      double percentage = (entry.value / totalTime) * 100;
      String percentageString = '${percentage.round()}%';
      return PieChartSectionData(
        value: percentage,
        title: '${entry.key}: $percentageString',
        color: Colors.primaries[_tagTimes.keys.toList().indexOf(entry.key) % Colors.primaries.length],
        titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 100,
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
