import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_list_item.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/features/app_usages/components/app_usage_card.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/enums/pagination_mode.dart';
import 'package:whph/presentation/ui/shared/mixins/pagination_mixin.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:whph/presentation/ui/shared/components/list_group_header.dart';
import 'package:whph/presentation/ui/shared/mixins/list_group_collapse_mixin.dart';

// Sealed class for lazy-loading list items
sealed class _ListItem {}

class _HeaderItem extends _ListItem {
  final String id;
  final String displayTitle;
  final int index;
  final bool isExpanded;
  _HeaderItem({
    required this.id,
    required this.displayTitle,
    required this.index,
    required this.isExpanded,
  });
}

class _DataItem extends _ListItem {
  final AppUsageListItem appUsage;
  _DataItem({required this.appUsage});
}

class _SeparatorItem extends _ListItem {
  final Key key;
  final double height;
  _SeparatorItem({required this.key, required this.height});
}

/// Immutable snapshot of filter state to ensure consistent filter state throughout lifecycle
class FilterContext {
  final List<String>? filterByTags;
  final bool showNoTagsFilter;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;
  final List<String>? filterByDevices;
  final bool showComparison;
  final SortConfig<AppUsageSortFields>? sortConfig;
  final bool useTagColorForBars;

  const FilterContext({
    this.filterByTags,
    this.showNoTagsFilter = false,
    this.filterStartDate,
    this.filterEndDate,
    this.filterByDevices,
    this.showComparison = false,
    this.sortConfig,
    this.useTagColorForBars = false,
  });

  @override
  String toString() =>
      'FilterContext(tags: $filterByTags, showNoTags: $showNoTagsFilter, startDate: $filterStartDate, endDate: $filterEndDate, devices: $filterByDevices, showComparison: $showComparison, sortConfig: $sortConfig, useTagColorForBars: $useTagColorForBars)';
}

class AppUsageList extends StatefulWidget implements IPaginatedWidget {
  final int pageSize;
  final List<String>? filterByTags;
  final bool showNoTagsFilter;
  final Function(String id)? onOpenDetails;
  final void Function(int count)? onList;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;
  final List<String>? filterByDevices;
  final bool showComparison;
  final SortConfig<AppUsageSortFields>? sortConfig;
  final bool useTagColorForBars;

  @override
  final PaginationMode paginationMode;

  const AppUsageList({
    super.key,
    this.pageSize = 10,
    this.filterByTags,
    this.showNoTagsFilter = false,
    this.onOpenDetails,
    this.onList,
    this.filterStartDate,
    this.filterEndDate,
    this.filterByDevices,
    this.showComparison = false,
    this.sortConfig,
    this.useTagColorForBars = false,
    this.paginationMode = PaginationMode.loadMore,
  });

  @override
  AppUsageListState createState() => AppUsageListState();
}

