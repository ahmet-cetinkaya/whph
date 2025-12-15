import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

/// Displays summary statistics cards (total usage, average daily, peak hour).
class StatisticsSummaryCards extends StatelessWidget {
  final String totalUsage;
  final String averageDaily;
  final String peakHour;
  final String totalUsageLabel;
  final String averageDailyLabel;
  final String peakHourLabel;

  const StatisticsSummaryCards({
    super.key,
    required this.totalUsage,
    required this.averageDaily,
    required this.peakHour,
    required this.totalUsageLabel,
    required this.averageDailyLabel,
    required this.peakHourLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;

        if (isNarrowScreen) {
          return Column(
            children: [
              _buildSummaryCard(label: totalUsageLabel, value: totalUsage),
              const SizedBox(height: AppTheme.sizeMedium),
              _buildSummaryCard(label: averageDailyLabel, value: averageDaily),
              const SizedBox(height: AppTheme.sizeMedium),
              _buildSummaryCard(label: peakHourLabel, value: peakHour),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: _buildSummaryCard(label: totalUsageLabel, value: totalUsage)),
              const SizedBox(width: AppTheme.sizeMedium),
              Expanded(child: _buildSummaryCard(label: averageDailyLabel, value: averageDaily)),
              const SizedBox(width: AppTheme.sizeMedium),
              Expanded(child: _buildSummaryCard(label: peakHourLabel, value: peakHour)),
            ],
          );
        }
      },
    );
  }

  Widget _buildSummaryCard({required String label, required String value}) {
    return Card(
      color: AppTheme.surface1,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeMedium, horizontal: AppTheme.sizeSmall),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: AppTheme.size2XSmall),
              Text(value,
                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
