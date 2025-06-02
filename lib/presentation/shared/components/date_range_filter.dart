import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:whph/core/acore/time/date_time_helper.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';
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
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _selectedStartDate = widget.selectedStartDate;
    _selectedEndDate = widget.selectedEndDate;
    _startDateController = TextEditingController(
      text: _formatDateForDisplay(_selectedStartDate),
    );
    _endDateController = TextEditingController(
      text: _formatDateForDisplay(_selectedEndDate),
    );
  }

  @override
  void didUpdateWidget(DateRangeFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedStartDate != oldWidget.selectedStartDate ||
        widget.selectedEndDate != oldWidget.selectedEndDate) {
      _selectedStartDate = widget.selectedStartDate;
      _selectedEndDate = widget.selectedEndDate;
      _startDateController.text = _formatDateForDisplay(_selectedStartDate);
      _endDateController.text = _formatDateForDisplay(_selectedEndDate);
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  String _formatDateForDisplay(DateTime? date) {
    if (date == null) return '';
    return DateTimeHelper.formatDate(date);
  }

  void _updateDateInput(String value, bool isStartDate) {
    final controller = isStartDate ? _startDateController : _endDateController;
    final oldValue = controller.text;

    String newText = value.replaceAll(RegExp(r'[^0-9/]'), '');
    if (newText.length > 10) newText = newText.substring(0, 10);

    // Add slashes automatically
    if (newText.length >= 2 && !newText.contains('/')) {
      newText = '${newText.substring(0, 2)}/${newText.substring(2)}';
    }
    if (newText.length >= 5 && newText.split('/').length == 2) {
      final parts = newText.split('/');
      newText = '${parts[0]}/${parts[1].substring(0, 2)}/${parts[1].substring(2)}';
    }

    // Only update if the text has changed
    if (oldValue != newText) {
      final newSelection = TextSelection.collapsed(
        offset: newText.length,
      );

      controller.value = TextEditingValue(
        text: newText,
        selection: newSelection,
      );
    }
  }

  String _getDateRangeText() {
    if (_selectedStartDate == null || _selectedEndDate == null) return '';
    return '${_selectedStartDate!.day}/${_selectedStartDate!.month} - ${_selectedEndDate!.day}/${_selectedEndDate!.month}';
  }

  void _selectQuickRange(String range, BuildContext context) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;
    final startOfDay = DateTime(now.year, now.month, now.day);

    switch (range) {
      case 'today':
        startDate = startOfDay;
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'this_week':
        // Find the start of the week (Monday)
        final daysToSubtract = now.weekday - 1;
        startDate = DateTime(now.year, now.month, now.day - daysToSubtract);
        // Find the end of the week (Sunday)
        final daysToAdd = 7 - now.weekday;
        endDate = DateTime(now.year, now.month, now.day + daysToAdd, 23, 59, 59);
        break;
      case 'this_month':
        // Start of the current month
        startDate = DateTime(now.year, now.month, 1);
        // End of the current month
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        endDate = DateTime(now.year, now.month, lastDayOfMonth.day, 23, 59, 59);
        break;
      case 'this_3_months':
        // Start of the current quarter
        final monthsToSubtract = (now.month - 1) % 3;
        startDate = DateTime(now.year, now.month - monthsToSubtract, 1);
        // End of the third month
        final endMonth = now.month - monthsToSubtract + 2; // +2 because we want the third month (0,1,2)
        final endYear = now.year + (endMonth > 12 ? 1 : 0);
        final adjustedEndMonth = endMonth > 12 ? endMonth - 12 : endMonth;
        final lastDayOfEndMonth = DateTime(endYear, adjustedEndMonth + 1, 0);
        endDate = DateTime(endYear, adjustedEndMonth, lastDayOfEndMonth.day, 23, 59, 59);
        break;
      case 'last_week':
        endDate = now;
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'last_month':
        endDate = now;
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'last_3_months':
        endDate = now;
        startDate = now.subtract(const Duration(days: 90));
        break;
      default:
        return;
    }

    setState(() {
      _selectedStartDate = startDate;
      _selectedEndDate = endDate;
      _startDateController.text = _formatDateForDisplay(startDate);
      _endDateController.text = _formatDateForDisplay(endDate);
    });
    widget.onDateFilterChange(startDate, endDate);
  }

  Future<void> _showDatePicker(BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog<List<DateTime?>>(
      context: context,
      size: DialogSize.large,
      child: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          appBar: AppBar(
            title: Text(_translationService.translate(SharedTranslationKeys.dateRangeTitle)),
            automaticallyImplyLeading: false,
            actions: [
              TextButton(
                onPressed: _closeDatePicker,
                child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
              ),
              const SizedBox(width: AppTheme.sizeSmall),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTheme.sizeMedium,
              AppTheme.sizeMedium,
              AppTheme.sizeMedium,
              MediaQuery.of(context).viewInsets.bottom + AppTheme.sizeMedium,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date Range Inputs Section
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startDateController,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: _translationService.translate(SharedTranslationKeys.dateFormatHint),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.size2XSmall, vertical: AppTheme.sizeSmall),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onTap: () {
                          if (_selectedStartDate != null) {
                            _scrollToDate(_selectedStartDate!);
                          }
                        },
                        onChanged: (value) => _updateDateInput(value, true),
                        onSubmitted: (value) {
                          final date = _parseDate(value);
                          if (date != null) {
                            setState(() {
                              _selectedStartDate = date;
                              _startDateController.text = _formatDateForDisplay(date);
                            });
                            if (_selectedEndDate != null) {
                              widget.onDateFilterChange(_selectedStartDate, _selectedEndDate);
                            }
                          }
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
                      child: Text('-'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _endDateController,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: _translationService.translate(SharedTranslationKeys.dateFormatHint),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.size2XSmall, vertical: AppTheme.sizeSmall),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onTap: () {
                          if (_selectedEndDate != null) {
                            _scrollToDate(_selectedEndDate!);
                          }
                        },
                        onChanged: (value) => _updateDateInput(value, false),
                        onSubmitted: (value) {
                          final date = _parseDate(value);
                          if (date != null) {
                            setState(() {
                              _selectedEndDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
                              _endDateController.text = _formatDateForDisplay(date);
                            });
                            if (_selectedStartDate != null) {
                              widget.onDateFilterChange(_selectedStartDate, _selectedEndDate);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.sizeMedium),

                // Quick Options Section
                Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.sizeMedium),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppTheme.size2XSmall,
                    runSpacing: AppTheme.size2XSmall,
                    children: [
                      _buildSimpleQuickOption(
                        context,
                        'today',
                        _translationService.translate(SharedTranslationKeys.today),
                        setState,
                      ),
                      _buildSimpleQuickOption(
                        context,
                        'this_week',
                        _translationService.translate(SharedTranslationKeys.thisWeek),
                        setState,
                      ),
                      _buildSimpleQuickOption(
                        context,
                        'this_month',
                        _translationService.translate(SharedTranslationKeys.thisMonth),
                        setState,
                      ),
                      _buildSimpleQuickOption(
                        context,
                        'this_3_months',
                        _translationService.translate(SharedTranslationKeys.this3Months),
                        setState,
                      ),
                      _buildSimpleQuickOption(
                        context,
                        'last_week',
                        _translationService.translate(SharedTranslationKeys.lastWeek),
                        setState,
                      ),
                      _buildSimpleQuickOption(
                        context,
                        'last_month',
                        _translationService.translate(SharedTranslationKeys.lastMonth),
                        setState,
                      ),
                      _buildSimpleQuickOption(
                        context,
                        'last_3_months',
                        _translationService.translate(SharedTranslationKeys.last3Months),
                        setState,
                      ),
                    ],
                  ),
                ),

                // Calendar Section
                CalendarDatePicker2(
                  key: ValueKey(_selectedStartDate ?? _selectedEndDate),
                  config: CalendarDatePicker2Config(
                    calendarType: CalendarDatePicker2Type.range,
                    selectedDayHighlightColor: Theme.of(context).primaryColor,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2050),
                    centerAlignModePicker: true,
                    selectedYearTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: _selectedStartDate != null && _selectedEndDate != null
                      ? [_selectedStartDate, _selectedEndDate]
                      : [],
                  onValueChanged: (dates) {
                    if (dates.length == 2) {
                      final startDate = DateTime(
                        dates[0].year,
                        dates[0].month,
                        dates[0].day,
                      );

                      final endDate = DateTime(
                        dates[1].year,
                        dates[1].month,
                        dates[1].day,
                        23,
                        59,
                        59,
                      );

                      setState(() {
                        _selectedStartDate = startDate;
                        _selectedEndDate = endDate;
                        _startDateController.text = _formatDateForDisplay(startDate);
                        _endDateController.text = _formatDateForDisplay(endDate);
                      });
                      widget.onDateFilterChange(startDate, endDate);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToDate(DateTime date) {
    setState(() {
      // Force calendar to rebuild with new current date
      _selectedStartDate = _selectedStartDate;
      _selectedEndDate = _selectedEndDate;
    });
  }

  void _closeDatePicker() {
    Navigator.pop(context);
  }

  Widget _buildSimpleQuickOption(BuildContext context, String value, String label, StateSetter setState) {
    final isSelected = _isQuickOptionSelected(value);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _selectQuickRange(value, context);
          setState(() {});
        },
        borderRadius: BorderRadius.circular(8),
        splashFactory: InkRipple.splashFactory,
        highlightColor: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        splashColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sizeSmall,
            vertical: AppTheme.size2XSmall,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : AppTheme.surface1,
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.2) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  bool _isQuickOptionSelected(String value) {
    if (_selectedStartDate == null || _selectedEndDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedStart = DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day);
    final selectedEnd = DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day, 23, 59, 59);

    switch (value) {
      case 'today':
        return _isSameDay(selectedStart, today) &&
            _isSameDay(selectedEnd.copyWith(hour: 0, minute: 0, second: 0), today);
      case 'this_week':
        final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final endOfWeek = DateTime(now.year, now.month, now.day + (7 - now.weekday), 23, 59, 59);
        return _isSameDay(selectedStart, startOfWeek) && _isSameDay(selectedEnd, endOfWeek);
      case 'this_month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        final endOfMonth = DateTime(now.year, now.month, lastDayOfMonth.day, 23, 59, 59);
        return _isSameDay(selectedStart, startOfMonth) && _isSameDay(selectedEnd, endOfMonth);
      case 'this_3_months':
        final monthsToSubtract = (now.month - 1) % 3;
        final startOfQuarter = DateTime(now.year, now.month - monthsToSubtract, 1);
        final endMonth = now.month - monthsToSubtract + 2;
        final endYear = now.year + (endMonth > 12 ? 1 : 0);
        final adjustedEndMonth = endMonth > 12 ? endMonth - 12 : endMonth;
        final lastDayOfEndMonth = DateTime(endYear, adjustedEndMonth + 1, 0);
        final endOfQuarter = DateTime(endYear, adjustedEndMonth, lastDayOfEndMonth.day, 23, 59, 59);
        return _isSameDay(selectedStart, startOfQuarter) && _isSameDay(selectedEnd, endOfQuarter);
      case 'last_week':
        final weekAgo = DateTime(now.year, now.month, now.day - 7);
        return _isSameDay(selectedStart, weekAgo) && _isSameDay(selectedEnd, today);
      case 'last_month':
        final monthAgo = DateTime(now.year, now.month, now.day - 30);
        return _isSameDay(selectedStart, monthAgo) && _isSameDay(selectedEnd, today);
      case 'last_3_months':
        final threeMonthsAgo = DateTime(now.year, now.month, now.day - 90);
        return _isSameDay(selectedStart, threeMonthsAgo) && _isSameDay(selectedEnd, today);
      default:
        return false;
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  DateTime? _parseDate(String value) {
    try {
      final parts = value.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        if (day < 1 || day > 31 || month < 1 || month > 12) return null;

        return DateTime(year, month, day);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error parsing date: $e');
    }
    return null;
  }

  void _onClearDate() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
      _startDateController.text = '';
      _endDateController.text = '';
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
