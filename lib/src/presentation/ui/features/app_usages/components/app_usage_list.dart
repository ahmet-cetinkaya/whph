import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/presentation/ui/features/app_usages/components/app_usage_card.dart';
import 'package:whph/src/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/src/presentation/ui/shared/components/load_more_button.dart';
import 'package:whph/src/presentation/ui/shared/components/icon_overlay.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

/// Immutable snapshot of filter state to ensure consistent filter state throughout lifecycle
class FilterContext {
  final List<String>? filterByTags;
  final bool showNoTagsFilter;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;
  final List<String>? filterByDevices;

  const FilterContext({
    this.filterByTags,
    this.showNoTagsFilter = false,
    this.filterStartDate,
    this.filterEndDate,
    this.filterByDevices,
  });

  @override
  String toString() =>
      'FilterContext(tags: $filterByTags, showNoTags: $showNoTagsFilter, startDate: $filterStartDate, endDate: $filterEndDate, devices: $filterByDevices)';
}

class AppUsageList extends StatefulWidget {
  final int pageSize;
  final List<String>? filterByTags;
  final bool showNoTagsFilter;
  final Function(String id)? onOpenDetails;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;
  final List<String>? filterByDevices;

  const AppUsageList({
    super.key,
    this.pageSize = 10,
    this.filterByTags,
    this.showNoTagsFilter = false,
    this.onOpenDetails,
    this.filterStartDate,
    this.filterEndDate,
    this.filterByDevices,
  });

  @override
  AppUsageListState createState() => AppUsageListState();
}

class AppUsageListState extends State<AppUsageList> {
  final _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  final ScrollController _scrollController = ScrollController();
  GetListByTopAppUsagesQueryResponse? _appUsageList;
  late FilterContext _currentFilters;
  Timer? _refreshDebounce;
  double? _savedScrollPosition;

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
      );

  bool _filtersChanged({required FilterContext oldFilters, required FilterContext newFilters}) {
    final oldMap = {
      'filterByTags': oldFilters.filterByTags,
      'showNoTagsFilter': oldFilters.showNoTagsFilter,
      'startDate': oldFilters.filterStartDate,
      'endDate': oldFilters.filterEndDate,
      'filterByDevices': oldFilters.filterByDevices
    };

    final newMap = {
      'filterByTags': newFilters.filterByTags,
      'showNoTagsFilter': newFilters.showNoTagsFilter,
      'startDate': newFilters.filterStartDate,
      'endDate': newFilters.filterEndDate,
      'filterByDevices': newFilters.filterByDevices
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
      filterByDevices: _currentFilters.filterByDevices
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
    if (_appUsageList?.hasNext == false) return;

    _saveScrollPosition();
    await _getList(pageIndex: _appUsageList!.pageIndex + 1);
    _backLastScrollPosition();
  }

  @override
  Widget build(BuildContext context) {
    if (_appUsageList?.items.isEmpty ?? true) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: IconOverlay(
          icon: Icons.bar_chart,
          message: _translationService.translate(AppUsageTranslationKeys.noUsage),
        ),
      );
    }

    final maxDuration = _appUsageList?.items.map((e) => e.duration.toDouble() / 60).reduce((a, b) => a > b ? a : b);

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _appUsageList!.items.length +
          (_appUsageList!.hasNext && _appUsageList!.items.length < _appUsageList!.totalItemCount ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: AppTheme.size3XSmall),
      itemBuilder: (context, index) {
        if (index == _appUsageList!.items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppTheme.size2XSmall),
            child: Center(
              child: LoadMoreButton(
                onPressed: _onLoadMore,
              ),
            ),
          );
        }

        final appUsage = _appUsageList!.items[index];
        return AppUsageCard(
          appUsage: appUsage,
          maxDurationInListing: maxDuration!,
          onTap: () => widget.onOpenDetails?.call(appUsage.id),
        );
      },
    );
  }
}
