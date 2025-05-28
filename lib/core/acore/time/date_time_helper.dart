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
        localeName.startsWith('en_PH') ||
        localeName.startsWith('en_IN') ||
        localeName.startsWith('en_MY') ||
        localeName.startsWith('en_SG') ||
        localeName.startsWith('ar_SA') ||
        localeName.startsWith('ar_EG') ||
        localeName.startsWith('hi') ||
        localeName.startsWith('bn') ||
        localeName.startsWith('ur')) {
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

    // Use locale-appropriate default date format
    final localeName = locale?.toString() ?? Intl.getCurrentLocale();
    final defaultFormat = _getDefaultDateFormat(localeName);
    return DateFormat(defaultFormat, locale?.toString()).format(localDateTime);
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
    final localeName = locale?.toString() ?? Intl.getCurrentLocale();
    final defaultFormat = _getDefaultTimeFormat(localeName);
    return DateFormat(defaultFormat, locale?.toString()).format(localDateTime);
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

  /// Formats date/time with medium locale-aware format
  static String formatDateTimeMedium(DateTime? dateTime, {Locale? locale}) {
    if (dateTime == null) return '';

    // First convert to local time zone
    final localDateTime = toLocalDateTime(dateTime);

    final localeName = locale?.toString() ?? Intl.getCurrentLocale();

    // Use appropriate medium format based on locale
    if (localeName.startsWith('en_US')) {
      return DateFormat('MMM d, yyyy h:mm a', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('en_GB') || localeName.startsWith('en_AU')) {
      return DateFormat('d MMM yyyy HH:mm', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('tr')) {
      return DateFormat('d MMM yyyy HH:mm', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('de')) {
      return DateFormat('d. MMM yyyy HH:mm', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('fr')) {
      return DateFormat('d MMM yyyy HH:mm', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('ja')) {
      return DateFormat('yyyy年M月d日 HH:mm', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('ko')) {
      return DateFormat('yyyy년 M월 d일 HH:mm', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('zh')) {
      return DateFormat('yyyy年M月d日 HH:mm', locale?.toString()).format(localDateTime);
    }

    // Default medium format
    return DateFormat.yMMMd(locale?.toString()).add_Hm().format(localDateTime);
  }

  /// Formats date with medium locale-aware format
  static String formatDateMedium(DateTime? dateTime, {Locale? locale}) {
    if (dateTime == null) return '';

    // First convert to local time zone
    final localDateTime = toLocalDateTime(dateTime);

    final localeName = locale?.toString() ?? Intl.getCurrentLocale();

    // Use appropriate medium format based on locale
    if (localeName.startsWith('ja')) {
      return DateFormat('yyyy年M月d日', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('ko')) {
      return DateFormat('yyyy년 M월 d일', locale?.toString()).format(localDateTime);
    } else if (localeName.startsWith('zh')) {
      return DateFormat('yyyy年M月d日', locale?.toString()).format(localDateTime);
    }

    // Default medium date format
    return DateFormat.yMMMd(locale?.toString()).format(localDateTime);
  }

  /// Gets default datetime format for locale
  static String _getDefaultDateTimeFormat(String localeName) {
    // Use 24-hour or 12-hour format based on locale
    final timePattern = is24HourFormat(Locale(localeName.split('_')[0])) ? 'HH:mm' : 'h:mm a';

    if (localeName.startsWith('en_US')) {
      return 'M/d/yyyy $timePattern';
    } else if (localeName.startsWith('en_GB') || localeName.startsWith('en_AU') || localeName.startsWith('en_NZ')) {
      return 'd/M/yyyy $timePattern';
    } else if (localeName.startsWith('en_CA')) {
      return 'yyyy-MM-dd $timePattern';
    } else if (localeName.startsWith('de')) {
      return 'd.M.yyyy HH:mm';
    } else if (localeName.startsWith('fr')) {
      return 'd/M/yyyy HH:mm';
    } else if (localeName.startsWith('tr')) {
      return 'd.MM.yyyy HH:mm';
    } else if (localeName.startsWith('ja')) {
      return 'yyyy/M/d $timePattern';
    } else if (localeName.startsWith('ko')) {
      return 'yyyy. M. d. $timePattern';
    } else if (localeName.startsWith('zh')) {
      return 'yyyy/M/d $timePattern';
    } else if (localeName.startsWith('ar')) {
      return 'd/M/yyyy $timePattern';
    } else if (localeName.startsWith('ru')) {
      return 'd.M.yyyy HH:mm';
    } else if (localeName.startsWith('es')) {
      return 'd/M/yyyy HH:mm';
    } else if (localeName.startsWith('it')) {
      return 'd/M/yyyy HH:mm';
    } else if (localeName.startsWith('pt')) {
      return 'd/M/yyyy HH:mm';
    } else if (localeName.startsWith('nl')) {
      return 'd-M-yyyy HH:mm';
    } else if (localeName.startsWith('sv') || localeName.startsWith('no') || localeName.startsWith('da')) {
      return 'yyyy-MM-dd HH:mm';
    }

    return 'yyyy-MM-dd HH:mm'; // ISO format as fallback
  }

  /// Gets default date format for locale
  static String _getDefaultDateFormat(String localeName) {
    if (localeName.startsWith('en_US')) {
      return 'M/d/yyyy';
    } else if (localeName.startsWith('en_GB') || localeName.startsWith('en_AU') || localeName.startsWith('en_NZ')) {
      return 'd/M/yyyy';
    } else if (localeName.startsWith('en_CA')) {
      return 'yyyy-MM-dd';
    } else if (localeName.startsWith('de')) {
      return 'd.M.yyyy';
    } else if (localeName.startsWith('fr')) {
      return 'd/M/yyyy';
    } else if (localeName.startsWith('tr')) {
      return 'd.MM.yyyy';
    } else if (localeName.startsWith('ja')) {
      return 'yyyy/M/d';
    } else if (localeName.startsWith('ko')) {
      return 'yyyy. M. d.';
    } else if (localeName.startsWith('zh')) {
      return 'yyyy/M/d';
    } else if (localeName.startsWith('ar')) {
      return 'd/M/yyyy';
    } else if (localeName.startsWith('ru')) {
      return 'd.M.yyyy';
    } else if (localeName.startsWith('es')) {
      return 'd/M/yyyy';
    } else if (localeName.startsWith('it')) {
      return 'd/M/yyyy';
    } else if (localeName.startsWith('pt')) {
      return 'd/M/yyyy';
    } else if (localeName.startsWith('nl')) {
      return 'd-M-yyyy';
    } else if (localeName.startsWith('sv') || localeName.startsWith('no') || localeName.startsWith('da')) {
      return 'yyyy-MM-dd';
    }

    return 'yyyy-MM-dd'; // ISO format as fallback
  }

  /// Gets default time format for locale
  static String _getDefaultTimeFormat(String localeName) {
    final use24Hour = is24HourFormat(Locale(localeName.split('_')[0]));

    if (use24Hour) {
      return 'HH:mm';
    } else {
      // For 12-hour format locales
      if (localeName.startsWith('en_US')) {
        return 'h:mm a';
      } else {
        return 'h:mm a'; // Standard 12-hour format
      }
    }
  }
}
