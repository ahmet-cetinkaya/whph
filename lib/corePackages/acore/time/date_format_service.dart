import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'date_time_helper.dart';

/// Centralized service for consistent date formatting across the application.
/// Provides explicit formatting patterns for internal storage/logic and
/// locale-aware formatting for UI display.
class DateFormatService {
  // Private constructor to prevent instantiation
  DateFormatService._();

  // ==============================================================================
  // INTERNAL/STORAGE FORMATS (Consistent across all platforms and locales)
  // ==============================================================================

  /// Standard ISO format for internal storage and API communication
  static const String internalDateTimeFormat = 'yyyy-MM-dd HH:mm:ss';

  /// Standard ISO date format for internal storage
  static const String internalDateFormat = 'yyyy-MM-dd';

  /// Standard time format for internal storage
  static const String internalTimeFormat = 'HH:mm:ss';

  /// Short time format for internal storage (without seconds)
  static const String internalTimeShortFormat = 'HH:mm';

  // ==============================================================================
  // DISPLAY/UI FORMATS (Locale-aware for user interface)
  // ==============================================================================

  /// Formats DateTime for display in user interface with full locale support
  static String formatForDisplay(
    DateTime? dateTime,
    BuildContext context, {
    DateFormatType type = DateFormatType.dateTime,
    bool useShortFormat = false,
  }) {
    if (dateTime == null) return '';

    final locale = Localizations.localeOf(context);
    final localDateTime = DateTimeHelper.toLocalDateTime(dateTime);

    switch (type) {
      case DateFormatType.dateTime:
        return useShortFormat
            ? DateTimeHelper.formatDateTime(localDateTime, locale: locale)
            : DateTimeHelper.formatDateTimeMedium(localDateTime, locale: locale);

      case DateFormatType.date:
        return useShortFormat
            ? DateTimeHelper.formatDate(localDateTime, locale: locale)
            : DateTimeHelper.formatDateMedium(localDateTime, locale: locale);

      case DateFormatType.time:
        return DateTimeHelper.formatTime(localDateTime, locale: locale);

      case DateFormatType.relative:
        return _formatRelativeDate(localDateTime, context);
    }
  }

  /// Formats DateTime for internal storage/logic (consistent format)
  static String formatForStorage(
    DateTime? dateTime, {
    DateFormatType type = DateFormatType.dateTime,
  }) {
    if (dateTime == null) return '';

    // Always convert to UTC for storage to ensure consistency
    final utcDateTime = DateTimeHelper.toUtcDateTime(dateTime);

    switch (type) {
      case DateFormatType.dateTime:
        return DateFormat(internalDateTimeFormat).format(utcDateTime);

      case DateFormatType.date:
        return DateFormat(internalDateFormat).format(utcDateTime);

      case DateFormatType.time:
        return DateFormat(internalTimeFormat).format(utcDateTime);

      case DateFormatType.relative:
        // Relative formatting doesn't make sense for storage
        return DateFormat(internalDateTimeFormat).format(utcDateTime);
    }
  }

  // ==============================================================================
  // INPUT FIELD FORMATS (For form fields and user input)
  // ==============================================================================

  /// Gets the appropriate format pattern for input fields based on locale
  static String getInputFormatPattern(
    BuildContext context, {
    DateFormatType type = DateFormatType.dateTime,
  }) {
    final locale = Localizations.localeOf(context);

    switch (type) {
      case DateFormatType.dateTime:
        return DateTimeHelper.formatDateTime(DateTime.now(), locale: locale)
            .replaceAll(RegExp(r'\d'), '0'); // Replace digits with placeholder

      case DateFormatType.date:
        return DateTimeHelper.formatDate(DateTime.now(), locale: locale).replaceAll(RegExp(r'\d'), '0');

      case DateFormatType.time:
        return DateTimeHelper.formatTime(DateTime.now(), locale: locale).replaceAll(RegExp(r'\d'), '0');

      case DateFormatType.relative:
        return getInputFormatPattern(context, type: DateFormatType.dateTime);
    }
  }

  /// Formats DateTime for input fields (locale-aware but stable)
  static String formatForInput(
    DateTime? dateTime,
    BuildContext context, {
    DateFormatType type = DateFormatType.dateTime,
  }) {
    if (dateTime == null) return '';

    final locale = Localizations.localeOf(context);
    final localDateTime = DateTimeHelper.toLocalDateTime(dateTime);

    switch (type) {
      case DateFormatType.dateTime:
        return DateTimeHelper.formatDateTime(localDateTime, locale: locale);

      case DateFormatType.date:
        return DateTimeHelper.formatDate(localDateTime, locale: locale);

      case DateFormatType.time:
        return DateTimeHelper.formatTime(localDateTime, locale: locale);

      case DateFormatType.relative:
        return formatForInput(dateTime, context, type: DateFormatType.dateTime);
    }
  }

