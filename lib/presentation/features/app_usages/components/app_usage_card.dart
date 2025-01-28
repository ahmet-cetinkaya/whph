import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/components/bar_chart.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';

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
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _getAppUsageTags();
  }

  Future<void> _getAppUsageTags() async {
    var query = GetListAppUsageTagsQuery(
      appUsageId: widget.appUsage.id,
      pageIndex: 0,
      pageSize: 5,
    );

    try {
      var result = await widget.mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(query);

      if (mounted) {
        setState(() {
          _appUsageTags = result;
        });
      }
    } on BusinessException catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.getTagsError),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHelper.showUnexpectedError(
          context,
          e as Exception,
          stackTrace,
          message: _translationService.translate(AppUsageTranslationKeys.getTagsError),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final barColor =
        widget.appUsage.color != null ? AppUsageUiConstants.getTagColor(widget.appUsage.color) : primaryColor;

    return BarChart(
      title: widget.appUsage.displayName ?? widget.appUsage.name,
      value: widget.appUsage.duration.toDouble() / 60,
      maxValue: widget.maxDurationInListing != null ? widget.maxDurationInListing!.toDouble() : double.infinity,
      unit: _translationService.translate(SharedTranslationKeys.minutes),
      barColor: barColor,
      onTap: widget.onTap,
      additionalWidget: _buildAdditionalWidget(),
    );
  }

  Widget? _buildAdditionalWidget() {
    if (_appUsageTags?.items.isEmpty ?? true) return null;

    return Row(
      children: [
        Text(
          "•",
          style: AppTheme.bodySmall.copyWith(color: AppTheme.disabledColor),
        ),
        const SizedBox(width: 4),
        Row(
          children: [
            for (var i = 0; i < _appUsageTags!.items.length; i++) ...[
              if (i > 0)
                Text(
                  ", ",
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.disabledColor),
                ),
              Text(
                _appUsageTags!.items[i].tagName,
                style: AppTheme.bodySmall.copyWith(
                  color: AppUsageUiConstants.getTagColor(_appUsageTags!.items[i].tagColor),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
