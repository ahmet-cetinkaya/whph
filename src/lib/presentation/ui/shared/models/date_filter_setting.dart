import 'package:acore/acore.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';

/// Represents a date filter setting with support for both quick selections and manual date ranges
class DateFilterSetting {
  /// Quick selection key (e.g., 'today', 'this_week', null for manual)
  final String? quickSelectionKey;

  /// Static start date (for manual ranges or as fallback)
  final DateTime? startDate;

  /// Static end date (for manual ranges or as fallback)
  final DateTime? endDate;

  /// Whether this filter was created using a quick selection
  final bool isQuickSelection;

  /// Whether auto-refresh is enabled for quick selections (dynamic dates)
  final bool isAutoRefreshEnabled;

  /// Whether to include items with null dates in the filter results
  final bool includeNullDates;

  /// Validates the following invariants:
  /// 1. If isQuickSelection is true, quickSelectionKey must not be null
  /// 2. If isAutoRefreshEnabled is true, isQuickSelection must also be true
  /// 3. For manual filters, at least one of startDate or endDate must be provided
  const DateFilterSetting._({
    this.quickSelectionKey,
    this.startDate,
    this.endDate,
    this.isQuickSelection = false,
    this.isAutoRefreshEnabled = false,
    this.includeNullDates = false,
  });

  factory DateFilterSetting({
    String? quickSelectionKey,
    DateTime? startDate,
    DateTime? endDate,
    bool isQuickSelection = false,
    bool isAutoRefreshEnabled = false,
    bool includeNullDates = false,
  }) {
    if (isQuickSelection && quickSelectionKey == null) {
      const errorCode = 'date_filter.quick_selection_key_required';
      Logger.error(
          '$errorCode: quickSelectionKey must be provided when isQuickSelection is true',
          component: 'DateFilterSetting');
      throw ArgumentError(
          'quickSelectionKey must be provided when isQuickSelection is true');
    }

    if (isAutoRefreshEnabled && !isQuickSelection) {
      const errorCode = 'date_filter.auto_refresh_not_allowed';
      Logger.error(
          '$errorCode: isAutoRefreshEnabled can only be true when isQuickSelection is true',
          component: 'DateFilterSetting');
      throw ArgumentError(
          'isAutoRefreshEnabled can only be true when isQuickSelection is true');
    }

    if (!isQuickSelection && startDate == null && endDate == null) {
      const errorCode = 'date_filter.no_dates_provided';
      Logger.error(
          '$errorCode: At least one of startDate or endDate must be provided for manual date filters',
          component: 'DateFilterSetting');
      throw ArgumentError(
          'At least one of startDate or endDate must be provided for manual date filters');
    }

    if (isAutoRefreshEnabled && !isQuickSelection) {
      const errorCode = 'date_filter.auto_refresh_not_allowed';
      Logger.error(
          '$errorCode: isAutoRefreshEnabled can only be true when isQuickSelection is true',
          component: 'DateFilterSetting');
      throw ArgumentError(
          'isAutoRefreshEnabled can only be true when isQuickSelection is true');
    }

    if (!isQuickSelection && startDate == null && endDate == null) {
      const errorCode = 'date_filter.no_dates_provided';
      Logger.error(
          '$errorCode: At least one of startDate or endDate must be provided for manual date filters',
          component: 'DateFilterSetting');
      throw ArgumentError(
          'At least one of startDate or endDate must be provided for manual date filters');
    }

    return DateFilterSetting._(
      quickSelectionKey: quickSelectionKey,
      startDate: startDate,
      endDate: endDate,
      isQuickSelection: isQuickSelection,
      isAutoRefreshEnabled: isAutoRefreshEnabled,
      includeNullDates: includeNullDates,
    );
  }

  /// Create a quick selection date filter
  factory DateFilterSetting.quickSelection({
    required String key,
    required DateTime startDate,
    required DateTime endDate,
    bool isAutoRefreshEnabled = false,
    bool includeNullDates = false,
  }) {
    // Known valid configuration, use const constructor directly for performance
    return DateFilterSetting._(
      quickSelectionKey: key,
      startDate: startDate,
      endDate: endDate,
      isQuickSelection: true,
      isAutoRefreshEnabled: isAutoRefreshEnabled,
      includeNullDates: includeNullDates,
    );
  }

  /// Create a manual date range filter
  factory DateFilterSetting.manual({
    required DateTime? startDate,
    required DateTime? endDate,
    bool includeNullDates = false,
  }) {
    // Known valid configuration, use const constructor directly for performance
    return DateFilterSetting._(
      quickSelectionKey: null,
      startDate: startDate,
      endDate: endDate,
      isQuickSelection: false,
      includeNullDates: includeNullDates,
    );
  }

