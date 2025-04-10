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

class AppUsageList extends StatefulWidget {
  final Mediator mediator;

  final int size;
  final List<String>? filterByTags;
  final Function(String int)? onOpenDetails;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;

  const AppUsageList({
    super.key,
    required this.mediator,
    this.size = 10,
    this.filterByTags,
    this.onOpenDetails,
    this.filterStartDate,
    this.filterEndDate,
  });

  @override
  AppUsageListState createState() => AppUsageListState();
}

class AppUsageListState extends State<AppUsageList> {
  List<AppUsageListItem> _appUsages = [];
  bool _isLoading = false;
  bool _isRefreshing = false;

  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _loadAppUsages();
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    await _loadAppUsages();

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _loadAppUsages() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final appUsages = await _fetchAppUsages();

      setState(() {
        _appUsages = appUsages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error appropriately
    }
  }

  Future<List<AppUsageListItem>> _fetchAppUsages() async {
    final query = GetListByTopAppUsagesQuery(
      pageIndex: 0,
      pageSize: widget.size,
      filterByTags: widget.filterByTags,
      startDate: widget.filterStartDate,
      endDate: widget.filterEndDate,
    );

    try {
      final result = await widget.mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(query);
      return result.items;
    } on BusinessException catch (e) {
      if (context.mounted) {
        // ignore: use_build_context_synchronously
        ErrorHelper.showError(context, e);
      }
      return [];
    } catch (e, stackTrace) {
      if (context.mounted) {
        ErrorHelper.showUnexpectedError(
          // ignore: use_build_context_synchronously
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
