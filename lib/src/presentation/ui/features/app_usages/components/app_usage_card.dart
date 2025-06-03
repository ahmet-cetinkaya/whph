// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:whph/src/core/application/features/app_usages/queries/get_list_by_top_app_usages_query.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/components/bar_chart.dart';
import 'package:whph/src/presentation/ui/shared/components/label.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/src/presentation/ui/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
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
    final translationService = container.resolve<ITranslationService>();
    final primaryColor = Theme.of(context).primaryColor;
    final barColor = appUsage.color != null ? AppUsageUiConstants.getTagColor(appUsage.color) : primaryColor;

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
      additionalWidget: _buildAdditionalWidget(),
    );
  }

  Widget? _buildAdditionalWidget() {
    if (appUsage.tags.isEmpty) return null;

    final List<Color> tagColors = appUsage.tags
        .map((tag) => tag.tagColor != null ? Color(int.parse('FF${tag.tagColor}', radix: 16)) : Colors.grey)
        .toList();

    return Wrap(
      spacing: AppTheme.size2XSmall,
      runSpacing: AppTheme.size3XSmall,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "•",
          style: AppTheme.bodySmall.copyWith(color: AppTheme.disabledColor),
        ),
        Label.multipleColored(
          icon: TagUiConstants.tagIcon,
          color: Colors.grey, // Default color for icon and commas
          values: appUsage.tags.map((tag) => tag.tagName).toList(),
          colors: tagColors,
          mini: true,
        ),
      ],
    );
  }
}
