import 'package:flutter/material.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_list_item.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/bar_chart.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/tag_list_widget.dart';
import 'package:whph/presentation/ui/shared/utils/tag_display_utils.dart';
import 'package:whph/main.dart';

class AppUsageCard extends StatelessWidget {
  final AppUsageListItem appUsage;
  final double maxDurationInListing;
  final double? maxCompareDurationInListing;
  final VoidCallback? onTap;
  final bool useTagColorForBars;

  const AppUsageCard({
    super.key,
    required this.appUsage,
    required this.maxDurationInListing,
    this.maxCompareDurationInListing,
    this.onTap,
    this.useTagColorForBars = false,
  });

  static final _translationService = container.resolve<ITranslationService>();

  Color _getBarColor(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // If toggle is ON and app usage has tags, use first tag's color
    if (useTagColorForBars && appUsage.tags.isNotEmpty) {
      final firstTag = appUsage.tags.first;
      if (firstTag.tagColor != null) {
        return AppUsageUiConstants.getTagColor(firstTag.tagColor!);
      }
    }

    // Otherwise use app usage's own color
    return appUsage.color != null ? AppUsageUiConstants.getTagColor(appUsage.color) : primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _getBarColor(context);

    final duration = appUsage.duration.toDouble() / 60;
    // Use 1.0 as minimum maxDuration to avoid division by zero
    final maxDuration = maxDurationInListing > 0 ? maxDurationInListing.toDouble() : 1.0;

    final compareDuration = appUsage.compareDuration != null ? appUsage.compareDuration!.toDouble() / 60 : null;
    final maxCompareDuration = maxCompareDurationInListing != null && maxCompareDurationInListing! > 0
        ? maxCompareDurationInListing!.toDouble()
        : 1.0;

    return BarChart(
      title: appUsage.displayName ?? appUsage.name,
      value: duration,
      maxValue: maxDuration,
      compareValue: compareDuration,
      compareMaxValue: maxCompareDuration,
      formatValue: (value) => SharedUiConstants.formatDurationHuman(value.toInt(), _translationService),
      barColor: barColor,
      onTap: onTap,
      additionalWidget: _buildAdditionalWidget(),
      minHeight: 40.0,
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
