import 'package:acore/acore.dart' show QuickDateRange;
import 'package:whph/shared/models/date_filter_setting.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';

/// Helper class for quick date range operations and matching logic.
class QuickDateRangeHelper {
  final ITranslationService _translationService;

  QuickDateRangeHelper({required ITranslationService translationService}) : _translationService = translationService;

  /// Get list of predefined quick date ranges
  List<QuickDateRange> getQuickRanges() {
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
    ];
  }

  /// Get label for a quick selection key
  String? getLabelForKey(String key) {
    try {
      final range = getQuickRanges().firstWhere((r) => r.key == key);
      return range.label;
    } catch (_) {
      return null;
    }
  }

  /// Try to detect quick selection from dates
  DateFilterSetting? tryDetectQuickSelectionFromDates(DateTime startDate, DateTime endDate) {
    final quickRanges = getQuickRanges();

    for (final quickRange in quickRanges) {
      final quickStart = quickRange.startDateCalculator();
      final quickEnd = quickRange.endDateCalculator();

      if (isExactQuickSelectionMatch(startDate, endDate, quickStart, quickEnd, quickRange.key)) {
        return DateFilterSetting.quickSelection(
          key: quickRange.key,
          startDate: startDate,
          endDate: endDate,
          isAutoRefreshEnabled: false,
        );
      }
    }
    return null;
  }

  /// Detect quick selection from dialog result
  String? detectQuickSelectionKey(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) return null;

    final quickRanges = getQuickRanges();
    final specificityOrder = [
      'today',
      'this_week',
      'this_month',
      'next_week',
      'last_week',
      'last_month',
    ];

    quickRanges.sort((a, b) {
      final aIndex = specificityOrder.indexOf(a.key);
      final bIndex = specificityOrder.indexOf(b.key);
      final aPos = aIndex == -1 ? 999 : aIndex;
      final bPos = bIndex == -1 ? 999 : bIndex;
      return aPos.compareTo(bPos);
    });

    for (final quickRange in quickRanges) {
      final quickStart = quickRange.startDateCalculator();
      final quickEnd = quickRange.endDateCalculator();

      if (isExactQuickSelectionMatch(startDate, endDate, quickStart, quickEnd, quickRange.key)) {
        return quickRange.key;
      }
    }
    return null;
  }

  /// More precise matching for quick selections to avoid false positives
  bool isExactQuickSelectionMatch(
      DateTime selectedStart, DateTime selectedEnd, DateTime quickStart, DateTime quickEnd, String quickKey) {
    switch (quickKey) {
      case 'today':
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
            duration.inMinutes >= 1439 &&
            selectedStart.day == quickStart.day &&
            selectedStart.month == quickStart.month &&
            selectedStart.year == quickStart.year &&
            isSameDay;

      case 'this_week':
        final weekStart = quickStart;
        final weekEnd = quickEnd;
        final duration = selectedEnd.difference(selectedStart);
        final isWeekDuration = duration.inDays >= 6;
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
            isWeekDuration;

      case 'this_month':
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

      case 'next_week':
      case 'last_week':
      case 'last_month':
        final startDiff = selectedStart.difference(quickStart).abs();
        final endDiff = selectedEnd.difference(quickEnd).abs();
        return startDiff.inSeconds < 60 && endDiff.inSeconds < 60;

      default:
        return false;
    }
  }
}
