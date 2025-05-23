// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/app_usages/queries/get_list_app_usage_tags_query.dart';
import 'package:whph/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/core/acore/errors/business_exception.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/bar_chart.dart';
import 'package:whph/presentation/shared/components/label.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/utils/error_helper.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class AppUsageCard extends StatelessWidget {
  final AppUsageListItem appUsage;
  final double maxDurationInListing;
  final VoidCallback? onTap;

  const AppUsageCard({
    super.key,
    required this.appUsage,
    required this.maxDurationInListing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mediator = container.resolve<Mediator>();
    final translationService = container.resolve<ITranslationService>();

    return FutureBuilder<GetListAppUsageTagsQueryResponse>(
      future: _getAppUsageTags(mediator),
      builder: (context, snapshot) {
        final appUsageTags = snapshot.data;
        final primaryColor = Theme.of(context).primaryColor;
        final barColor = appUsage.color != null ? AppUsageUiConstants.getTagColor(appUsage.color) : primaryColor;

        if (snapshot.hasError) {
          ErrorHelper.showUnexpectedError(
            context,
            snapshot.error as Exception,
            StackTrace.current,
            message: translationService.translate(AppUsageTranslationKeys.getTagsError),
          );
        }

        final duration = appUsage.duration.toDouble() / 60;
        // Use 1.0 as minimum maxDuration to avoid division by zero
        final maxDuration = maxDurationInListing > 0 ? maxDurationInListing.toDouble() : 1.0;

        return BarChart(
          title: appUsage.displayName ?? appUsage.name,
          value: duration,
          maxValue: maxDuration,
          formatValue: (value) => SharedUiConstants.formatDurationHuman(value.toInt(), translationService),
          barColor: barColor,
          onTap: onTap,
          additionalWidget: _buildAdditionalWidget(appUsageTags),
        );
      },
    );
  }

  Future<GetListAppUsageTagsQueryResponse> _getAppUsageTags(Mediator mediator) async {
    final query = GetListAppUsageTagsQuery(
      appUsageId: appUsage.id,
      pageIndex: 0,
      pageSize: 5,
    );

    return await mediator.send<GetListAppUsageTagsQuery, GetListAppUsageTagsQueryResponse>(query);
  }

  Widget? _buildAdditionalWidget(GetListAppUsageTagsQueryResponse? appUsageTags) {
    if (appUsageTags?.items.isEmpty ?? true) return null;

    final List<Color> tagColors = appUsageTags!.items
        .map((tag) => tag.tagColor != null ? Color(int.parse('FF${tag.tagColor}', radix: 16)) : Colors.grey)
        .toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "•",
            style: AppTheme.bodySmall.copyWith(color: AppTheme.disabledColor),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Label.multipleColored(
              icon: TagUiConstants.tagIcon,
              color: Colors.grey, // Default color for icon and commas
              values: appUsageTags.items.map((tag) => tag.tagName).toList(),
              colors: tagColors,
              mini: true,
            ),
          ),
        ],
      ),
    );
  }
}
