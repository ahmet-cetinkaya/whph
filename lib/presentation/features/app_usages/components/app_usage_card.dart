import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/features/shared/components/bar_chart.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/shared/utils/error_helper.dart';

class AppUsageCard extends StatefulWidget {
  final Mediator mediator;

  final AppUsageListItem appUsage;
  final double? maxDurationInListing;
  final void Function()? onTap;

  const AppUsageCard({
    super.key,
    required this.appUsage,
    required this.mediator,
    this.maxDurationInListing,
    this.onTap,
  });

  @override
  State<AppUsageCard> createState() => _AppUsageCardState();
}

class _AppUsageCardState extends State<AppUsageCard> {
  GetListAppUsageTagsQueryResponse? _appUsageTags;

  @override
  void initState() {
    super.initState();
    _getAppUsageTags();
  }

  Future<void> _getAppUsageTags() async {
    var query = GetListAppUsageTagsQuery(
      appUsageId: widget.appUsage.id,
      pageIndex: 0,
      pageSize: 100,
    );

    try {
      var result = await widget.mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(query);

      if (mounted) {
        setState(() {
          _appUsageTags = result;
        });
      }
    } on BusinessException catch (e) {
      if (mounted) ErrorHelper.showError(context, e);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(context, e, message: 'Unexpected error occurred while getting app usage tags.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BarChart(
      title: widget.appUsage.displayName ?? widget.appUsage.name,
      value: widget.appUsage.duration.toDouble() / 60,
      maxValue: widget.maxDurationInListing != null ? widget.maxDurationInListing!.toDouble() : double.infinity,
      unit: "min",
      barColor: Color(int.parse(widget.appUsage.color!, radix: 16)),
      onTap: widget.onTap,
      additionalWidget: _appUsageTags?.items.isNotEmpty == true
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "•",
                  style: TextStyle(
                    color: AppTheme.disabledColor,
                    fontSize: AppTheme.fontSizeSmall,
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  children: [
                    for (var i = 0; i < _appUsageTags!.items.length; i++) ...[
                      if (i > 0)
                        Text(", ",
                            style: TextStyle(
                              color: AppTheme.disabledColor,
                              fontSize: AppTheme.fontSizeSmall - 1,
                            )),
                      Text(
                        _appUsageTags!.items[i].tagName,
                        style: TextStyle(
                          color: _appUsageTags!.items[i].tagColor != null
                              ? Color(int.parse('FF${_appUsageTags!.items[i].tagColor}', radix: 16))
                              : AppTheme.disabledColor,
                          fontSize: AppTheme.fontSizeSmall - 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            )
          : null,
    );
  }
}
