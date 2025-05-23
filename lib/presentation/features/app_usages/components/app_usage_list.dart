import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_card.dart';
import 'package:whph/presentation/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/components/icon_overlay.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/core/acore/utils/collection_utils.dart';

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
  GetListByTopAppUsagesQueryResponse? _appUsagesList;
  late FilterContext _currentFilters;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _currentFilters = _captureCurrentFilters();
    _setupEventListeners();
    _getList(isRefresh: true);
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

    return CollectionUtils.hasAnyMapValueChanged(oldMap, newMap);
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 100), () async {
      await _getList(isRefresh: true);
    });
  }

  Future<void> _getList({int pageIndex = 0, bool isRefresh = false}) async {
    final query = GetListByTopAppUsagesQuery(
      pageIndex: pageIndex,
      pageSize: widget.size,
      filterByTags: _currentFilters.filterByTags,
      showNoTagsFilter: _currentFilters.showNoTagsFilter,
      startDate: _currentFilters.filterStartDate != null
          ? DateTimeHelper.toUtcDateTime(_currentFilters.filterStartDate!)
          : null,
      endDate:
          _currentFilters.filterEndDate != null ? DateTimeHelper.toUtcDateTime(_currentFilters.filterEndDate!) : null,
    );

    await AsyncErrorHandler.execute<GetListByTopAppUsagesQueryResponse>(
      context: context,
      errorMessage: _translationService.translate(AppUsageTranslationKeys.getUsageError),
      operation: () async {
        final result = await _mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(query);
        return result;
      },
      onSuccess: (data) {
        if (mounted) {
          setState(() {
            if (isRefresh) {
              _appUsagesList = data;
            } else {
              _appUsagesList = GetListByTopAppUsagesQueryResponse(
                items: [...?_appUsagesList?.items, ...data.items],
                pageIndex: data.pageIndex,
                pageSize: data.pageSize,
                totalItemCount: data.totalItemCount,
                totalPageCount: data.totalPageCount,
              );
            }
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

  Future<void> _onLoadMore() async {
    if (_appUsagesList?.hasNext == false) return;

    await _getList(pageIndex: _appUsagesList!.pageIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_appUsagesList?.items.isEmpty ?? true) {
      return IconOverlay(
        icon: Icons.bar_chart,
        message: _translationService.translate(AppUsageTranslationKeys.noUsage),
      );
    }

    final maxDuration = _appUsagesList?.items.map((e) => e.duration.toDouble() / 60).reduce((a, b) => a > b ? a : b);

    return ListView(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ...?_appUsagesList?.items.map((appUsage) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AppUsageCard(
                appUsage: appUsage,
                maxDurationInListing: maxDuration!,
                onTap: () => widget.onOpenDetails?.call(appUsage.id),
              ),
            )),

        // Load more button
        if (_appUsagesList?.hasNext == true)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeSmall),
            child: Center(
              child: LoadMoreButton(
                onPressed: _onLoadMore,
              ),
            ),
          ),
      ],
    );
  }
}
