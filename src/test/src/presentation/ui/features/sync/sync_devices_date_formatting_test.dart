import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:acore/acore.dart' show DateTimeHelper;

void main() {
  setUpAll(() async {
    // Initialize locale data for testing
    await initializeDateFormatting();
  });

  group('Sync Devices Date Formatting Tests', () {
    test('formatDateTimeMedium should include both date and time', () {
      // Arrange
      final testDate = DateTime(2024, 1, 15, 14, 30, 0);
      const locale = Locale('en', 'US');

      // Act
      final formattedDateTime = DateTimeHelper.formatDateTimeMedium(testDate, locale: locale);

      // Assert
      expect(formattedDateTime, contains('Jan'));
      expect(formattedDateTime, contains('15'));
      expect(formattedDateTime, contains('2024'));
      expect(formattedDateTime, anyOf(contains('2:30'), contains('14:30')));
    });

    test('formatDateTimeMedium should handle different locales correctly', () {
      // Arrange
      final testDate = DateTime(2024, 1, 15, 14, 30, 0);

      // Test default locale behavior
      final defaultFormatted = DateTimeHelper.formatDateTimeMedium(testDate);

      // Test with explicit locale
      const locale = Locale('en', 'US');
      final localeFormatted = DateTimeHelper.formatDateTimeMedium(testDate, locale: locale);

      // Assert - both should contain date and time information
      expect(defaultFormatted, isNotEmpty);
      expect(localeFormatted, isNotEmpty);
      expect(defaultFormatted, contains('2024'));
      expect(localeFormatted, contains('2024'));
    });

    test('formatDateTimeMedium should handle null dates gracefully', () {
      // Act
      final result = DateTimeHelper.formatDateTimeMedium(null);

      // Assert
      expect(result, equals(''));
    });

    test('formatDateTimeMedium should convert UTC to local time', () {
      // Arrange
      final utcDate = DateTime.utc(2024, 1, 15, 14, 30, 0);
      const locale = Locale('en', 'US');

      // Act
      final formattedDateTime = DateTimeHelper.formatDateTimeMedium(utcDate, locale: locale);

      // Assert
      // The formatted result should contain date and time information
      // The exact time will depend on the local timezone, but it should be formatted
      expect(formattedDateTime, isNotEmpty);
      expect(formattedDateTime, contains('Jan'));
      expect(formattedDateTime, contains('15'));
      expect(formattedDateTime, contains('2024'));
    });

    test('formatDateTimeMedium provides more information than formatDate', () {
      // Arrange
      final testDate = DateTime(2024, 1, 15, 14, 30, 0);
      const locale = Locale('en', 'US');

      // Act
      final dateOnly = DateTimeHelper.formatDate(testDate, locale: locale);
      final dateTime = DateTimeHelper.formatDateTimeMedium(testDate, locale: locale);

      // Assert
      expect(dateTime.length, greaterThan(dateOnly.length));
      expect(dateTime, contains(dateOnly.split('/')[0])); // Contains month
      expect(dateTime, contains(dateOnly.split('/')[1])); // Contains day
      expect(dateTime, contains(dateOnly.split('/')[2])); // Contains year
      expect(dateTime, anyOf(contains('AM'), contains('PM'), contains(':')));
    });
  });
}
