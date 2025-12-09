import 'package:flutter/material.dart';
import 'package:acore/acore.dart' as acore;
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';

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
        title: Text(
          translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
          style: AppTheme.headlineSmall,
        ),
        automaticallyImplyLeading: true,
        actions: [
          TextButton(
            onPressed: () {
              onConfirm?.call();
              Navigator.of(context).pop();
            },
            child: Text(
              translationService.translate(SharedTranslationKeys.doneButton),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppTheme.sizeLarge),
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

                // Custom time input section
                _buildCustomTimeSection(),

                const SizedBox(height: AppTheme.sizeLarge),

                // Quick time selection chips
                _buildQuickTimeChips(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppTheme.sizeSmall, bottom: AppTheme.sizeSmall),
          child: Text(
            translationService.translate(SharedTranslationKeys.custom),
            style: AppTheme.labelLarge,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          ),
          child: Row(
            children: [
              StyledIcon(
                TaskUiConstants.estimatedTimeIcon,
                isActive: true,
              ),
              const SizedBox(width: AppTheme.sizeLarge),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translationService.translate(SharedTranslationKeys.timeLoggingDuration),
                      style: AppTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      translationService.translate(SharedTranslationKeys.minutes),
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              acore.NumericInput(
                value: selectedTime,
                minValue: 0,
                maxValue: 480, // 8 hours maximum
                incrementValue: 5,
                decrementValue: 5,
                onValueChanged: onTimeSelected,
                valueSuffix: '', // Removed suffix as it's now in the description
                iconSize: AppTheme.iconSizeMedium,
                iconColor: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the quick time selection list with optimized layout
  Widget _buildQuickTimeChips() {
    final quickTimeOptions = [
      {'time': 0, 'label': translationService.translate(SharedTranslationKeys.notSetTime)},
      {'time': 5, 'label': '5 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 10, 'label': '10 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 15, 'label': '15 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 30, 'label': '30 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 45, 'label': '45 ${translationService.translate(SharedTranslationKeys.minutesShort)}'},
      {'time': 60, 'label': '1 ${translationService.translate(SharedTranslationKeys.hoursShort)}'},
    ];

    return Column(
      children: quickTimeOptions.map((option) {
        final int time = option['time'] as int;
        final String label = option['label'] as String;
        final bool isSelected = selectedTime == time;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.sizeSmall),
          child: InkWell(
            onTap: () => onTimeSelected(time),
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.sizeLarge,
                vertical: AppTheme.sizeMedium,
              ),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.12) : AppTheme.surface1,
                borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isSelected)
                    StyledIcon(
                      Icons.check_circle,
                      isActive: true,
                      size: AppTheme.iconSizeMedium,
                    )
                  else
                    Icon(
                      Icons.circle_outlined,
                      color: theme.colorScheme.outline,
                      size: AppTheme.iconSizeMedium,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
