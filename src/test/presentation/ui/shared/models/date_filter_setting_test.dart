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
        final setting = DateFilterSetting.quickSelection(
          key: 'up_to_today',
          startDate: DateTime(2000, 1, 1),
          endDate: DateTime(2020, 1, 1),
          isAutoRefreshEnabled: true,
        );

        setting.calculateCurrentDateRange();

        // Simulate passing midnight
        await Future.delayed(const Duration(milliseconds: 1));

        final secondRange = setting.calculateCurrentDateRange();

        // Range should always be recalculated based on current time
        expect(secondRange.endDate, isNotNull);
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
