import 'package:flutter/material.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

/// Dialog content component for selecting estimated time
/// Provides quick selection chips and custom time input with enhanced UI
class EstimatedTimeDialogContent extends StatelessWidget {
  final int selectedTime;
  final ValueChanged<int> onTimeSelected;
  final VoidCallback? onConfirm;
  final ITranslationService translationService;
  final ThemeData theme;

  const EstimatedTimeDialogContent({
    super.key,
    required this.selectedTime,
    required this.onTimeSelected,
    this.onConfirm,
    required this.translationService,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(translationService.translate(SharedTranslationKeys.timeDisplayEstimated)),
        automaticallyImplyLeading: true,
        actions: [
          if (selectedTime > 0)
            IconButton(
              onPressed: () => onTimeSelected(0),
              icon: const Icon(Icons.clear),
              tooltip: translationService.translate(SharedTranslationKeys.clearButton),
            ),
          TextButton(
            onPressed: () {
              onConfirm?.call();
              Navigator.of(context).pop();
            },
            child: Text(translationService.translate(SharedTranslationKeys.doneButton)),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.sizeMedium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Description section
                _buildDescriptionSection(context),

                const SizedBox(height: AppTheme.sizeLarge),

                // Quick time selection chips
                _buildQuickTimeChips(),

                const SizedBox(height: AppTheme.sizeLarge),

                // Custom time input section
                _buildCustomTimeSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the description section with helpful context
  Widget _buildDescriptionSection(BuildContext context) {
    return InformationCard.themed(
      context: context,
      icon: Icons.info_outline,
      text: translationService.translate(TaskTranslationKeys.estimatedTimeDescription),
    );
  }

  /// Builds the custom time input section with enhanced styling
  Widget _buildCustomTimeSection() {
    return Center(
      child: SizedBox(
        width: 250,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeLarge),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: AppTheme.sizeSmall,
                offset: const Offset(0, AppTheme.size2XSmall),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(TaskUiConstants.estimatedTimeIcon),
              const SizedBox(width: AppTheme.sizeSmall),
              acore.NumericInput(
                value: selectedTime,
                minValue: 0,
                maxValue: 480, // 8 hours maximum
                incrementValue: 5,
                decrementValue: 5,
                onValueChanged: onTimeSelected,
                valueSuffix: translationService.translate(SharedTranslationKeys.minutesShort),
                iconSize: AppTheme.iconSizeMedium,
                iconColor: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the quick time selection chips with optimized layout
  Widget _buildQuickTimeChips() {
    final quickTimeOptions = [
      {'time': 5, 'label': '5 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 10, 'label': '10 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 15, 'label': '15 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 30, 'label': '30 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 45, 'label': '45 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 60, 'label': '1 ${translationService.translate(SharedTranslationKeys.hoursShort)}'},
    ];

    return Wrap(
      spacing: AppTheme.sizeXSmall,
      runSpacing: AppTheme.sizeXSmall,
      children: quickTimeOptions.map((option) {
        final int time = option['time'] as int;
        final String label = option['label'] as String;
        final bool isSelected = selectedTime == time;

        return FilterChip(
          label: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12, // Slightly smaller font for better fit
              color: acore.ColorContrastHelper.getContrastingTextColor(
                isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
              ),
            ),
          ),
          selected: isSelected,
          onSelected: (_) => onTimeSelected(time),
          backgroundColor: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          selectedColor: theme.colorScheme.primaryContainer,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // More compact padding
          checkmarkColor: acore.ColorContrastHelper.getContrastingTextColor(theme.colorScheme.primaryContainer),
          side: BorderSide.none, // Remove border
          pressElevation: AppTheme.size2XSmall,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
        );
      }).toList(),
    );
  }
}
