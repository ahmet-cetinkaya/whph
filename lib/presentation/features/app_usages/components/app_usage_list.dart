import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/presentation/features/shared/components/bar_chart.dart';

class AppUsageList extends StatefulWidget {
  final Mediator mediator;

  const AppUsageList({
    super.key,
    required this.mediator,
  });

  @override
  AppUsageListState createState() => AppUsageListState();
}

class AppUsageListState extends State<AppUsageList> {
  final List<AppUsage> _appUsages = [];
  int _pageIndex = 0;
  bool _hasNext = true;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  Future<void> _loadInitialData() async {
    await _fetchAppUsages();
  }

  Future<void> _fetchAppUsages() async {
    if (_isLoading || !_hasNext) return;

    setState(() {
      _isLoading = true;
    });

    final query = GetListByTopAppUsagesQuery(pageIndex: _pageIndex, pageSize: 10);

    try {
      final response =
          await widget.mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(query);
      setState(() {
        _pageIndex++;
        _appUsages.addAll(response.items);
        _hasNext = response.hasNext;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent && !_isLoading && _hasNext) {
        _fetchAppUsages();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double maxDuration = _appUsages.isNotEmpty
        ? _appUsages.map((e) => e.duration.toDouble() / 60).reduce((a, b) => a > b ? a : b)
        : 1.0; // Avoid division by zero, maximum duration in minutes

    return ListView.builder(
      controller: _scrollController,
      itemCount: _appUsages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _appUsages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final appUsage = _appUsages[index];

        return BarChartComponent(
          title: appUsage.title,
          value: appUsage.duration / 60,
          maxValue: maxDuration,
          unit: "min",
        );
      },
    );
  }
}
