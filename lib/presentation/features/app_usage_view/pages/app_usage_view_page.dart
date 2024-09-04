import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usage/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/domain/features/app_usage/app_usage.dart';
import 'package:whph/main.dart';

class AppUsageViewPage extends StatefulWidget {
  static const String route = '/app-usages';

  final Mediator mediator = container.resolve<Mediator>();

  AppUsageViewPage({super.key});

  @override
  State<AppUsageViewPage> createState() => _AppUsageViewPageState();
}

class _AppUsageViewPageState extends State<AppUsageViewPage> {
  List<AppUsage> _appUsages = [];
  int _pageIndex = 0;
  bool _hasNext = false;
  final ScrollController _scrollController = ScrollController();
  int _loadingCount = 0;

  @override
  void initState() {
    _getList();
    _listenLazyLoad();
    super.initState();
  }

  Future<void> _getList({int pageIndex = 0}) async {
    setState(() {
      _loadingCount = _loadingCount + 1;
    });

    const size = 50;
    var query = GetListByTopAppUsagesQuery(
      pageIndex: pageIndex,
      pageSize: size,
    );
    var queryResponse =
        await widget.mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(query);

    setState(() {
      _appUsages = [..._appUsages, ...queryResponse.items];
      _pageIndex = pageIndex;
      _hasNext = queryResponse.hasNext;
      _loadingCount = _loadingCount - 1;
    });
  }

  void _listenLazyLoad() {
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasNext) {
        await _getList(pageIndex: _pageIndex + 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Usages'),
        actions: [
          if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                _appUsages.clear();
                await _getList(pageIndex: _pageIndex);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _getList();
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _appUsages.length + (_loadingCount > 0 ? 1 : 0),
          itemBuilder: (context, index) {
            if (_loadingCount > 0 && index == _appUsages.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return ListTile(
              title: Text(_appUsages[index].title),
              subtitle: Text(
                  "${(_appUsages[index].duration / 60) < 1 ? "<1" : (_appUsages[index].duration / Duration.secondsPerMinute).roundToDouble().toString()} minutes"),
            );
          },
        ),
      ),
    );
  }
}
