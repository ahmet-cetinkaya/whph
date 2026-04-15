import 'package:flutter_test/flutter_test.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';

void main() {
  group('DateFilterSetting', () {
    group('calculateCurrentDateRange', () {
      test('up_to_today returns correct range', () {
        final now = DateTime.now();
        final expectedEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

        final setting = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate, DateTime(2000, 1, 1));
        expect(range.endDate?.year, expectedEnd.year);
        expect(range.endDate?.month, expectedEnd.month);
        expect(range.endDate?.day, expectedEnd.day);
        expect(range.endDate?.hour, 23);
        expect(range.endDate?.minute, 59);
        expect(range.endDate?.second, 59);
      });

      test('up_to_today updates dynamically', () async {
        // Get current date
        final now = DateTime.now();

        // Create filter with old historic dates that would never match current calculation
        final historicStart = DateTime(1990, 1, 1);
        final historicEnd = DateTime(1990, 12, 31);

        final setting = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: historicStart,
          endDate: historicEnd,
          isAutoRefreshEnabled: true,
        );

        // First calculation should return current date, NOT historic stored date
        final firstRange = setting.calculateCurrentDateRange();
        expect(firstRange.endDate?.year, now.year);
        expect(firstRange.endDate?.month, now.month);
        expect(firstRange.endDate?.day, now.day);

        // Verify end date is dynamically updated (start date remains stored value)
        expect(firstRange.startDate, historicStart);
        expect(firstRange.endDate, isNot(historicEnd));

        // No static dates are ever returned for dynamic quick selections
      });

      test('manual range returns static dates', () {
        final start = DateTime(2025, 1, 1);
        final end = DateTime(2025, 12, 31);

        final setting = DateFilterSetting.manual(
          startDate: start,
          endDate: end,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate, start);
        expect(range.endDate, end);
      });

      test('today returns correct range', () {
        final now = DateTime.now();

        final setting = DateFilterSetting.quickSelection(
          key: 'today',
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate?.year, now.year);
        expect(range.startDate?.month, now.month);
        expect(range.startDate?.day, now.day);
        expect(range.startDate?.hour, 0);
        expect(range.startDate?.minute, 0);
        expect(range.endDate?.year, now.year);
        expect(range.endDate?.month, now.month);
        expect(range.endDate?.day, now.day);
        expect(range.endDate?.hour, 23);
        expect(range.endDate?.minute, 59);
      });

      test('this_week returns correct range', () {
        final now = DateTime.now();
        final daysToSubtract = now.weekday - 1;
        final daysToAdd = 7 - now.weekday;

        final setting = DateFilterSetting.quickSelection(
          key: 'this_week',
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate?.year, now.year);
        expect(range.startDate?.month, now.month);
        expect(range.startDate?.day, now.day - daysToSubtract);
        expect(range.endDate?.year, now.year);
        expect(range.endDate?.month, now.month);
        expect(range.endDate?.day, now.day + daysToAdd);
        expect(range.endDate?.hour, 23);
        expect(range.endDate?.minute, 59);
      });

      test('this_month returns correct range', () {
        final now = DateTime.now();
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

        final setting = DateFilterSetting.quickSelection(
          key: 'this_month',
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate?.year, now.year);
        expect(range.startDate?.month, now.month);
        expect(range.startDate?.day, 1);
        expect(range.endDate?.year, now.year);
        expect(range.endDate?.month, now.month);
        expect(range.endDate?.day, lastDayOfMonth.day);
        expect(range.endDate?.hour, 23);
        expect(range.endDate?.minute, 59);
      });

      test('this_3_months returns correct range', () {
        final setting = DateFilterSetting.quickSelection(
          key: 'this_3_months',
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate, isNotNull);
        expect(range.endDate, isNotNull);
        expect(range.startDate!.isBefore(range.endDate!), isTrue);
      });

      test('last_week returns correct range', () {
        final setting = DateFilterSetting.quickSelection(
          key: 'last_week',
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate, isNotNull);
        expect(range.endDate, isNotNull);
        expect(range.startDate!.isBefore(range.endDate!), isTrue);
      });

      test('last_month returns correct range', () {
        final setting = DateFilterSetting.quickSelection(
          key: 'last_month',
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate, isNotNull);
        expect(range.endDate, isNotNull);
        expect(range.startDate!.isBefore(range.endDate!), isTrue);
      });

      test('last_3_months returns correct range', () {
        final setting = DateFilterSetting.quickSelection(
          key: 'last_3_months',
          startDate: DateTime(2020, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate, isNotNull);
        expect(range.endDate, isNotNull);
        expect(range.startDate!.isBefore(range.endDate!), isTrue);
      });

      test('unknown key falls back to static dates', () {
        final start = DateTime(2020, 1, 1);
        final end = DateTime(2020, 12, 31);

        final setting = DateFilterSetting.quickSelection(
          key: 'unknown_key',
          startDate: start,
          endDate: end,
          isAutoRefreshEnabled: true,
        );

        final range = setting.calculateCurrentDateRange();

        expect(range.startDate, start);
        expect(range.endDate, end);
      });
    });

    group('serialization', () {
      test('toJson and fromJson preserve all properties', () {
        final original = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
          includeNullDates: true,
        );

        final json = original.toJson();
        final restored = DateFilterSetting.fromJson(json);

        expect(restored.quickSelectionKey, original.quickSelectionKey);
        expect(restored.startDate, original.startDate);
        expect(restored.endDate, original.endDate);
        expect(restored.isQuickSelection, original.isQuickSelection);
        expect(restored.isAutoRefreshEnabled, original.isAutoRefreshEnabled);
        expect(restored.includeNullDates, original.includeNullDates);
      });
    });

    group('copyWith', () {
      test('creates modified copy correctly', () {
        final original = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: false,
          includeNullDates: false,
        );

        final modified = original.copyWith(
          isAutoRefreshEnabled: true,
          includeNullDates: true,
        );

        expect(modified.quickSelectionKey, 'up_to_today');
        expect(modified.isAutoRefreshEnabled, true);
        expect(modified.includeNullDates, true);
        expect(modified.startDate, original.startDate);
      });
    });

    group('equality', () {
      test('same properties are equal', () {
        final a = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final b = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        expect(a == b, isTrue);
        expect(a.hashCode == b.hashCode, isTrue);
      });

      test('different properties are not equal', () {
        final a = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        final b = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: false,
        );

        expect(a == b, isFalse);
      });
    });
  });
}
