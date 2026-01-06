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

  const DateFilterSetting({
    this.quickSelectionKey,
    this.startDate,
    this.endDate,
    this.isQuickSelection = false,
    this.isAutoRefreshEnabled = false,
    this.includeNullDates = false,
  });

  /// Create a quick selection date filter
  factory DateFilterSetting.quickSelection({
    required String key,
    required DateTime startDate,
    required DateTime endDate,
    bool isAutoRefreshEnabled = false,
    bool includeNullDates = false,
  }) {
    return DateFilterSetting(
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
    return DateFilterSetting(
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

    return DateFilterSetting(
      quickSelectionKey: json['quickSelectionKey'] as String?,
      startDate: startDate,
      endDate: endDate,
      isQuickSelection: json['isQuickSelection'] as bool? ?? false,
      isAutoRefreshEnabled: json['isAutoRefreshEnabled'] as bool? ?? false,
      includeNullDates: json['includeNullDates'] as bool? ?? false,
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
        final weekStart = DateTime(now.year, now.month, now.day - daysToSubtract);
        final weekEnd = DateTime(now.year, now.month, now.day + daysToAdd, 23, 59, 59);
        return DateRange(
          startDate: weekStart,
          endDate: weekEnd,
        );

      case 'this_month':
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month, lastDayOfMonth.day, 23, 59, 59);
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
        final quarter3Start = DateTime(now.year, now.month - monthsToSubtract, 1);
        final quarter3End = DateTime(endYear, adjustedEndMonth, lastDayOfEndMonth.day, 23, 59, 59);
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

      default:
        // Fallback to static dates if unknown key
        return DateRange(startDate: startDate, endDate: endDate);
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
    return Object.hash(quickSelectionKey, startDate, endDate, isQuickSelection, isAutoRefreshEnabled, includeNullDates);
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

  const DateRange({
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateRange && other.startDate == startDate && other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(startDate, endDate);

  @override
  String toString() => 'DateRange(startDate: $startDate, endDate: $endDate)';
}
