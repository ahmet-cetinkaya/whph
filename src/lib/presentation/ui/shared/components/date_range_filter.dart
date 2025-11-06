import 'dart:async';
import 'package:flutter/material.dart' hide DatePickerDialog;
import 'package:acore/acore.dart'
    show DatePickerConfig, DateSelectionMode, QuickDateRange, DatePickerDialog, DateTimePickerTranslationKey;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import '../constants/shared_translation_keys.dart';

class DateRangeFilter extends StatefulWidget {
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final DateFilterSetting? dateFilterSetting;
  final Function(DateTime?, DateTime?) onDateFilterChange;
  final Function(DateFilterSetting?)? onDateFilterSettingChange;
  final Function(DateTime?, DateTime?, DateFilterSetting?)? onAutoRefresh;
  final double iconSize;
  final Color? iconColor;

  const DateRangeFilter({
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
  State<DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends State<DateRangeFilter> {
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  DateFilterSetting? _dateFilterSetting;
  String? _activeQuickSelectionKey;
  Timer? _autoRefreshTimer;

  // Preserve quick selection state for auto-refresh even if widget properties change
  DateFilterSetting? _preservedQuickSelectionSetting;

  // Track refresh toggle state
  bool _isRefreshToggleEnabled = false;

  // Track if we just performed a clear operation to avoid false detection
  bool _justCleared = false;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    _dateFilterSetting = widget.dateFilterSetting;

    if (_dateFilterSetting != null) {
      _activeQuickSelectionKey = _dateFilterSetting!.quickSelectionKey;
      _isRefreshToggleEnabled = _dateFilterSetting!.isAutoRefreshEnabled;

      if (_dateFilterSetting!.isQuickSelection) {
        // Calculate current date range for quick selections
        final currentRange = _dateFilterSetting!.calculateCurrentDateRange();
        _selectedStartDate = currentRange.startDate;
        _selectedEndDate = currentRange.endDate;

        // Preserve the quick selection setting immediately for auto-refresh
        _preservedQuickSelectionSetting = _dateFilterSetting;
      } else {
        _selectedStartDate = _dateFilterSetting!.startDate;
        _selectedEndDate = _dateFilterSetting!.endDate;
      }
    } else {
      // Fallback to legacy properties
      _selectedStartDate = widget.selectedStartDate;
      _selectedEndDate = widget.selectedEndDate;
      _activeQuickSelectionKey = null;
      _isRefreshToggleEnabled = false;

      // Try to detect if the legacy dates match a quick selection pattern
      if (_selectedStartDate != null && _selectedEndDate != null) {
        _tryDetectQuickSelectionFromDates();
      }
    }

    // Set up auto-refresh for quick selections
    _setupAutoRefresh();
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();

    if (_dateFilterSetting?.isQuickSelection == true && _isRefreshToggleEnabled) {
      // Preserve the quick selection setting for auto-refresh
      _preservedQuickSelectionSetting = _dateFilterSetting;

      // Determine refresh interval based on quick selection type - production values
      Duration refreshInterval;
      switch (_activeQuickSelectionKey) {
        case 'today':
          refreshInterval = const Duration(minutes: 15); // Refresh every 15 minutes for day-level
          break;
        case 'this_week':
          refreshInterval = const Duration(hours: 1); // Refresh every hour for week-level
          break;
        case 'this_month':
        case 'this_3_months':
          refreshInterval = const Duration(hours: 4); // Refresh every 4 hours for longer periods
          break;
        default:
          refreshInterval = const Duration(minutes: 30); // Default refresh
      }

      _autoRefreshTimer = Timer.periodic(refreshInterval, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // Use preserved setting if current one is null
        final activeQuickSetting = _preservedQuickSelectionSetting ?? _dateFilterSetting;

        if (activeQuickSetting?.isQuickSelection == true) {
          _refreshQuickSelection();
        }
      });
    }
  }

  void _refreshQuickSelection() {
    // Use preserved setting if current one is null or not a quick selection
    final activeQuickSetting = _preservedQuickSelectionSetting ?? _dateFilterSetting;

    if (activeQuickSetting?.isQuickSelection != true) {
      return;
    }

    // Recalculate current range using the active quick setting
    final currentRange = activeQuickSetting!.calculateCurrentDateRange();

    // Check if the range actually changed
    final hasChanged = currentRange.startDate != _selectedStartDate || currentRange.endDate != _selectedEndDate;

    if (hasChanged) {
      setState(() {
        _selectedStartDate = currentRange.startDate;
        _selectedEndDate = currentRange.endDate;
        // Preserve the quick selection state during refresh
        _dateFilterSetting = activeQuickSetting;
        _activeQuickSelectionKey = activeQuickSetting.quickSelectionKey;
      });

      // Call onAutoRefresh to notify parent of date changes without marking as "unsaved"
      widget.onAutoRefresh?.call(currentRange.startDate, currentRange.endDate, activeQuickSetting);
    }
  }

  @override
  void didUpdateWidget(DateRangeFilter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only update if the dateFilterSetting truly changed (ignoring auto-refresh updates)
    if (widget.dateFilterSetting != oldWidget.dateFilterSetting) {
      // If we're currently auto-refreshing and the new setting matches our preserved one, ignore
      if (_isAutoRefreshActive() && _isSameQuickSelection(widget.dateFilterSetting)) {
        return;
      }

      _updateFromWidgetProperties();
      _setupAutoRefresh();
    }

    // Handle legacy date properties for backward compatibility
    else if (_shouldUpdateFromLegacyDates(oldWidget)) {
      _updateFromLegacyProperties();
      _setupAutoRefresh();
    }
  }

  /// Check if auto-refresh is currently active
  bool _isAutoRefreshActive() {
    return _isRefreshToggleEnabled && _activeQuickSelectionKey != null && _autoRefreshTimer?.isActive == true;
  }

  /// Check if the new dateFilterSetting is the same quick selection we're already refreshing
  bool _isSameQuickSelection(DateFilterSetting? newSetting) {
    return newSetting?.quickSelectionKey == _activeQuickSelectionKey && newSetting?.isAutoRefreshEnabled == true;
  }

  /// Check if we should update from legacy date properties
  bool _shouldUpdateFromLegacyDates(DateRangeFilter oldWidget) {
    return widget.selectedStartDate != oldWidget.selectedStartDate ||
        widget.selectedEndDate != oldWidget.selectedEndDate;
  }

  /// Updates state from widget's dateFilterSetting
  void _updateFromWidgetProperties() {
    setState(() {
      _dateFilterSetting = widget.dateFilterSetting;

      if (_dateFilterSetting != null) {
        _activeQuickSelectionKey = _dateFilterSetting!.quickSelectionKey;
        _isRefreshToggleEnabled = _dateFilterSetting!.isAutoRefreshEnabled;

        if (_dateFilterSetting!.isQuickSelection) {
          final currentRange = _dateFilterSetting!.calculateCurrentDateRange();
          _selectedStartDate = currentRange.startDate;
          _selectedEndDate = currentRange.endDate;
          _preservedQuickSelectionSetting = _dateFilterSetting;
        } else {
          _selectedStartDate = _dateFilterSetting!.startDate;
          _selectedEndDate = _dateFilterSetting!.endDate;
          _preservedQuickSelectionSetting = null;
        }
      } else {
        // Clear operation
        _selectedStartDate = null;
        _selectedEndDate = null;
        _activeQuickSelectionKey = null;
        _isRefreshToggleEnabled = false;
        _preservedQuickSelectionSetting = null;
      }
    });
  }

  /// Updates state from legacy date properties (backward compatibility)
  void _updateFromLegacyProperties() {
    setState(() {
      _selectedStartDate = widget.selectedStartDate;
      _selectedEndDate = widget.selectedEndDate;

      // Try to detect quick selection pattern if dates are provided
      if (_selectedStartDate != null && _selectedEndDate != null && !_justCleared) {
        _tryDetectQuickSelectionFromDates();
      } else {
        _activeQuickSelectionKey = null;
        _isRefreshToggleEnabled = false;
        _preservedQuickSelectionSetting = null;
      }

      _justCleared = false;
    });
  }

  String _getDateRangeText() {
    if (_selectedStartDate == null || _selectedEndDate == null) return '';

    // If we have an active quick selection, show the label instead of dates
    if (_activeQuickSelectionKey != null) {
      final quickRanges = _getQuickRanges();

      // Find the exact match - don't use orElse with first item
      try {
        final quickRange = quickRanges.firstWhere(
          (range) => range.key == _activeQuickSelectionKey,
        );
        final baseText = quickRange.label;

        return baseText;
      } catch (e) {
        // If no match found, fall back to date format
        return '${_selectedStartDate!.day}/${_selectedStartDate!.month} - ${_selectedEndDate!.day}/${_selectedEndDate!.month}';
      }
    }

    return '${_selectedStartDate!.day}/${_selectedStartDate!.month} - ${_selectedEndDate!.day}/${_selectedEndDate!.month}';
  }

  List<QuickDateRange> _getQuickRanges() {
    final quickRanges = [
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

    return quickRanges;
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final translations = <DateTimePickerTranslationKey, String>{
      for (final key in DateTimePickerTranslationKey.values)
        key: _translationService.translate(SharedTranslationKeys.mapDateTimePickerKey(key)),
    };

    final quickRanges = _getQuickRanges();
    final config = DatePickerConfig(
      selectionMode: DateSelectionMode.range,
      initialStartDate: _selectedStartDate,
      initialEndDate: _selectedEndDate,
      minDate: DateTime(2000),
      maxDate: DateTime(2050),
      showQuickRanges: true,
      quickRanges: quickRanges,
      enableManualInput: true,
      translations: translations,
      showRefreshToggle: true,
      initialRefreshEnabled: _isRefreshToggleEnabled,
      onRefreshToggleChanged: (bool enabled) {
        // Don't update field state immediately - wait for Done button
        // The dialog will handle its own state internally
      },
      actionButtonRadius: AppTheme.containerBorderRadius,
    );

    final result = await DatePickerDialog.show(
      context: context,
      config: config,
    );

    if (result != null && result.isConfirmed) {
      final startDate = result.startDate;
      final endDate = result.endDate;
      final refreshEnabled = result.isRefreshEnabled ?? false;

      // Check if only refresh toggle changed (same dates, existing quick selection)
      final hasRefreshToggleOnlyChanged = startDate == _selectedStartDate &&
          endDate == _selectedEndDate &&
          _activeQuickSelectionKey != null &&
          refreshEnabled != _isRefreshToggleEnabled;

      // Detect if this was a quick selection by comparing with quick range calculations
      String? quickSelectionKey;
      bool isQuickSelection = false;

      // If we have an existing quick selection and dates haven't changed, preserve it
      if (hasRefreshToggleOnlyChanged) {
        quickSelectionKey = _activeQuickSelectionKey;
        isQuickSelection = true;
      } else if (startDate != null && endDate != null) {
        // Check for actual quick date selections
        // Check in order of specificity: most specific first to avoid false matches
        final quickRangesToCheck = quickRanges;

        // Sort by specificity: minute -> day -> week -> month -> etc.
        final specificityOrder = [
          'today',
          'this_week',
          'this_month',
          'this_3_months',
          'last_week',
          'last_month',
          'last_3_months',
        ];

        quickRangesToCheck.sort((a, b) {
          final aIndex = specificityOrder.indexOf(a.key);
          final bIndex = specificityOrder.indexOf(b.key);
          final aPos = aIndex == -1 ? 999 : aIndex;
          final bPos = bIndex == -1 ? 999 : bIndex;
          return aPos.compareTo(bPos);
        });

        for (final quickRange in quickRangesToCheck) {
          final quickStart = quickRange.startDateCalculator();
          final quickEnd = quickRange.endDateCalculator();

          // More precise matching for different time ranges
          final isExactMatch = _isExactQuickSelectionMatch(startDate, endDate, quickStart, quickEnd, quickRange.key);

          if (isExactMatch) {
            quickSelectionKey = quickRange.key;
            isQuickSelection = true;
            break;
          }
        }
      }

      // Create the appropriate date filter setting
      DateFilterSetting? newSetting;
      if (startDate != null || endDate != null) {
        if (isQuickSelection && quickSelectionKey != null) {
          newSetting = DateFilterSetting.quickSelection(
            key: quickSelectionKey,
            startDate: startDate!,
            endDate: endDate!,
            isAutoRefreshEnabled: refreshEnabled, // Use the actual refresh state from dialog
          );
        } else {
          newSetting = DateFilterSetting.manual(
            startDate: startDate,
            endDate: endDate,
          );
        }
      } else if (hasRefreshToggleOnlyChanged && _dateFilterSetting != null) {
        // Even if dates are cleared but we had a setting before, create a new setting with updated refresh state
        newSetting = DateFilterSetting(
          quickSelectionKey: _dateFilterSetting!.quickSelectionKey,
          startDate: _dateFilterSetting!.startDate,
          endDate: _dateFilterSetting!.endDate,
          isQuickSelection: _dateFilterSetting!.isQuickSelection,
          isAutoRefreshEnabled: refreshEnabled,
        );
      }

      setState(() {
        _selectedStartDate = startDate;
        _selectedEndDate = endDate;
        _dateFilterSetting = newSetting;

        // IMPORTANT: Only set the active quick selection if we actually detected one
        if (isQuickSelection && quickSelectionKey != null) {
          _activeQuickSelectionKey = quickSelectionKey;
          _isRefreshToggleEnabled = refreshEnabled; // Use dialog's refresh state

          // Preserve the quick selection setting for auto-refresh if refresh is enabled
          if (refreshEnabled) {
            _preservedQuickSelectionSetting = newSetting;
          }
        } else {
          // For manual selections, clear quick selection and disable refresh
          _activeQuickSelectionKey = null;
          _isRefreshToggleEnabled = false;
          _preservedQuickSelectionSetting = null;
        }
      });

      // Call both callbacks for backward compatibility
      // Always call callbacks when dialog is confirmed - let parent handle if there are actual changes
      widget.onDateFilterChange(startDate, endDate);
      widget.onDateFilterSettingChange?.call(newSetting);

      // Setup auto-refresh if this is a quick selection
      _setupAutoRefresh();
    }
  }

  /// Try to detect if the legacy dates match a quick selection pattern
  void _tryDetectQuickSelectionFromDates() {
    if (_selectedStartDate == null || _selectedEndDate == null) return;

    final quickRanges = _getQuickRanges();

    // Check each quick range to see if it matches the current dates
    for (final quickRange in quickRanges) {
      final quickStart = quickRange.startDateCalculator();
      final quickEnd = quickRange.endDateCalculator();

      final isExactMatch =
          _isExactQuickSelectionMatch(_selectedStartDate!, _selectedEndDate!, quickStart, quickEnd, quickRange.key);

      if (isExactMatch) {
        // Found a match! Set up the quick selection
        _activeQuickSelectionKey = quickRange.key;

        // For legacy fallback, don't assume refresh was enabled - keep it disabled by default
        // This prevents overriding user's saved preference
        _isRefreshToggleEnabled = false;

        // Create a DateFilterSetting for this detected quick selection
        _dateFilterSetting = DateFilterSetting.quickSelection(
          key: quickRange.key,
          startDate: _selectedStartDate!,
          endDate: _selectedEndDate!,
          isAutoRefreshEnabled: false,
        );

        // Don't preserve for auto-refresh since it's disabled
        _preservedQuickSelectionSetting = null;

        break;
      }
    }
  }

  void _onClearDate() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
      _dateFilterSetting = null;
      _activeQuickSelectionKey = null;
      _isRefreshToggleEnabled = false;
      _justCleared = true; // Mark that we just cleared
    });
    widget.onDateFilterChange(null, null);
    widget.onDateFilterSettingChange?.call(null);

