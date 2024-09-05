import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_card.dart';

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
  List<AppUsage> _appUsages = [];
  int _pageIndex = 0;
  bool _hasNext = false;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  Future<void> _loadInitialData() async {
    await _fetchAppUsages();
  }

  Future<void> _fetchAppUsages({int pageIndex = 0}) async {
    if (_isLoading) return; // Check to prevent multiple requests

    setState(() {
      _isLoading = true;
    });

    final query = GetListByTopAppUsagesQuery(pageIndex: pageIndex, pageSize: 100); //TODO: Add lazy loading

    try {
      final response =
          await widget.mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(query);

      setState(() {
        _appUsages = [..._appUsages, ...response.items];
        _pageIndex = pageIndex;
        _hasNext = response.hasNext;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Optionally show an error message or dialog
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoading && _hasNext) {
        await _fetchAppUsages(pageIndex: _pageIndex + 1);
      }
    });
  }

  Future<void> refreshData() async {
    setState(() {
      _appUsages.clear();
      _pageIndex = 0;
      _hasNext = true;
    });
    await _fetchAppUsages();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupScrollListener();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refreshData,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _appUsages.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isLoading && index == _appUsages.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final appUsage = _appUsages[index];
          return AppUsageCard(
            appUsage: appUsage,
            mediator: widget.mediator,
          );
        },
      ),
    );
  }
}