  // ==============================================================================
  // PARSING METHODS (Robust parsing with multiple format support)
  // ==============================================================================

  /// Parses a date string with multiple format attempts
  static DateTime? parseDateTime(
    String dateStr, {
    bool assumeLocal = true,
    Locale? locale,
  }) {
    if (dateStr.trim().isEmpty) return null;

    final trimmedStr = dateStr.trim();

    // Try parsing common formats in order of likelihood
    final formats = _getParsingFormats(locale);

    for (final format in formats) {
      try {
        final parsed = DateFormat(format).parse(trimmedStr);
        return assumeLocal ? parsed : DateTimeHelper.toUtcDateTime(parsed);
      } catch (e) {
        // Continue to next format
      }
    }

    // Try DateTime.tryParse as fallback (handles ISO formats)
    try {
      final parsed = DateTime.tryParse(trimmedStr);
      if (parsed != null) {
        return assumeLocal ? parsed : DateTimeHelper.toUtcDateTime(parsed);
      }
    } catch (e) {
      // Continue to alternative parsing
    }

    // Try alternative parsing methods for complex formats
    return _parseAlternativeFormats(trimmedStr, assumeLocal: assumeLocal);
  }

  /// Parse date from input field with locale-specific patterns
  static DateTime? parseFromInput(
    String input,
    BuildContext context, {
    DateFormatType type = DateFormatType.dateTime,
  }) {
    if (input.trim().isEmpty) return null;

    final locale = Localizations.localeOf(context);
    return parseDateTime(input, locale: locale, assumeLocal: true);
  }

  // ==============================================================================
  // RELATIVE DATE FORMATTING
  // ==============================================================================

  /// Formats a relative date (e.g., "Today", "Yesterday", "3 days ago")
  static String _formatRelativeDate(DateTime dateTime, BuildContext context) {
    final locale = Localizations.localeOf(context);
    final now = DateTime.now();
    final localDateTime = DateTimeHelper.toLocalDateTime(dateTime);
    final difference = now.difference(localDateTime);

    if (DateTimeHelper.isSameDay(localDateTime, now)) {
      return 'Today ${DateTimeHelper.formatTime(localDateTime, locale: locale)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7 && difference.inDays > 0) {
      return DateTimeHelper.getWeekday(localDateTime.weekday, locale);
    } else if (difference.inDays < -1) {
      // Future dates
      final futureDays = -difference.inDays;
      if (futureDays == 1) {
        return 'Tomorrow';
      } else if (futureDays < 7) {
        return DateTimeHelper.getWeekday(localDateTime.weekday, locale);
      }
    }

    // For dates older than a week or far in the future
    return DateTimeHelper.formatDate(localDateTime, locale: locale);
  }

  // ==============================================================================
  // PRIVATE HELPER METHODS
  // ==============================================================================

  /// Gets parsing formats in order of likelihood based on locale
  static List<String> _getParsingFormats(Locale? locale) {
    final localeName = locale?.toString() ?? 'en_US';

    final formats = <String>[
      // Internal/storage formats (always try first)
      internalDateTimeFormat,
      internalDateFormat,
      internalTimeShortFormat,

      // ISO formats
      'yyyy-MM-ddTHH:mm:ss.SSSZ',
      'yyyy-MM-ddTHH:mm:ssZ',
      'yyyy-MM-ddTHH:mm:ss',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',

      // Locale-specific formats
      ..._getLocaleSpecificFormats(localeName),

      // Common alternative formats
      'dd/MM/yyyy HH:mm',
      'MM/dd/yyyy HH:mm',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'd/M/yyyy H:mm',
      'M/d/yyyy H:mm',
      'd/M/yyyy',
      'M/d/yyyy',
      'dd.MM.yyyy HH:mm',
      'dd.MM.yyyy',
      'd.M.yyyy H:mm',
      'd.M.yyyy',

      // Time-only formats
      'HH:mm:ss',
      'HH:mm',
      'H:mm',
      'h:mm a',
      'h:mm:ss a',
    ];

    return formats;
  }

