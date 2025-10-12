import 'package:flutter/material.dart';
import 'package:whph/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/bar_chart.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/tag_list_widget.dart';
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

  static final _translationService = container.resolve<ITranslationService>();

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final barColor = appUsage.color != null ? AppUsageUiConstants.getTagColor(appUsage.color) : primaryColor;

    final duration = appUsage.duration.toDouble() / 60;
    // Use 1.0 as minimum maxDuration to avoid division by zero
    final maxDuration = maxDurationInListing > 0 ? maxDurationInListing.toDouble() : 1.0;

    return BarChart(
      title: appUsage.displayName ?? appUsage.name,
      value: duration,
      maxValue: maxDuration,
      formatValue: (value) => SharedUiConstants.formatDurationHuman(value.toInt(), _translationService),
      barColor: barColor,
      onTap: onTap,
      additionalWidget: _buildAdditionalWidget(),
    );
  }

  Widget _buildAppUsageTagsWidget() {
    final items = TagDisplayUtils.tagDataToDisplayItems(appUsage.tags, _translationService);
    return TagListWidget(items: items);
  }

  Widget? _buildAdditionalWidget() {
    if (appUsage.tags.isEmpty) return null;

    return Wrap(
      spacing: AppTheme.size2XSmall,
      runSpacing: AppTheme.size3XSmall,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "•",
          style: AppTheme.bodySmall.copyWith(color: AppTheme.disabledColor),
        ),
        _buildAppUsageTagsWidget(),
      ],
    );
  }
}
