import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_card.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/utils/filter_change_analyzer.dart';

/// Immutable snapshot of filter state to ensure consistent filter state throughout lifecycle
class FilterContext {
  final List<String>? filterByTags;
  final bool showNoTagsFilter;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;

  const FilterContext({
    this.filterByTags,
    this.showNoTagsFilter = false,
    this.filterStartDate,
    this.filterEndDate,
  });

  @override
  String toString() =>
      'FilterContext(tags: $filterByTags, showNoTags: $showNoTagsFilter, startDate: $filterStartDate, endDate: $filterEndDate)';
}

class AppUsageList extends StatefulWidget {
  final int size;
  final List<String>? filterByTags;
  final bool showNoTagsFilter;
  final Function(String id)? onOpenDetails;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;

  const AppUsageList({
    super.key,
    this.size = 10,
    this.filterByTags,
    this.showNoTagsFilter = false,
    this.onOpenDetails,
    this.filterStartDate,
    this.filterEndDate,
  });

  @override
  AppUsageListState createState() => AppUsageListState();
}

class AppUsageListState extends State<AppUsageList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  late List<AppUsageListItem> _appUsages = [];
  late FilterContext _currentFilters;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _currentFilters = _captureCurrentFilters();
    _setupEventListeners();
    _loadAppUsages();
  }

  @override
  void dispose() {
    _removeEventListeners();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppUsageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newFilters = _captureCurrentFilters();
    if (_filtersChanged(oldFilters: _currentFilters, newFilters: newFilters)) {
      _currentFilters = newFilters;
      refresh();
    }
  }

  FilterContext _captureCurrentFilters() => FilterContext(
        filterByTags: widget.filterByTags,
        showNoTagsFilter: widget.showNoTagsFilter,
        filterStartDate: widget.filterStartDate,
        filterEndDate: widget.filterEndDate,
      );

  bool _filtersChanged({required FilterContext oldFilters, required FilterContext newFilters}) {
    final oldMap = {
      'filterByTags': oldFilters.filterByTags,
      'showNoTagsFilter': oldFilters.showNoTagsFilter,
      'startDate': oldFilters.filterStartDate,
      'endDate': oldFilters.filterEndDate,
    };

    final newMap = {
      'filterByTags': newFilters.filterByTags,
      'showNoTagsFilter': newFilters.showNoTagsFilter,
      'startDate': newFilters.filterStartDate,
      'endDate': newFilters.filterEndDate,
    };

    return FilterChangeAnalyzer.hasAnyFilterChanged(oldMap, newMap);
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 100), () async {
      setState(() {
        _appUsages = [];
      });

      await _loadAppUsages();
    });
  }

  Future<void> _loadAppUsages() async {
    final query = GetListByTopAppUsagesQuery(
      pageIndex: 0,
      pageSize: widget.size,
      filterByTags: _currentFilters.filterByTags,
      showNoTagsFilter: _currentFilters.showNoTagsFilter,
      startDate: _currentFilters.filterStartDate,
      endDate: _currentFilters.filterEndDate,
    );

    await AsyncErrorHandler.execute<List<AppUsageListItem>>(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getUsageError),
      operation: () async {
        final result = await _mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(query);
        return result.items;
      },
      onSuccess: (appUsages) {
        if (mounted) {
          setState(() {
            _appUsages = appUsages;
          });
        }
      },
    );
  }

  void _setupEventListeners() {
    _appUsagesService.onAppUsageUpdated.addListener(_handleAppUsageChange);
    _appUsagesService.onAppUsageCreated.addListener(_handleAppUsageChange);
    _appUsagesService.onAppUsageDeleted.addListener(_handleAppUsageChange);
  }

  void _removeEventListeners() {
    _appUsagesService.onAppUsageUpdated.removeListener(_handleAppUsageChange);
    _appUsagesService.onAppUsageCreated.removeListener(_handleAppUsageChange);
    _appUsagesService.onAppUsageDeleted.removeListener(_handleAppUsageChange);
  }

  void _handleAppUsageChange() {
    if (!mounted) return;
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_appUsages.isEmpty) {
      return IconOverlay(
        icon: Icons.bar_chart,
        message: _translationService.translate(AppUsageTranslationKeys.noUsage),
      );
    }

    final maxDuration = _appUsages.map((e) => e.duration.toDouble() / 60).reduce((a, b) => a > b ? a : b);

    return ListView(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ..._appUsages.map((appUsage) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AppUsageCard(
                appUsage: appUsage,
                maxDurationInListing: maxDuration,
                onTap: () => widget.onOpenDetails?.call(appUsage.id),
              ),
            )),
        if (_appUsages.length >= widget.size)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: LoadMoreButton(
                onPressed: _loadAppUsages,
              ),
            ),
          ),
      ],
    );
  }
}
