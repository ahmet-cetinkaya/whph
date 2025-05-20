import 'package:intl/intl.dart';

class DateTimeHelper {
  static String getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        throw Exception('Invalid weekday');
    }
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

  /// Formats date/time information with the default format
  static String formatDateTime(DateTime? dateTime, {String format = 'yyyy-MM-dd HH:mm'}) {
    if (dateTime == null) return '';

    // First convert to local time zone, then format
    final localDateTime = toLocalDateTime(dateTime);
    return DateFormat(format).format(localDateTime);
  }

  /// Formats only the date with the default format
  static String formatDate(DateTime? dateTime, {String format = 'dd.MM.yyyy'}) {
    if (dateTime == null) return '';

    // First convert to local time zone, then format
    final localDateTime = toLocalDateTime(dateTime);
    return DateFormat(format).format(localDateTime);
  }

  /// Formats only the time with the default format
  static String formatTime(DateTime? dateTime, {String format = 'HH:mm'}) {
    if (dateTime == null) return '';

    // First convert to local time zone, then format
    final localDateTime = toLocalDateTime(dateTime);
    return DateFormat(format).format(localDateTime);
  }
}