  /// Gets locale-specific date formats
  static List<String> _getLocaleSpecificFormats(String localeName) {
    if (localeName.startsWith('en_US')) {
      return [
        'MMM d, yyyy h:mm a', // Aug 5, 2025 2:30 PM
        'MMM d, yyyy HH:mm', // Aug 5, 2025 14:30
        'M/d/yyyy h:mm a',
        'M/d/yyyy H:mm',
        'MM/dd/yyyy h:mm a',
        'MM/dd/yyyy HH:mm',
        'M/d/yyyy',
        'MM/dd/yyyy',
        'MMM d, yyyy', // Aug 5, 2025
      ];
    } else if (localeName.startsWith('en_GB') || localeName.startsWith('en_AU') || localeName.startsWith('en_NZ')) {
      return [
        'd MMM yyyy HH:mm', // 5 Aug 2025 14:30
        'd/M/yyyy HH:mm',
        'dd/MM/yyyy HH:mm',
        'd/M/yyyy',
        'dd/MM/yyyy',
        'd MMM yyyy', // 5 Aug 2025
      ];
    } else if (localeName.startsWith('de')) {
      return [
        'd. MMM yyyy HH:mm', // 5. Aug 2025 14:30
        'd.M.yyyy HH:mm',
        'dd.MM.yyyy HH:mm',
        'd.M.yyyy',
        'dd.MM.yyyy',
        'd. MMM yyyy', // 5. Aug 2025
      ];
    } else if (localeName.startsWith('fr')) {
      return [
        'd MMM yyyy HH:mm', // 5 août 2025 14:30
        'd/M/yyyy HH:mm',
        'dd/MM/yyyy HH:mm',
        'd/M/yyyy',
        'dd/MM/yyyy',
        'd MMM yyyy', // 5 août 2025
      ];
    } else if (localeName.startsWith('tr')) {
      return [
        'd MMM yyyy HH:mm', // 5 Ağu 2025 14:30
        'd.M.yyyy HH:mm',
        'dd.MM.yyyy HH:mm',
        'd.M.yyyy',
        'dd.MM.yyyy',
        'd MMM yyyy', // 5 Ağu 2025
      ];
    }

    // Default to common medium formats
    return [
      'MMM d, yyyy HH:mm', // Default medium format with time
      'MMM d, yyyy h:mm a', // Default medium format with AM/PM
      'd MMM yyyy HH:mm', // European style medium format
      'MMM d, yyyy', // Default medium format date only
      'd MMM yyyy', // European style medium format date only
    ];
  }

