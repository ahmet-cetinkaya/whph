import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class DateTimeHelper {
  /// Gets the localized weekday name
  static String getWeekday(int weekday, [Locale? locale]) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final targetDate = monday.add(Duration(days: weekday - 1));

    final formatter = DateFormat('E', locale?.toString());
    return formatter.format(targetDate);
  }

  /// Gets the localized short weekday name
  static String getWeekdayShort(int weekday, [Locale? locale]) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final targetDate = monday.add(Duration(days: weekday - 1));

    final formatter = DateFormat('EEE', locale?.toString());
    return formatter.format(targetDate);
  }

  /// Gets the first day of week based on locale (1 = Monday, 7 = Sunday)
  static int getFirstDayOfWeek([Locale? locale]) {
    final localeName = locale?.toString() ?? Intl.getCurrentLocale();

    // Most European countries, Russia, China start with Monday
    if (localeName.startsWith('en_US') ||
        localeName.startsWith('en_CA') ||
        localeName.startsWith('ar') ||
        localeName.startsWith('he') ||
        localeName.startsWith('ja') ||
        localeName.startsWith('ko')) {
      return 7; // Sunday
    }

    return 1; // Monday for most other locales
  }

  /// Checks if the locale uses 24-hour format
  static bool is24HourFormat([Locale? locale]) {
    final localeName = locale?.toString() ?? Intl.getCurrentLocale();

    // Countries that typically use 12-hour format
    if (localeName.startsWith('en_US') ||
        localeName.startsWith('en_CA') ||
        localeName.startsWith('en_AU') ||
        localeName.startsWith('en_NZ') ||
        localeName.startsWith('en_PH')) {
      return false;
    }

    return true; // Most other countries use 24-hour format
  }

  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  /// Converts a DateTime to local time zone if it's in UTC, or keeps it as is if already local
  static DateTime toLocalDateTime(DateTime dateTime) {
    // If already in local timezone, return as is
    if (!dateTime.isUtc) {
      return dateTime;
    }
    // Convert UTC date/time to local time zone
    return dateTime.toLocal();
  }

  /// Converts a DateTime to UTC if it's in local time zone, or keeps it as is if already UTC
  static DateTime toUtcDateTime(DateTime dateTime) {
    // If already in UTC timezone, return as is
    if (dateTime.isUtc) {
      return dateTime;
    }

    // Convert local date/time to UTC
    return dateTime.toUtc();
  }

  /// Formats date/time information with locale-aware format
  static String formatDateTime(DateTime? dateTime, {String? format, Locale? locale}) {
    if (dateTime == null) return '';

    // First convert to local time zone
    final localDateTime = toLocalDateTime(dateTime);

    if (format != null) {
      return DateFormat(format, locale?.toString()).format(localDateTime);
    }

    // Use locale-appropriate default format
    final localeName = locale?.toString() ?? Intl.getCurrentLocale();
    final defaultFormat = _getDefaultDateTimeFormat(localeName);
    return DateFormat(defaultFormat, locale?.toString()).format(localDateTime);
  }

  /// Formats only the date with locale-aware format
  static String formatDate(DateTime? dateTime, {String? format, Locale? locale}) {
    if (dateTime == null) return '';

    // First convert to local time zone
    final localDateTime = toLocalDateTime(dateTime);

    if (format != null) {
      return DateFormat(format, locale?.toString()).format(localDateTime);
    }

    // Use locale-appropriate default format
    return DateFormat.yMd(locale?.toString()).format(localDateTime);
  }

  /// Formats only the time with locale-aware format
  static String formatTime(DateTime? dateTime, {String? format, Locale? locale}) {
    if (dateTime == null) return '';

    // First convert to local time zone
    final localDateTime = toLocalDateTime(dateTime);

    if (format != null) {
      return DateFormat(format, locale?.toString()).format(localDateTime);
    }

    // Use locale-appropriate time format (12/24 hour)
    if (is24HourFormat(locale)) {
      return DateFormat.Hm(locale?.toString()).format(localDateTime);
    } else {
      return DateFormat.jm(locale?.toString()).format(localDateTime);
    }
  }

  /// Formats hour with locale-aware format (12/24 hour)
  static String formatHour(int hour, [Locale? locale]) {
    final dateTime = DateTime(2024, 1, 1, hour);

    if (is24HourFormat(locale)) {
      return DateFormat.H(locale?.toString()).format(dateTime);
    } else {
      return DateFormat.j(locale?.toString()).format(dateTime);
    }
  }

  /// Formats duration with locale-aware format
  static String formatDuration(Duration duration, [Locale? locale]) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final localeName = locale?.toString() ?? Intl.getCurrentLocale();

    if (hours > 0) {
      if (localeName.startsWith('tr')) {
        return '$hours sa ${minutes > 0 ? '$minutes dk' : ''}';
      } else {
        return '$hours h ${minutes > 0 ? '$minutes m' : ''}';
      }
    } else if (minutes > 0) {
      if (localeName.startsWith('tr')) {
        return '$minutes dk';
      } else {
        return '$minutes min';
      }
    } else {
      if (localeName.startsWith('tr')) {
        return '$seconds sn';
      } else {
        return '$seconds sec';
      }
    }
  }

  /// Formats duration in short format with locale-aware format
  static String formatDurationShort(Duration duration, [Locale? locale]) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final localeName = locale?.toString() ?? Intl.getCurrentLocale();

    if (hours > 0) {
      if (localeName.startsWith('tr')) {
        return '${hours}sa';
      } else {
        return '${hours}h';
      }
    } else if (minutes > 0) {
      if (localeName.startsWith('tr')) {
        return '${minutes}dk';
      } else {
        return '${minutes}m';
      }
    } else {
      if (localeName.startsWith('tr')) {
        return '${seconds}sn';
      } else {
        return '${seconds}s';
      }
    }
  }

  /// Gets default datetime format for locale
  static String _getDefaultDateTimeFormat(String localeName) {
    if (localeName.startsWith('en_US')) {
      return 'M/d/yyyy h:mm a';
    } else if (localeName.startsWith('en_GB') || localeName.startsWith('en_AU')) {
      return 'd/M/yyyy HH:mm';
    } else if (localeName.startsWith('de')) {
      return 'd.M.yyyy HH:mm';
    } else if (localeName.startsWith('fr')) {
      return 'd/M/yyyy HH:mm';
    } else if (localeName.startsWith('tr')) {
      return 'd.M.yyyy HH:mm';
    }

    return 'yyyy-MM-dd HH:mm'; // ISO format as fallback
  }
}