  /// Copy with new values
  DateFilterSetting copyWith({
    String? quickSelectionKey,
    DateTime? startDate,
    DateTime? endDate,
    bool? isQuickSelection,
    bool? isAutoRefreshEnabled,
    bool? includeNullDates,
  }) {
    return DateFilterSetting(
      quickSelectionKey: quickSelectionKey ?? this.quickSelectionKey,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isQuickSelection: isQuickSelection ?? this.isQuickSelection,
      isAutoRefreshEnabled: isAutoRefreshEnabled ?? this.isAutoRefreshEnabled,
      includeNullDates: includeNullDates ?? this.includeNullDates,
    );
  }

  /// Create from JSON
  factory DateFilterSetting.fromJson(Map<String, dynamic> json) {
    DateTime? startDate;
    if (json['startDate'] != null) {
      startDate = DateTime.tryParse(json['startDate'] as String);
    }

    DateTime? endDate;
    if (json['endDate'] != null) {
      endDate = DateTime.tryParse(json['endDate'] as String);
    }

    final quickSelectionKey = json['quickSelectionKey'] as String?;
    var isQuickSelection = json['isQuickSelection'] as bool? ?? false;
    var isAutoRefreshEnabled = json['isAutoRefreshEnabled'] as bool? ?? false;
    final includeNullDates = json['includeNullDates'] as bool? ?? false;

    // Fix corrupted persisted data
    if (isQuickSelection && quickSelectionKey == null) {
      const errorCode = 'date_filter_invalid_json';
      Logger.warning(
          '$errorCode: Corrupted date filter: isQuickSelection=true without key',
          component: 'DateFilterSetting');
      isQuickSelection = false;
    }

    if (isAutoRefreshEnabled && !isQuickSelection) {
      const errorCode = 'date_filter_invalid_json';
      Logger.warning(
          '$errorCode: Corrupted date filter: isAutoRefreshEnabled=true without quick selection',
          component: 'DateFilterSetting');
      isAutoRefreshEnabled = false;
    }

    // Fallback to default if manual filter has no dates
    if (!isQuickSelection && startDate == null && endDate == null) {
      const errorCode = 'date_filter_invalid_json';
      Logger.warning(
          '$errorCode: Corrupted date filter: manual filter without dates, falling back to today',
          component: 'DateFilterSetting');
      isQuickSelection = false;
    }

    if (isAutoRefreshEnabled && !isQuickSelection) {
      Logger.warning(
          '[date_filter_invalid_json] Corrupted date filter: isAutoRefreshEnabled=true without quick selection',
          component: 'DateFilterSetting');
      isAutoRefreshEnabled = false;
    }

    // Fallback to default if manual filter has no dates
    if (!isQuickSelection && startDate == null && endDate == null) {
      Logger.warning(
          '[date_filter_invalid_json] Corrupted date filter: manual filter without dates, falling back to today',
          component: 'DateFilterSetting');
      final now = DateTime.now();
      return DateFilterSetting.quickSelection(
        key: 'today',
        startDate: DateTime(now.year, now.month, now.day),
        endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
        isAutoRefreshEnabled: true,
        includeNullDates: includeNullDates,
      );
    }

    return DateFilterSetting(
      quickSelectionKey: quickSelectionKey,
      startDate: startDate,
      endDate: endDate,
      isQuickSelection: isQuickSelection,
      isAutoRefreshEnabled: isAutoRefreshEnabled,
      includeNullDates: includeNullDates,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'quickSelectionKey': quickSelectionKey,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isQuickSelection': isQuickSelection,
      'isAutoRefreshEnabled': isAutoRefreshEnabled,
      'includeNullDates': includeNullDates,
    };
  }