    // Cancel auto-refresh when clearing and clear preserved state
    if (_autoRefreshTimer?.isActive == true) {
      _autoRefreshTimer?.cancel();
    }
    _preservedQuickSelectionSetting = null;
  }

  /// More precise matching for quick selections to avoid false positives
  bool _isExactQuickSelectionMatch(
      DateTime selectedStart, DateTime selectedEnd, DateTime quickStart, DateTime quickEnd, String quickKey) {
    switch (quickKey) {
      case 'today':
        // For today: start should be 00:00:00, end should be 23:59:59
        // And duration should be almost 24 hours - be very strict to avoid conflicts
        final duration = selectedEnd.difference(selectedStart);
        final isSameDay = selectedStart.day == selectedEnd.day &&
            selectedStart.month == selectedEnd.month &&
            selectedStart.year == selectedEnd.year;
        return selectedStart.hour == 0 &&
            selectedStart.minute == 0 &&
            selectedStart.second == 0 &&
            selectedStart.millisecond == 0 &&
            selectedEnd.hour == 23 &&
            selectedEnd.minute == 59 &&
            selectedEnd.second == 59 &&
            duration.inHours >= 23 &&
            duration.inMinutes >= 1439 && // Should be exactly 1439 minutes (23:59)
            selectedStart.day == quickStart.day &&
            selectedStart.month == quickStart.month &&
            selectedStart.year == quickStart.year &&
            isSameDay; // Ensure it's actually a single day

      case 'this_week':
        // For this_week: should be from Monday 00:00:00 to Sunday 23:59:59
        final weekStart = quickStart;
        final weekEnd = quickEnd;
        final duration = selectedEnd.difference(selectedStart);
        final isWeekDuration = duration.inDays >= 6; // Should span at least 6 days for a week
        return selectedStart.day == weekStart.day &&
            selectedStart.month == weekStart.month &&
            selectedStart.year == weekStart.year &&
            selectedStart.hour == 0 &&
            selectedStart.minute == 0 &&
            selectedStart.second == 0 &&
            selectedEnd.day == weekEnd.day &&
            selectedEnd.month == weekEnd.month &&
            selectedEnd.year == weekEnd.year &&
            selectedEnd.hour == 23 &&
            selectedEnd.minute == 59 &&
            selectedEnd.second == 59 &&
            isWeekDuration; // Ensure it's actually a week-long duration

      case 'this_month':
        // For this_month: should be from 1st 00:00:00 to last day 23:59:59
        final monthStart = quickStart;
        final monthEnd = quickEnd;
        return selectedStart.day == 1 &&
            selectedStart.month == monthStart.month &&
            selectedStart.year == monthStart.year &&
            selectedStart.hour == 0 &&
            selectedStart.minute == 0 &&
            selectedStart.second == 0 &&
            selectedEnd.day == monthEnd.day &&
            selectedEnd.month == monthEnd.month &&
            selectedEnd.year == monthEnd.year &&
            selectedEnd.hour == 23 &&
            selectedEnd.minute == 59 &&
            selectedEnd.second == 59;

      case 'this_3_months':
        // For this_3_months: quarter-based range
        final quarterStart = quickStart;
        final quarterEnd = quickEnd;
        return selectedStart.day == quarterStart.day &&
            selectedStart.month == quarterStart.month &&
            selectedStart.year == quarterStart.year &&
            selectedStart.hour == 0 &&
            selectedStart.minute == 0 &&
            selectedStart.second == 0 &&
            selectedEnd.day == quarterEnd.day &&
            selectedEnd.month == quarterEnd.month &&
            selectedEnd.year == quarterEnd.year &&
            selectedEnd.hour == 23 &&
            selectedEnd.minute == 59 &&
            selectedEnd.second == 59;

      case 'last_week':
      case 'last_month':
      case 'last_3_months':
        // For "last" selections, use precise date-time matching within small tolerance
        final startDiff = selectedStart.difference(quickStart).abs();
        final endDiff = selectedEnd.difference(quickEnd).abs();
        return startDiff.inSeconds < 60 && endDiff.inSeconds < 60;

      default:
        // No match for unknown keys
        return false;
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _preservedQuickSelectionSetting = null;
    super.dispose();
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRefreshToggleEnabled && _activeQuickSelectionKey != null) ...[
                Icon(
                  Icons.autorenew,
                  size: AppTheme.iconSizeSmall,
                  color: primaryColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                _getDateRangeText(),
                style: AppTheme.bodySmall.copyWith(
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
        // Clear button - only show when there's a date filter
        if (hasDateFilter) ...[
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
