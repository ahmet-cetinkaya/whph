import 'package:flutter/material.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:acore/utils/color_contrast_helper.dart';
import 'tour_step.dart';

/// Content card displayed during the tour showing step info.
class TourStepContent extends StatelessWidget {
  final TourStep step;
  final int stepNumber;
  final int totalSteps;

  const TourStepContent({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.9,
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.sizeMedium),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIndicator(),
            const SizedBox(height: AppTheme.sizeSmall),
            _buildTitleRow(),
            const SizedBox(height: AppTheme.sizeXSmall),
            _buildDescription(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sizeSmall,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(AppTheme.sizeXSmall),
      ),
      child: Text(
        '$stepNumber / $totalSteps',
        style: AppTheme.bodySmall.copyWith(
          color: ColorContrastHelper.getContrastingTextColor(AppTheme.primaryColor),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        if (step.icon != null) ...[
          Icon(
            step.icon,
            size: 32,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: AppTheme.sizeSmall),
        ],
        Expanded(
          child: Text(
            step.title,
            style: AppTheme.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      step.description,
      style: AppTheme.bodyMedium,
    );
  }
}