  /// Calculate the actual date range based on current date if this is a quick selection
  DateRange calculateCurrentDateRange() {
    try {
      if (!isQuickSelection || quickSelectionKey == null) {
        return DateRange(startDate: startDate, endDate: endDate);
      }

      final now = DateTime.now();

      switch (quickSelectionKey!) {
        case 'today':
          final todayStart = DateTime(now.year, now.month, now.day);
          final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
          return DateRange(
            startDate: todayStart,
            endDate: todayEnd,
          );

        case 'this_week':
          final daysToSubtract = now.weekday - 1;
          final daysToAdd = 7 - now.weekday;
          final weekStart =
              DateTime(now.year, now.month, now.day - daysToSubtract);
          final weekEnd =
              DateTime(now.year, now.month, now.day + daysToAdd, 23, 59, 59);
          return DateRange(
            startDate: weekStart,
            endDate: weekEnd,
          );

        case 'this_month':
          final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
          final monthStart = DateTime(now.year, now.month, 1);
          final monthEnd =
              DateTime(now.year, now.month, lastDayOfMonth.day, 23, 59, 59);
          return DateRange(
            startDate: monthStart,
            endDate: monthEnd,
          );

        case 'this_3_months':
          final monthsToSubtract = (now.month - 1) % 3;
          final endMonth = now.month - monthsToSubtract + 2;
          final endYear = now.year + (endMonth > 12 ? 1 : 0);
          final adjustedEndMonth = endMonth > 12 ? endMonth - 12 : endMonth;
          final lastDayOfEndMonth = DateTime(endYear, adjustedEndMonth + 1, 0);
          final quarter3Start =
              DateTime(now.year, now.month - monthsToSubtract, 1);
          final quarter3End = DateTime(
              endYear, adjustedEndMonth, lastDayOfEndMonth.day, 23, 59, 59);
          return DateRange(
            startDate: quarter3Start,
            endDate: quarter3End,
          );

        case 'last_week':
          final lastWeekStart = now.subtract(const Duration(days: 7));
          return DateRange(
            startDate: lastWeekStart,
            endDate: now,
          );

        case 'last_month':
          final lastMonthStart = now.subtract(const Duration(days: 30));
          return DateRange(
            startDate: lastMonthStart,
            endDate: now,
          );

        case 'last_3_months':
          final last3MonthsStart = now.subtract(const Duration(days: 90));
          return DateRange(
            startDate: last3MonthsStart,
            endDate: now,
          );

        case 'up_to_today':
          try {
            // Includes all items from the stored start date up to end of current day
            // Used for filtering overdue tasks and all pending items with no future cutoff
            final upToTodayEnd =
                DateTime(now.year, now.month, now.day, 23, 59, 59);
            return DateRange(
              startDate: startDate,
              endDate: upToTodayEnd,
            );
          } catch (e, stackTrace) {
            Logger.error(
                '[date_filter_up_to_today_failed] Failed to calculate up_to_today date range',
                component: 'DateFilterSetting',
                error: e,
                stackTrace: stackTrace);
            return DateRange(startDate: startDate, endDate: endDate);
          }

        default:
          const errorCode = 'date_filter.unknown_quick_selection_key';
          Logger.error(
              '$errorCode: Unknown quick selection key: $quickSelectionKey',
              component: 'DateFilterSetting');
          throw BusinessException(
              'Unknown quick selection filter key: $quickSelectionKey',
              errorCode,
              args: {'key': quickSelectionKey ?? 'null'});
      }
    } catch (e, stackTrace) {
      const errorCode = 'date_filter.calculate_range_failed';
      Logger.error(
          '$errorCode: Failed to calculate current date range, falling back to today',
          component: 'DateFilterSetting',
          error: e,
          stackTrace: stackTrace);

      // Fallback to safe default today range that will never fail
      final now = DateTime.now();
      return DateRange(
        startDate: DateTime(now.year, now.month, now.day),
        endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateFilterSetting &&
        other.quickSelectionKey == quickSelectionKey &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.isQuickSelection == isQuickSelection &&
        other.isAutoRefreshEnabled == isAutoRefreshEnabled &&
        other.includeNullDates == includeNullDates;
  }

  @override
  int get hashCode {
    return Object.hash(quickSelectionKey, startDate, endDate, isQuickSelection,
        isAutoRefreshEnabled, includeNullDates);
  }

  @override
  String toString() {
    return 'DateFilterSetting('
        'quickSelectionKey: $quickSelectionKey, '
        'startDate: $startDate, '
        'endDate: $endDate, '
        'isQuickSelection: $isQuickSelection, '
        'isAutoRefreshEnabled: $isAutoRefreshEnabled, '
        'includeNullDates: $includeNullDates)';
  }
}

/// Represents a date range
class DateRange {
  final DateTime? startDate;
  final DateTime? endDate;

  /// Creates a date range. Automatically swaps dates if startDate > endDate.
  factory DateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    DateTime? finalStart = startDate;
    DateTime? finalEnd = endDate;

    if (finalStart != null &&
        finalEnd != null &&
        finalStart.isAfter(finalEnd)) {
      const errorCode = 'date_range_reversed';
      Logger.warning(
          '$errorCode: startDate is after endDate, automatically swapping values',
          component: 'DateRange');
      final temp = finalStart;
      finalStart = finalEnd;
      finalEnd = temp;
    }

    return DateRange._internal(finalStart, finalEnd);
  }

  const DateRange._internal(this.startDate, this.endDate);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRange &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(startDate, endDate);

  @override
  String toString() => 'DateRange(startDate: $startDate, endDate: $endDate)';
}
