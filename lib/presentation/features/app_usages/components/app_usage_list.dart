import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_card.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

class AppUsageList extends StatefulWidget {
  final Mediator mediator;

  final int size;
  final List<String>? filterByTags;
  final Function(String int)? onOpenDetails;

  const AppUsageList({super.key, required this.mediator, this.size = 10, this.filterByTags, this.onOpenDetails});

  @override
  AppUsageListState createState() => AppUsageListState();
}

class AppUsageListState extends State<AppUsageList> {
  GetListByTopAppUsagesQueryResponse? _appUsages;

  @override
  void initState() {
    _getAppUsages();

    super.initState();
  }

  Future<void> _getAppUsages({int pageIndex = 0}) async {
    final query =
        GetListByTopAppUsagesQuery(pageIndex: pageIndex, pageSize: widget.size, filterByTags: widget.filterByTags);

    try {
      final result = await widget.mediator.send<GetListByTopAppUsagesQuery, GetListByTopAppUsagesQueryResponse>(query);

      if (mounted) {
        setState(() {
          if (_appUsages == null) {
            _appUsages = result;
          } else {
            _appUsages!.items.addAll(result.items);
            _appUsages!.pageIndex = result.pageIndex;
          }
        });
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: 'Unexpected error occurred while getting app usages.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_appUsages == null) {
      return const SizedBox.shrink();
    }

    if (_appUsages!.items.isEmpty) {
      return const Center(
        child: Text('No app usage data found'),
      );
    }

    double maxDuration = _appUsages!.items.map((e) => e.duration.toDouble() / 60).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var appUsage in _appUsages!.items)
          AppUsageCard(
            mediator: widget.mediator,
            appUsage: appUsage,
            maxDurationInListing: maxDuration,
            onTap: () => widget.onOpenDetails != null ? widget.onOpenDetails!(appUsage.id) : null,
          ),
        if (_appUsages!.hasNext)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: () {
                  _getAppUsages(pageIndex: _appUsages!.pageIndex + 1);
                },
                child: const Text('Load more'),
              ),
            ),
          ),
      ],
    );
  }
}