  /// Alternative parsing for complex date formats
  static DateTime? _parseAlternativeFormats(String dateStr, {bool assumeLocal = true}) {
    try {
      // Handle medium format patterns that might not be in the main list

      // Try to parse common medium formats with regex patterns
      // Format: "Jun 5, 2025 14:30" or "Jun 5, 2025"
      final mediumFormat1 = RegExp(r'^(\w+)\s+(\d{1,2}),\s+(\d{4})(?:\s+(\d{1,2}):(\d{2}))?$');
      final match1 = mediumFormat1.firstMatch(dateStr);
      if (match1 != null) {
        final monthStr = match1.group(1)!;
        final day = int.parse(match1.group(2)!);
        final year = int.parse(match1.group(3)!);
        final hour = match1.group(4) != null ? int.parse(match1.group(4)!) : 0;
        final minute = match1.group(5) != null ? int.parse(match1.group(5)!) : 0;

        final month = _parseMonthName(monthStr);
        if (month != null) {
          final result = DateTime(year, month, day, hour, minute);
          return assumeLocal ? result : DateTimeHelper.toUtcDateTime(result);
        }
      }

      // Format: "5 Jun 2025 14:30" or "5 Jun 2025"
      final mediumFormat2 = RegExp(r'^(\d{1,2})\s+(\w+)\s+(\d{4})(?:\s+(\d{1,2}):(\d{2}))?$');
      final match2 = mediumFormat2.firstMatch(dateStr);
      if (match2 != null) {
        final day = int.parse(match2.group(1)!);
        final monthStr = match2.group(2)!;
        final year = int.parse(match2.group(3)!);
        final hour = match2.group(4) != null ? int.parse(match2.group(4)!) : 0;
        final minute = match2.group(5) != null ? int.parse(match2.group(5)!) : 0;

        final month = _parseMonthName(monthStr);
        if (month != null) {
          final result = DateTime(year, month, day, hour, minute);
          return assumeLocal ? result : DateTimeHelper.toUtcDateTime(result);
        }
      }

      // Handle formats like "6/3/2025 03:11", "6/3/2025", etc.

      // Try US format: M/d/yyyy H:mm or M/d/yyyy
      final usDateTimeRegex = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2}))?$');
      final usMatch = usDateTimeRegex.firstMatch(dateStr);
      if (usMatch != null) {
        final month = int.parse(usMatch.group(1)!);
        final day = int.parse(usMatch.group(2)!);
        final year = int.parse(usMatch.group(3)!);
        final hour = usMatch.group(4) != null ? int.parse(usMatch.group(4)!) : 0;
        final minute = usMatch.group(5) != null ? int.parse(usMatch.group(5)!) : 0;

        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final result = DateTime(year, month, day, hour, minute);
          return assumeLocal ? result : DateTimeHelper.toUtcDateTime(result);
        }
      }

      // Try European format: d/M/yyyy H:mm or d/M/yyyy
      final euDateTimeRegex = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2}))?$');
      final euMatch = euDateTimeRegex.firstMatch(dateStr);
      if (euMatch != null) {
        final day = int.parse(euMatch.group(1)!);
        final month = int.parse(euMatch.group(2)!);
        final year = int.parse(euMatch.group(3)!);
        final hour = euMatch.group(4) != null ? int.parse(euMatch.group(4)!) : 0;
        final minute = euMatch.group(5) != null ? int.parse(euMatch.group(5)!) : 0;

        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          // If day > 12, it's definitely European format
          if (day > 12 || month <= 12) {
            final result = DateTime(year, month, day, hour, minute);
            return assumeLocal ? result : DateTimeHelper.toUtcDateTime(result);
          }
        }
      }

      // Try dot-separated format (German style): d.M.yyyy H:mm or d.M.yyyy
      final dotDateTimeRegex = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:\s+(\d{1,2}):(\d{2}))?$');
      final dotMatch = dotDateTimeRegex.firstMatch(dateStr);
      if (dotMatch != null) {
        final day = int.parse(dotMatch.group(1)!);
        final month = int.parse(dotMatch.group(2)!);
        final year = int.parse(dotMatch.group(3)!);
        final hour = dotMatch.group(4) != null ? int.parse(dotMatch.group(4)!) : 0;
        final minute = dotMatch.group(5) != null ? int.parse(dotMatch.group(5)!) : 0;

        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final result = DateTime(year, month, day, hour, minute);
          return assumeLocal ? result : DateTimeHelper.toUtcDateTime(result);
        }
      }
    } catch (e) {
      // Parsing failed
    }

    return null;
  }

  /// Helper method to parse month names to month numbers
  static int? _parseMonthName(String monthStr) {
    final monthLower = monthStr.toLowerCase();

    // English months
    const monthsEn = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    // Turkish months
    const monthsTr = {
      'oca': 1,
      'ocak': 1,
      'şub': 2,
      'şubat': 2,
      'mar': 3,
      'mart': 3,
      'nis': 4,
      'nisan': 4,
      'may': 5,
      'mayıs': 5,
      'haz': 6,
      'haziran': 6,
      'tem': 7,
      'temmuz': 7,
      'ağu': 8,
      'ağustos': 8,
      'eyl': 9,
      'eylül': 9,
      'eki': 10,
      'ekim': 10,
      'kas': 11,
      'kasım': 11,
      'ara': 12,
      'aralık': 12,
    };

    // German months
    const monthsDe = {
      'jan': 1,
      'januar': 1,
      'feb': 2,
      'februar': 2,
      'mär': 3,
      'märz': 3,
      'apr': 4,
      'april': 4,
      'mai': 5,
      'jun': 6,
      'juni': 6,
      'jul': 7,
      'juli': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'september': 9,
      'okt': 10,
      'oktober': 10,
      'nov': 11,
      'november': 11,
      'dez': 12,
      'dezember': 12,
    };

    // French months
    const monthsFr = {
      'jan': 1,
      'janvier': 1,
      'fév': 2,
      'février': 2,
      'mar': 3,
      'mars': 3,
      'avr': 4,
      'avril': 4,
      'mai': 5,
      'jun': 6,
      'juin': 6,
      'jul': 7,
      'juillet': 7,
      'aoû': 8,
      'août': 8,
      'sep': 9,
      'septembre': 9,
      'oct': 10,
      'octobre': 10,
      'nov': 11,
      'novembre': 11,
      'déc': 12,
      'décembre': 12,
    };

    // Try all language month mappings
    return monthsEn[monthLower] ?? monthsTr[monthLower] ?? monthsDe[monthLower] ?? monthsFr[monthLower];
  }
}

/// Enum for different date format types
enum DateFormatType {
  /// Full date and time
  dateTime,

  /// Date only
  date,

  /// Time only
  time,

  /// Relative date (e.g., "Today", "Yesterday")
  relative,
}
