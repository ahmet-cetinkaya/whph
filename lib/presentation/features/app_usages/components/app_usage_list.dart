import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_card.dart';
import 'package:whph/presentation/shared/components/load_more_button.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

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
  final Mediator mediator;
  final int size;
  final List<String>? filterByTags;
  final bool showNoTagsFilter;
  final Function(String id)? onOpenDetails;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;

  const AppUsageList({
    super.key,
    required this.mediator,
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
  late List<AppUsageListItem> _appUsages = [];
  bool _isLoading = false;
  late FilterContext _currentFilters;

  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _currentFilters = _captureCurrentFilters();
    _loadAppUsages();
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

  /// Creates an immutable snapshot of current filter state
  FilterContext _captureCurrentFilters() => FilterContext(
        filterByTags: widget.filterByTags,
        showNoTagsFilter: widget.showNoTagsFilter,
        filterStartDate: widget.filterStartDate,
        filterEndDate: widget.filterEndDate,
      );

  /// Determines if filters have functionally changed
  bool _filtersChanged({required FilterContext oldFilters, required FilterContext newFilters}) {
    return oldFilters.filterByTags != newFilters.filterByTags ||
        oldFilters.showNoTagsFilter != newFilters.showNoTagsFilter ||
        oldFilters.filterStartDate != newFilters.filterStartDate ||
        oldFilters.filterEndDate != newFilters.filterEndDate;
  }

  Future<void> refresh() async {
    setState(() {
      _isLoading = true;
      _appUsages = []; // Clear current data while refreshing
    });

    await _loadAppUsages();
  }

  Future<void> _loadAppUsages() async {
    if (!mounted) return;

    try {
      final appUsages = await _fetchAppUsages();

      if (mounted) {
        setState(() {
          _appUsages = appUsages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<AppUsageListItem>> _fetchAppUsages() async {
    final query = GetListByTopAppUsagesQuery(
      pageIndex: 0,
      pageSize: widget.size,
      filterByTags: _currentFilters.filterByTags,
      showNoTagsFilter: _currentFilters.showNoTagsFilter,
      startDate: _currentFilters.filterStartDate,
      endDate: _currentFilters.filterEndDate,
    );

    try {
      final result = await widget.mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(query);
      return result.items;
    } on BusinessException catch (e) {
      if (mounted) {
        ErrorHelper.showError(context, e);
      }
      return [];
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.getUsageError),
        );
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _appUsages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_appUsages.isEmpty) {
      return Center(
        child: Text(_translationService.translate(AppUsageTranslationKeys.noUsage)),
      );
    }

    double maxDuration = _appUsages.map((e) => e.duration.toDouble() / 60).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final appUsage in _appUsages)
          AppUsageCard(
            mediator: widget.mediator,
            appUsage: appUsage,
            maxDurationInListing: maxDuration,
            onTap: () => widget.onOpenDetails?.call(appUsage.id),
          ),
        if (_appUsages.length >= widget.size)
          Center(
            child: LoadMoreButton(
              onPressed: () => _loadAppUsages(),
            ),
          ),
      ],
    );
  }
}
