import 'package:dart_json_mapper/dart_json_mapper.dart' as jm;

@jm.jsonSerializable
enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly,
  hourly,
  minutely,
}

@jm.jsonSerializable
enum RecurrenceEndCondition {
  never,
  date,
  count,
}

@jm.jsonSerializable
enum RecurrenceFromPolicy {
  plannedDate,
  completionDate,
}

@jm.jsonSerializable
enum MonthlyPatternType {
  specificDay, // e.g., 15th
  relativeDay, // e.g., 2nd Tuesday
}

/// Represents a specific day of the week with a designated time
/// Used for weekly recurrence patterns where different days can have different times
@jm.jsonSerializable
class WeeklySchedule {
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final int hour; // 0-23
  final int minute; // 0-59

  const WeeklySchedule({
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
  });

  /// Validates a WeeklySchedule and throws ArgumentError if invalid
  static void _validate(int dayOfWeek, int hour, int minute) {
    if (dayOfWeek < 1 || dayOfWeek > 7) {
      throw ArgumentError.value(
        dayOfWeek,
        'dayOfWeek',
        'Must be between 1 (Monday) and 7 (Sunday)',
      );
    }
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(
        hour,
        'hour',
        'Must be between 0 and 23',
      );
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(
        minute,
        'minute',
        'Must be between 0 and 59',
      );
    }
  }

  /// Creates a validated WeeklySchedule from JSON
  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    final dayOfWeek = json['dayOfWeek'] as int;
    final hour = json['hour'] as int;
    final minute = json['minute'] as int;

    // Validate before constructing
    _validate(dayOfWeek, hour, minute);

    return WeeklySchedule(
      dayOfWeek: dayOfWeek,
      hour: hour,
      minute: minute,
    );
  }

  /// Creates a validated WeeklySchedule with runtime validation
  factory WeeklySchedule.validated({
    required int dayOfWeek,
    required int hour,
    required int minute,
  }) {
    _validate(dayOfWeek, hour, minute);
    return WeeklySchedule(
      dayOfWeek: dayOfWeek,
      hour: hour,
      minute: minute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'hour': hour,
      'minute': minute,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeeklySchedule && other.dayOfWeek == dayOfWeek && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(dayOfWeek, hour, minute);
}

/// Validation constants for RecurrenceConfiguration
class RecurrenceConfigurationValidation {
  static const int minInterval = 1;
  static const int maxInterval = 365; // One year maximum
  static const int minDayOfMonth = 1;
  static const int maxDayOfMonth = 31;
  static const int minDayOfWeek = 1;
  static const int maxDayOfWeek = 7;
  static const int minWeekOfMonth = 1;
  static const int maxWeekOfMonth = 5;
  static const int minMonthOfYear = 1;
  static const int maxMonthOfYear = 12;
  static const int maxOccurrenceCount = 10000; // Reasonable upper bound
  static const int minHour = 0;
  static const int maxHour = 23;
  static const int minMinute = 0;
  static const int maxMinute = 59;
}

@jm.jsonSerializable
class RecurrenceConfiguration {
  final RecurrenceFrequency frequency;
  final int interval;

  // Weekly specific
  final List<int>? daysOfWeek; // 1=Monday, 7=Sunday
  final List<WeeklySchedule>? weeklySchedule; // Per-day time schedules for weekly recurrence

  // Monthly specific
  final MonthlyPatternType? monthlyPatternType;
  final int? dayOfMonth; // 1-31
  final int? weekOfMonth; // 1, 2, 3, 4, 5 (Last)
  final int? dayOfWeek; // 1-7 (for relative pattern)

  // Yearly specific
  final int? monthOfYear; // 1-12

  // End condition
  final RecurrenceEndCondition endCondition;
  final DateTime? endDate;
  final int? occurrenceCount;

  // Advanced
  final RecurrenceFromPolicy fromPolicy;

  RecurrenceConfiguration({
    required this.frequency,
    this.interval = 1,
    List<int>? daysOfWeek,
    List<WeeklySchedule>? weeklySchedule,
    this.monthlyPatternType,
    this.dayOfMonth,
    this.weekOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    this.endCondition = RecurrenceEndCondition.never,
    this.endDate,
    this.occurrenceCount,
    this.fromPolicy = RecurrenceFromPolicy.plannedDate,
  })  : daysOfWeek = daysOfWeek != null ? List.unmodifiable(daysOfWeek) : null,
        weeklySchedule = weeklySchedule != null ? List.unmodifiable(weeklySchedule) : null {
    _validate();
  }

  /// Creates a RecurrenceConfiguration for testing purposes without validation.
  /// This should ONLY be used in tests to create configurations with intentionally
  /// invalid dates (e.g., past dates) to test edge cases.
  factory RecurrenceConfiguration.test({
    required RecurrenceFrequency frequency,
    int interval = 1,
    List<int>? daysOfWeek,
    List<WeeklySchedule>? weeklySchedule,
    MonthlyPatternType? monthlyPatternType,
    int? dayOfMonth,
    int? weekOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
    RecurrenceEndCondition endCondition = RecurrenceEndCondition.never,
    DateTime? endDate,
    int? occurrenceCount,
    RecurrenceFromPolicy fromPolicy = RecurrenceFromPolicy.plannedDate,
  }) {
    return RecurrenceConfiguration._internal(
      frequency: frequency,
      interval: interval,
      daysOfWeek: daysOfWeek,
      weeklySchedule: weeklySchedule,
      monthlyPatternType: monthlyPatternType,
      dayOfMonth: dayOfMonth,
      weekOfMonth: weekOfMonth,
      dayOfWeek: dayOfWeek,
      monthOfYear: monthOfYear,
      endCondition: endCondition,
      endDate: endDate,
      occurrenceCount: occurrenceCount,
      fromPolicy: fromPolicy,
    );
  }

  /// Creates a safe default RecurrenceConfiguration for error recovery.
  /// This bypasses validation and is used when deserialization fails.
  /// Should only be used as a fallback when data corruption is detected.
  factory RecurrenceConfiguration.safeDefault() {
    return RecurrenceConfiguration._internal(
      frequency: RecurrenceFrequency.daily,
      interval: 1,
      endCondition: RecurrenceEndCondition.never,
      fromPolicy: RecurrenceFromPolicy.plannedDate,
    );
  }

  /// Private constructor that bypasses validation.
  RecurrenceConfiguration._internal({
    required this.frequency,
    required this.interval,
    this.daysOfWeek,
    this.weeklySchedule,
    this.monthlyPatternType,
    this.dayOfMonth,
    this.weekOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    required this.endCondition,
    this.endDate,
    this.occurrenceCount,
    required this.fromPolicy,
  });

  /// Creates a copy of this RecurrenceConfiguration with the given fields replaced.
  /// Any field not provided will retain its current value.
  ///
  /// The copy will be validated, so attempting to create an invalid configuration
  /// will throw an ArgumentError.
  RecurrenceConfiguration copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    List<int>? daysOfWeek,
    List<WeeklySchedule>? weeklySchedule,
    MonthlyPatternType? monthlyPatternType,
    int? dayOfMonth,
    int? weekOfMonth,
    int? dayOfWeek,
    int? monthOfYear,
    RecurrenceEndCondition? endCondition,
    DateTime? endDate,
    int? occurrenceCount,
    RecurrenceFromPolicy? fromPolicy,
  }) {
    return RecurrenceConfiguration(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      monthlyPatternType: monthlyPatternType ?? this.monthlyPatternType,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      weekOfMonth: weekOfMonth ?? this.weekOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      endCondition: endCondition ?? this.endCondition,
      endDate: endDate ?? this.endDate,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      fromPolicy: fromPolicy ?? this.fromPolicy,
    );
  }

  /// Validates configuration parameters and throws ArgumentError if invalid
  void _validate() {
    // Validate interval
    if (interval < RecurrenceConfigurationValidation.minInterval) {
      throw ArgumentError('Interval must be at least ${RecurrenceConfigurationValidation.minInterval}');
    }
    if (interval > RecurrenceConfigurationValidation.maxInterval) {
      throw ArgumentError('Interval cannot exceed ${RecurrenceConfigurationValidation.maxInterval}');
    }

    // Validate dayOfMonth
    if (dayOfMonth != null) {
      if (dayOfMonth! < RecurrenceConfigurationValidation.minDayOfMonth ||
          dayOfMonth! > RecurrenceConfigurationValidation.maxDayOfMonth) {
        throw ArgumentError(
            'dayOfMonth must be between ${RecurrenceConfigurationValidation.minDayOfMonth} and ${RecurrenceConfigurationValidation.maxDayOfMonth}');
      }
    }

    // Validate dayOfWeek
    if (dayOfWeek != null) {
      if (dayOfWeek! < RecurrenceConfigurationValidation.minDayOfWeek ||
          dayOfWeek! > RecurrenceConfigurationValidation.maxDayOfWeek) {
        throw ArgumentError(
            'dayOfWeek must be between ${RecurrenceConfigurationValidation.minDayOfWeek} and ${RecurrenceConfigurationValidation.maxDayOfWeek}');
      }
    }

    // Validate weekOfMonth
    if (weekOfMonth != null) {
      if (weekOfMonth! < RecurrenceConfigurationValidation.minWeekOfMonth ||
          weekOfMonth! > RecurrenceConfigurationValidation.maxWeekOfMonth) {
        throw ArgumentError(
            'weekOfMonth must be between ${RecurrenceConfigurationValidation.minWeekOfMonth} and ${RecurrenceConfigurationValidation.maxWeekOfMonth}');
      }
    }

    // Validate monthOfYear
    if (monthOfYear != null) {
      if (monthOfYear! < RecurrenceConfigurationValidation.minMonthOfYear ||
          monthOfYear! > RecurrenceConfigurationValidation.maxMonthOfYear) {
        throw ArgumentError(
            'monthOfYear must be between ${RecurrenceConfigurationValidation.minMonthOfYear} and ${RecurrenceConfigurationValidation.maxMonthOfYear}');
      }
    }

    // Validate occurrenceCount
    if (occurrenceCount != null) {
      if (occurrenceCount! <= 0 || occurrenceCount! > RecurrenceConfigurationValidation.maxOccurrenceCount) {
        throw ArgumentError(
            'occurrenceCount must be between 1 and ${RecurrenceConfigurationValidation.maxOccurrenceCount}');
      }
    }

    // Validate endDate is in the future if provided
    // Allow a 1-second tolerance to account for timing differences between date creation and validation
    // This ensures tests can use DateTime.now() as endDate without flaky failures
    // Use UTC to ensure consistent timezone handling
    if (endDate != null && endDate!.isBefore(DateTime.now().toUtc().subtract(const Duration(seconds: 1)))) {
      throw ArgumentError('endDate must be in the future or at the current time');
    }

    // Validate endCondition consistency
    if (endCondition == RecurrenceEndCondition.date && endDate == null) {
      throw ArgumentError('Date end condition requires endDate to be specified');
    }
    if (endCondition == RecurrenceEndCondition.count && occurrenceCount == null) {
      throw ArgumentError('Count end condition requires occurrenceCount to be specified');
    }

    // Validate daysOfWeek contains valid values
    if (daysOfWeek != null && daysOfWeek!.isNotEmpty) {
      for (final day in daysOfWeek!) {
        if (day < RecurrenceConfigurationValidation.minDayOfWeek ||
            day > RecurrenceConfigurationValidation.maxDayOfWeek) {
          throw ArgumentError(
              'daysOfWeek must contain values between ${RecurrenceConfigurationValidation.minDayOfWeek} and ${RecurrenceConfigurationValidation.maxDayOfWeek}');
        }
      }
    }

    // Validate weeklySchedule
    if (weeklySchedule != null && weeklySchedule!.isNotEmpty) {
      // Check for duplicate days
      final seenDays = <int>{};
      for (final schedule in weeklySchedule!) {
        // Validate dayOfWeek
        if (schedule.dayOfWeek < RecurrenceConfigurationValidation.minDayOfWeek ||
            schedule.dayOfWeek > RecurrenceConfigurationValidation.maxDayOfWeek) {
          throw ArgumentError(
              'weeklySchedule dayOfWeek must be between ${RecurrenceConfigurationValidation.minDayOfWeek} and ${RecurrenceConfigurationValidation.maxDayOfWeek}');
        }
        // Validate hour
        if (schedule.hour < RecurrenceConfigurationValidation.minHour ||
            schedule.hour > RecurrenceConfigurationValidation.maxHour) {
          throw ArgumentError(
              'weeklySchedule hour must be between ${RecurrenceConfigurationValidation.minHour} and ${RecurrenceConfigurationValidation.maxHour}');
        }
        // Validate minute
        if (schedule.minute < RecurrenceConfigurationValidation.minMinute ||
            schedule.minute > RecurrenceConfigurationValidation.maxMinute) {
          throw ArgumentError(
              'weeklySchedule minute must be between ${RecurrenceConfigurationValidation.minMinute} and ${RecurrenceConfigurationValidation.maxMinute}');
        }
        // Check for duplicate days
        if (seenDays.contains(schedule.dayOfWeek)) {
          throw ArgumentError('weeklySchedule cannot contain duplicate days');
        }
        seenDays.add(schedule.dayOfWeek);
      }
    }

    // Validate monthly pattern consistency
    if (monthlyPatternType != null) {
      if (monthlyPatternType == MonthlyPatternType.relativeDay) {
        if (weekOfMonth == null || dayOfWeek == null) {
          throw ArgumentError('Relative day pattern requires both weekOfMonth and dayOfWeek');
        }
      }
      if (monthlyPatternType == MonthlyPatternType.specificDay) {
        if (dayOfMonth == null) {
          throw ArgumentError('Specific day pattern requires dayOfMonth');
        }
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency.name,
      'interval': interval,
      'daysOfWeek': daysOfWeek,
      'weeklySchedule': weeklySchedule?.map((e) => e.toJson()).toList(),
      'monthlyPatternType': monthlyPatternType?.name,
      'dayOfMonth': dayOfMonth,
      'weekOfMonth': weekOfMonth,
      'dayOfWeek': dayOfWeek,
      'monthOfYear': monthOfYear,
      'endCondition': endCondition.name,
      'endDate': endDate?.toIso8601String(),
      'occurrenceCount': occurrenceCount,
      'fromPolicy': fromPolicy.name,
    };
  }

  /// Helper function to deserialize enum from both name (new) and index (old)
  static T _deserializeEnum<T extends Enum>(List<T> values, dynamic value, T defaultValue) {
    if (value == null) return defaultValue;

    // Try name first (new format)
    if (value is String) {
      try {
        return values.firstWhere((e) => e.name == value);
      } catch (_) {
        // Fall back to index if name lookup fails
      }
    }

    // Try index (old format) for backward compatibility
    if (value is int) {
      if (value >= 0 && value < values.length) {
        return values[value];
      }
    }

    return defaultValue;
  }

  /// Helper function to parse endDate with better error messages
  static DateTime? _parseEndDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value as String);
    } on FormatException {
      throw FormatException(
        'Invalid endDate format: "$value". Expected ISO8601 format (e.g., "2024-12-31T23:59:59Z")',
        value,
      );
    }
  }

  /// Deserializes a [RecurrenceConfiguration] from JSON.
  ///
  /// Uses the [_internal] constructor to bypass validation that would reject
  /// recurrence end dates in the past. This is intentional to allow proper
  /// deserialization of historical tasks during sync - tasks that were created
  /// in the past may have recurrence configurations with end dates that are now
  /// in the past, and these should still be valid for historical data integrity.
  factory RecurrenceConfiguration.fromJson(Map<String, dynamic> json) {
    return RecurrenceConfiguration._internal(
      frequency: _deserializeEnum(RecurrenceFrequency.values, json['frequency'], RecurrenceFrequency.daily),
      interval: json['interval'] as int? ?? 1,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.map((e) => e as int).toList(),
      weeklySchedule: (json['weeklySchedule'] as List<dynamic>?)
          ?.map((e) => WeeklySchedule.fromJson(e as Map<String, dynamic>))
          .toList(),
      monthlyPatternType: json['monthlyPatternType'] != null
          ? _deserializeEnum(MonthlyPatternType.values, json['monthlyPatternType'], MonthlyPatternType.specificDay)
          : null,
      dayOfMonth: json['dayOfMonth'] as int?,
      weekOfMonth: json['weekOfMonth'] as int?,
      dayOfWeek: json['dayOfWeek'] as int?,
      monthOfYear: json['monthOfYear'] as int?,
      endCondition: _deserializeEnum(RecurrenceEndCondition.values, json['endCondition'], RecurrenceEndCondition.never),
      endDate: _parseEndDate(json['endDate']),
      occurrenceCount: json['occurrenceCount'] as int?,
      fromPolicy: _deserializeEnum(RecurrenceFromPolicy.values, json['fromPolicy'], RecurrenceFromPolicy.plannedDate),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RecurrenceConfiguration) return false;

    bool listEquals<T>(List<T>? a, List<T>? b) {
      if (a == null) return b == null;
      if (b == null || a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    return other.frequency == frequency &&
        other.interval == interval &&
        listEquals(other.daysOfWeek, daysOfWeek) &&
        listEquals(other.weeklySchedule, weeklySchedule) &&
        other.monthlyPatternType == monthlyPatternType &&
        other.dayOfMonth == dayOfMonth &&
        other.weekOfMonth == weekOfMonth &&
        other.dayOfWeek == dayOfWeek &&
        other.monthOfYear == monthOfYear &&
        other.endCondition == endCondition &&
        other.endDate == endDate &&
        other.occurrenceCount == occurrenceCount &&
        other.fromPolicy == fromPolicy;
  }

  @override
  int get hashCode {
    return Object.hash(
      frequency,
      interval,
      Object.hashAll(daysOfWeek ?? []),
      Object.hashAll(weeklySchedule ?? []),
      monthlyPatternType,
      dayOfMonth,
      weekOfMonth,
      dayOfWeek,
      monthOfYear,
      endCondition,
      endDate,
      occurrenceCount,
      fromPolicy,
    );
  }
}
