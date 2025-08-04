import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart' show DatePickerConfig, DateSelectionMode, QuickDateRange, DatePickerDialog;
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/components/filter_icon_button.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import '../constants/shared_translation_keys.dart';

class DateRangeFilter extends StatefulWidget {
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final Function(DateTime?, DateTime?) onDateFilterChange;
  final double iconSize;
  final Color? iconColor;

  const DateRangeFilter({
    super.key,
    this.selectedStartDate,
    this.selectedEndDate,
    required this.onDateFilterChange,
    this.iconSize = AppTheme.iconSizeMedium,
    this.iconColor,
  });

  @override
  State<DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends State<DateRangeFilter> {
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _selectedStartDate = widget.selectedStartDate;
    _selectedEndDate = widget.selectedEndDate;
  }

  @override
  void didUpdateWidget(DateRangeFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedStartDate != oldWidget.selectedStartDate ||
        widget.selectedEndDate != oldWidget.selectedEndDate) {
      setState(() {
        _selectedStartDate = widget.selectedStartDate;
        _selectedEndDate = widget.selectedEndDate;
      });
    }
  }


  String _getDateRangeText() {
    if (_selectedStartDate == null || _selectedEndDate == null) return '';
    return '${_selectedStartDate!.day}/${_selectedStartDate!.month} - ${_selectedEndDate!.day}/${_selectedEndDate!.month}';
  }

  List<QuickDateRange> _getQuickRanges() {
    return [
      QuickDateRange(
        key: 'today',
        label: _translationService.translate(SharedTranslationKeys.today),
        startDateCalculator: () {
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day);
        },
        endDateCalculator: () {
          final now = DateTime.now();
          return DateTime(now.year, now.month, now.day, 23, 59, 59);
        },
      ),
      QuickDateRange(
        key: 'this_week',
        label: _translationService.translate(SharedTranslationKeys.thisWeek),
        startDateCalculator: () {
          final now = DateTime.now();
          final daysToSubtract = now.weekday - 1;
          return DateTime(now.year, now.month, now.day - daysToSubtract);
        },
        endDateCalculator: () {
          final now = DateTime.now();
          final daysToAdd = 7 - now.weekday;
          return DateTime(now.year, now.month, now.day + daysToAdd, 23, 59, 59);
        },
      ),
      QuickDateRange(
        key: 'this_month',
        label: _translationService.translate(SharedTranslationKeys.thisMonth),
        startDateCalculator: () {
          final now = DateTime.now();
          return DateTime(now.year, now.month, 1);
        },
        endDateCalculator: () {
          final now = DateTime.now();
          final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
          return DateTime(now.year, now.month, lastDayOfMonth.day, 23, 59, 59);
        },
      ),
      QuickDateRange(
        key: 'this_3_months',
        label: _translationService.translate(SharedTranslationKeys.this3Months),
        startDateCalculator: () {
          final now = DateTime.now();
          final monthsToSubtract = (now.month - 1) % 3;
          return DateTime(now.year, now.month - monthsToSubtract, 1);
        },
        endDateCalculator: () {
          final now = DateTime.now();
          final monthsToSubtract = (now.month - 1) % 3;
          final endMonth = now.month - monthsToSubtract + 2;
          final endYear = now.year + (endMonth > 12 ? 1 : 0);
          final adjustedEndMonth = endMonth > 12 ? endMonth - 12 : endMonth;
          final lastDayOfEndMonth = DateTime(endYear, adjustedEndMonth + 1, 0);
          return DateTime(endYear, adjustedEndMonth, lastDayOfEndMonth.day, 23, 59, 59);
        },
      ),
      QuickDateRange(
        key: 'last_week',
        label: _translationService.translate(SharedTranslationKeys.lastWeek),
        startDateCalculator: () {
          final now = DateTime.now();
          return now.subtract(const Duration(days: 7));
        },
        endDateCalculator: () => DateTime.now(),
      ),
      QuickDateRange(
        key: 'last_month',
        label: _translationService.translate(SharedTranslationKeys.lastMonth),
        startDateCalculator: () {
          final now = DateTime.now();
          return now.subtract(const Duration(days: 30));
        },
        endDateCalculator: () => DateTime.now(),
      ),
      QuickDateRange(
        key: 'last_3_months',
        label: _translationService.translate(SharedTranslationKeys.last3Months),
        startDateCalculator: () {
          final now = DateTime.now();
          return now.subtract(const Duration(days: 90));
        },
        endDateCalculator: () => DateTime.now(),
      ),
    ];
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final translations = <String, String>{
      'date_picker_title': _translationService.translate(SharedTranslationKeys.dateRangeTitle),
      'confirm': _translationService.translate(SharedTranslationKeys.doneButton),
      'cancel': _translationService.translate(SharedTranslationKeys.cancelButton),
      'date_format_hint': _translationService.translate(SharedTranslationKeys.dateFormatHint),
    };

    final config = DatePickerConfig(
      selectionMode: DateSelectionMode.range,
      initialStartDate: _selectedStartDate,
      initialEndDate: _selectedEndDate,
      minDate: DateTime(2000),
      maxDate: DateTime(2050),
      showQuickRanges: true,
      quickRanges: _getQuickRanges(),
      enableManualInput: true,
      translations: translations,
    );

    final result = await DatePickerDialog.show(
      context: context,
      config: config,
    );

    if (result != null && result.isConfirmed) {
      setState(() {
        _selectedStartDate = result.startDate;
        _selectedEndDate = result.endDate;
      });
      widget.onDateFilterChange(_selectedStartDate, _selectedEndDate);
    }
  }


  void _onClearDate() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
    });
    widget.onDateFilterChange(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final hasDateFilter = _selectedStartDate != null && _selectedEndDate != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterIconButton(
          icon: Icons.calendar_month,
          iconSize: widget.iconSize,
          color: hasDateFilter ? primaryColor : widget.iconColor,
          tooltip: _translationService.translate(SharedTranslationKeys.dateFilterTooltip),
          onPressed: () => _showDatePicker(context),
        ),
        if (hasDateFilter) ...[
          const SizedBox(width: AppTheme.size2XSmall),
          Text(
            _getDateRangeText(),
            style: AppTheme.bodySmall.copyWith(
              color: primaryColor,
            ),
          ),
          const SizedBox(width: AppTheme.size2XSmall),
          FilterIconButton(
            icon: Icons.close,
            iconSize: AppTheme.iconSizeSmall,
            onPressed: _onClearDate,
            tooltip: _translationService.translate(SharedTranslationKeys.clearDateFilterTooltip),
          ),
        ],
      ],
    );
  }
}
