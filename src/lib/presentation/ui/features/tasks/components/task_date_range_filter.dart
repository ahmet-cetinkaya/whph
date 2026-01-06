import 'package:flutter/material.dart';
import 'package:acore/acore.dart' show DatePickerFooterAction, QuickDateRange;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/components/date_range_filter/date_range_filter.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';

class TaskDateRangeFilter extends StatefulWidget {
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final DateFilterSetting? dateFilterSetting;
  final Function(DateTime?, DateTime?) onDateFilterChange;
  final Function(DateFilterSetting?)? onDateFilterSettingChange;
  final Function(DateTime?, DateTime?, DateFilterSetting?)? onAutoRefresh;
  final double iconSize;
  final Color? iconColor;

  const TaskDateRangeFilter({
    super.key,
    this.selectedStartDate,
    this.selectedEndDate,
    this.dateFilterSetting,
    required this.onDateFilterChange,
    this.onDateFilterSettingChange,
    this.onAutoRefresh,
    this.iconSize = AppTheme.iconSizeMedium,
    this.iconColor,
  });

  @override
  State<TaskDateRangeFilter> createState() => _TaskDateRangeFilterState();
}

class _TaskDateRangeFilterState extends State<TaskDateRangeFilter> {
  late final ITranslationService _translationService;
  late final ValueNotifier<bool> _includeNullDatesNotifier;

  @override
  void initState() {
    super.initState();
    _translationService = container.resolve<ITranslationService>();
    _includeNullDatesNotifier = ValueNotifier<bool>(widget.dateFilterSetting?.includeNullDates ?? false);
  }

  @override
  void didUpdateWidget(TaskDateRangeFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dateFilterSetting?.includeNullDates != oldWidget.dateFilterSetting?.includeNullDates) {
      _includeNullDatesNotifier.value = widget.dateFilterSetting?.includeNullDates ?? false;
    }
  }

  @override
  void dispose() {
    _includeNullDatesNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DateRangeFilter(
      selectedStartDate: widget.selectedStartDate,
      selectedEndDate: widget.selectedEndDate,
      dateFilterSetting: widget.dateFilterSetting,
      onDateFilterChange: widget.onDateFilterChange,
      onDateFilterSettingChange: (setting) {
        if (widget.onDateFilterSettingChange != null) {
          final newSetting = setting?.copyWith(
            includeNullDates: _includeNullDatesNotifier.value,
          );
          widget.onDateFilterSettingChange!(newSetting);
        }
      },
      onAutoRefresh: widget.onAutoRefresh,
      iconSize: widget.iconSize,
      iconColor: widget.iconColor,
      additionalQuickRanges: [
        QuickDateRange(
          key: 'up_to_today',
          label: _translationService.translate(SharedTranslationKeys.dateTimePickerQuickSelectionUpToToday),
          startDateCalculator: () => TaskUiConstants.minFilterDate,
          endDateCalculator: () {
            final now = DateTime.now();
            return DateTime(now.year, now.month, now.day, 23, 59, 59);
          },
        ),
      ],
      footerActions: [
        DatePickerFooterAction(
          onPressed: () async {
            _includeNullDatesNotifier.value = !_includeNullDatesNotifier.value;
          },
          label: () => _translationService.translate(SharedTranslationKeys.dateTimePickerShowNoDate),
          icon: () => _includeNullDatesNotifier.value ? Icons.check_box : Icons.check_box_outline_blank,
          color: () => _includeNullDatesNotifier.value ? Theme.of(context).primaryColor : null,
          listenable: _includeNullDatesNotifier,
        ),
      ],
    );
  }
}
