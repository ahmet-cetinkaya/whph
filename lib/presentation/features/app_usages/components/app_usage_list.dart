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
  GetListByTopAppUsagesQueryResponse? _appUsages;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    _getAppUsages();

    super.initState();
  }

  Future<void> _getAppUsages({int pageIndex = 0}) async {
    final query = GetListByTopAppUsagesQuery(
      pageIndex: pageIndex,
      pageSize: widget.size,
      filterByTags: widget.filterByTags,
      startDate: widget.filterStartDate,
      endDate: widget.filterEndDate,
    );

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
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.getUsageError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_appUsages == null) {
      return const SizedBox.shrink();
    }

    if (_appUsages!.items.isEmpty) {
      return Center(
        child: Text(_translationService.translate(AppUsageTranslationKeys.noUsage)),
      );
    }

    double maxDuration = _appUsages!.items.map((e) => e.duration.toDouble() / 60).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final appUsage in _appUsages!.items)
          AppUsageCard(
            mediator: widget.mediator,
            appUsage: appUsage,
            maxDurationInListing: maxDuration,
            onTap: () => widget.onOpenDetails?.call(appUsage.id),
          ),
        if (_appUsages!.hasNext)
          Center(
            child: LoadMoreButton(
              onPressed: () => _getAppUsages(pageIndex: _appUsages!.pageIndex + 1),
            ),
          ),
      ],
    );
  }
}
