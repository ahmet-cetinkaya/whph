import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart' hide Container;
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

/// A widget for selecting recurrence end condition (forever, until date, or count)
class RecurrenceEndConditionSelector extends StatelessWidget {
  final DateTime? endDate;
  final int? count;
  final DateTime minimumEndDate;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<int?> onCountChanged;
  final ITranslationService translationService;
  final TextEditingController endDateController;

  const RecurrenceEndConditionSelector({
    super.key,
    required this.endDate,
    required this.count,
    required this.minimumEndDate,
    required this.onEndDateChanged,
    required this.onCountChanged,
    required this.translationService,
    required this.endDateController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ToggleButtons(
          isSelected: [
            endDate == null && count == null, // Forever
            endDate != null, // Until Date
            count != null, // Count
          ],
          onPressed: (index) => _handleTogglePress(index, context),
          renderBorder: false,
          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          color: AppTheme.textColor,
          selectedColor: theme.colorScheme.onPrimary,
          fillColor: theme.colorScheme.primary,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
              child: Text(translationService.translate(TaskTranslationKeys.recurrenceEndsNever)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
              child: Text(translationService.translate(TaskTranslationKeys.recurrenceEndsOnDate)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
              child: Text(translationService.translate(TaskTranslationKeys.recurrenceEndsAfter)),
            ),
          ],
        ),
        if (endDate != null) _buildDatePicker(context),
        if (count != null) _buildCountInput(),
      ],
    );
  }

  void _handleTogglePress(int index, BuildContext context) {
    if (index == 0) {
      // Forever
      onEndDateChanged(null);
      onCountChanged(null);
    } else if (index == 1) {
      // Until Date
      onCountChanged(null);
      final newEndDate = endDate ?? minimumEndDate.add(const Duration(days: 30));
      onEndDateChanged(newEndDate);
    } else if (index == 2) {
      // Count
      onEndDateChanged(null);
      onCountChanged(count ?? 5);
    }
  }

  Widget _buildDatePicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.sizeMedium),
      child: Semantics(
        label: translationService.translate(TaskTranslationKeys.recurrenceEndsOnDate),
        button: true,
        child: InkWell(
          onTap: () => _showDatePicker(context),
          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(endDateController.text, style: AppTheme.bodyMedium),
                const SizedBox(width: AppTheme.sizeSmall),
                const Icon(Icons.calendar_today, size: AppTheme.iconSizeSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    if (!context.mounted) return;

    final config = DatePickerConfig(
      selectionMode: DateSelectionMode.single,
      initialDate: endDate,
      minDate: minimumEndDate,
      maxDate: DateTime(2100),
      formatType: DateFormatType.date,
      showTime: false,
      enableManualInput: true,
      titleText: translationService.translate(TaskTranslationKeys.recurrenceEndsLabel),
      translations: {
        DateTimePickerTranslationKey.title: translationService.translate(TaskTranslationKeys.recurrenceEndsLabel),
        DateTimePickerTranslationKey.confirm: translationService.translate(SharedTranslationKeys.doneButton),
        DateTimePickerTranslationKey.cancel: translationService.translate(SharedTranslationKeys.cancelButton),
      },
    );

    final result = await DatePickerDialog.show(context: context, config: config);

    if (result != null && !result.wasCancelled && result.selectedDate != null && context.mounted) {
      onEndDateChanged(result.selectedDate!);
    }
  }

  Widget _buildCountInput() {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.sizeMedium),
      child: NumericInput(
        value: count ?? 1,
        minValue: 1,
        maxValue: 999,
        onValueChanged: onCountChanged,
        style: NumericInputStyle.contained,
      ),
    );
  }
}