class AppUsageListState extends State<AppUsageList>
    with PaginationMixin<AppUsageList>, ListGroupCollapseMixin<AppUsageList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  final ScrollController _scrollController = ScrollController();
  GetListByTopAppUsagesQueryResponse? _appUsageList;
  late FilterContext _currentFilters;
  Timer? _refreshDebounce;
  double? _savedScrollPosition;
  bool _isInitialLoading = true;
  List<_ListItem> _flattenedItems = [];
  double _maxDuration = 0;
  double _maxCompareDuration = 0;

  @override
  ScrollController get scrollController => _scrollController;

  @override
  bool get hasNextPage => _appUsageList?.hasNext ?? false;

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
    _scrollController.dispose();
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
        filterByDevices: widget.filterByDevices,
        showComparison: widget.showComparison,
        sortConfig: widget.sortConfig,
        useTagColorForBars: widget.useTagColorForBars,
      );

  bool _filtersChanged({required FilterContext oldFilters, required FilterContext newFilters}) {
    final oldMap = {
      'filterByTags': oldFilters.filterByTags,
      'showNoTagsFilter': oldFilters.showNoTagsFilter,
      'startDate': oldFilters.filterStartDate,
      'endDate': oldFilters.filterEndDate,
      'filterByDevices': oldFilters.filterByDevices,
      'showComparison': oldFilters.showComparison,
      'sortConfig': oldFilters.sortConfig,
      'useTagColorForBars': oldFilters.useTagColorForBars,
    };

    final newMap = {
      'filterByTags': newFilters.filterByTags,
      'showNoTagsFilter': newFilters.showNoTagsFilter,
      'startDate': newFilters.filterStartDate,
      'endDate': newFilters.filterEndDate,
      'filterByDevices': newFilters.filterByDevices,
      'showComparison': newFilters.showComparison,
      'sortConfig': newFilters.sortConfig,
      'useTagColorForBars': newFilters.useTagColorForBars,
    };

    return CollectionUtils.hasAnyMapValueChanged(oldMap, newMap);
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients && _scrollController.position.hasViewportDimension) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
  }

  void _backLastScrollPosition() {
    if (_savedScrollPosition == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.hasViewportDimension &&
          _savedScrollPosition! <= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_savedScrollPosition!);
      }
    });
  }

  Future<void> refresh() async {
    if (!mounted) return;

    _saveScrollPosition();
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 100), () async {
      await _getList(isRefresh: true);
      _backLastScrollPosition();
    });
  }

  Future<void> _getList({int pageIndex = 0, bool isRefresh = false}) async {
    final query = GetListByTopAppUsagesQuery(
      pageIndex: pageIndex,
      pageSize: isRefresh && (_appUsageList?.items.length ?? 0) > widget.pageSize
          ? _appUsageList?.items.length ?? widget.pageSize
          : widget.pageSize,
      filterByTags: _currentFilters.filterByTags,
      showNoTagsFilter: _currentFilters.showNoTagsFilter,
      startDate: _currentFilters.filterStartDate != null
          ? DateTimeHelper.toUtcDateTime(_currentFilters.filterStartDate!)
          : null,
      endDate:
          _currentFilters.filterEndDate != null ? DateTimeHelper.toUtcDateTime(_currentFilters.filterEndDate!) : null,
      compareStartDate: _currentFilters.showComparison && _currentFilters.filterStartDate != null
          ? DateTimeHelper.toUtcDateTime(_currentFilters.filterStartDate!
              .subtract(_currentFilters.filterEndDate!.difference(_currentFilters.filterStartDate!)))
          : null,
      compareEndDate: _currentFilters.showComparison && _currentFilters.filterEndDate != null
          ? DateTimeHelper.toUtcDateTime(_currentFilters.filterStartDate!)
          : null,
      filterByDevices: _currentFilters.filterByDevices,
      sortBy: _currentFilters.sortConfig?.orderOptions,
      groupBy: _currentFilters.sortConfig?.groupOption,
      enableGrouping: _currentFilters.sortConfig?.enableGrouping ?? false,
      sortByCustomOrder: _currentFilters.sortConfig?.useCustomOrder ?? false,
      customTagSortOrder: _currentFilters.sortConfig?.customTagSortOrder,
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
              _appUsageList = data;
            } else {
              _appUsageList = GetListByTopAppUsagesQueryResponse(
                items: [...?_appUsageList?.items, ...data.items],
                pageIndex: data.pageIndex,
                pageSize: data.pageSize,
                totalItemCount: data.totalItemCount,
              );
            }
            // Mark initial loading as complete
            _isInitialLoading = false;
            // Build flattened items for lazy loading
            _buildFlattenedItems();
          });

          // Notify about list count
          widget.onList?.call(_appUsageList?.items.length ?? 0);

          // For infinity scroll: check if viewport needs more content
          if (widget.paginationMode == PaginationMode.infinityScroll && (_appUsageList?.hasNext ?? false)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              checkAndFillViewport();
            });
          }
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
  void onGroupCollapseChanged() {
    _buildFlattenedItems();
  }

  @override
  Future<void> onLoadMore() async {
    if (_appUsageList?.hasNext == false) return;

    _saveScrollPosition();
    await _getList(pageIndex: _appUsageList!.pageIndex + 1);
    _backLastScrollPosition();
  }

  void _buildFlattenedItems() {
    if (_appUsageList == null || _appUsageList!.items.isEmpty) {
      _flattenedItems = [];
      _maxDuration = 0;
      _maxCompareDuration = 0;
      return;
    }

    final List<_ListItem> items = [];
    String? currentGroup;

    final sortConfig = widget.sortConfig;
    final showHeaders = ((sortConfig?.orderOptions.isNotEmpty ?? false) || (sortConfig?.groupOption != null)) &&
        (sortConfig?.enableGrouping ?? false);

    // Calculate max durations
    double maxDuration = 0;
    double maxCompareDuration = 0;

    for (final item in _appUsageList!.items) {
      final duration = item.duration.toDouble() / 60;
      if (duration > maxDuration) maxDuration = duration;

      final compareDuration = (item.compareDuration ?? 0).toDouble() / 60;
      if (compareDuration > maxCompareDuration) maxCompareDuration = compareDuration;
    }

    _maxDuration = maxDuration;
    _maxCompareDuration = maxCompareDuration;

    // Build flattened model list
    for (var i = 0; i < _appUsageList!.items.length; i++) {
      final appUsage = _appUsageList!.items[i];

      if (showHeaders && appUsage.groupName != null && appUsage.groupName != currentGroup) {
        currentGroup = appUsage.groupName;
        if (i > 0) {
          items.add(_SeparatorItem(
            key: ValueKey('separator_header_${appUsage.id}'),
            height: AppTheme.sizeSmall,
          ));
        }
        items.add(_HeaderItem(
          id: appUsage.groupName!,
          displayTitle: appUsage.isGroupNameTranslatable
              ? _translationService.translate(appUsage.groupName!)
              : appUsage.groupName!,
          index: i,
          isExpanded: !collapsedGroups.contains(appUsage.groupName),
        ));
      } else if (i > 0 && !(showHeaders && currentGroup != null && collapsedGroups.contains(currentGroup))) {
        items.add(_SeparatorItem(
          key: ValueKey('separator_item_${appUsage.id}'),
          height: AppTheme.sizeSmall,
        ));
      }

      if (showHeaders && currentGroup != null && collapsedGroups.contains(currentGroup)) {
        continue;
      }

      items.add(_DataItem(appUsage: appUsage));
    }

    _flattenedItems = items;
  }

  @override
  Widget build(BuildContext context) {
    // Show nothing while initial data is being fetched to prevent flickering
    if (_isInitialLoading) {
      return const SizedBox.shrink();
    }

    // Show empty message only after initial loading is complete and list is actually empty
    if (_appUsageList?.items.isEmpty ?? true) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: IconOverlay(
          icon: Icons.bar_chart,
          message: _translationService.translate(AppUsageTranslationKeys.noUsage),
        ),
      );
    }

    final showLoadMore = _appUsageList!.hasNext && widget.paginationMode == PaginationMode.loadMore;
    final showInfinityLoading =
        _appUsageList!.hasNext && widget.paginationMode == PaginationMode.infinityScroll && isLoadingMore;
    final extraItemCount = (showLoadMore || showInfinityLoading) ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
      itemCount: _flattenedItems.length + extraItemCount,
      itemBuilder: (context, index) {
        if (index < _flattenedItems.length) {
          final item = _flattenedItems[index];
          return switch (item) {
            _HeaderItem() => ListGroupHeader(
                key: ValueKey('header_${item.id}_${item.index}'),
                title: item.displayTitle,
                isExpanded: item.isExpanded,
                onTap: () => toggleGroupCollapse(item.id),
              ),
            _DataItem() => Padding(
                key: ValueKey('app_usage_${item.appUsage.id}'),
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: AppUsageCard(
                  appUsage: item.appUsage,
                  maxDurationInListing: _maxDuration,
                  maxCompareDurationInListing: _maxCompareDuration,
                  onTap: () => widget.onOpenDetails?.call(item.appUsage.id),
                  useTagColorForBars: widget.useTagColorForBars,
                ),
              ),
            _SeparatorItem() => SizedBox(
                key: item.key,
                height: item.height,
              ),
          };
        } else if (showLoadMore) {
          return Padding(
            key: const ValueKey('load_more_button'),
            padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
            child: Center(
              child: LoadMoreButton(
                onPressed: onLoadMore,
              ),
            ),
          );
        } else if (showInfinityLoading) {
          return const Padding(
            key: ValueKey('infinity_loading_indicator'),
            padding: EdgeInsets.symmetric(vertical: AppTheme.sizeMedium),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
