import 'package:flutter/material.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/utils/task_date_time_normalizer.dart';

/// Presentation helper for rendering task dates with all-day semantics.
class TaskDateDisplayHelper {
  TaskDateDisplayHelper._();

  /// Formats a DateTime for display in input fields.
  ///
  /// Automatically selects appropriate format based on all-day detection:
  /// - Date-only format for all-day values (00:00:00.000000 local time)
  /// - Date-time format for values with explicit times
  ///
  /// Returns empty string if value is null.
  ///
  /// See [TaskDateTimeNormalizer.isAllDay] for all-day detection logic.
  static String formatForInput(DateTime? value, BuildContext context) {
    if (value == null) return '';
    final formatType = TaskDateTimeNormalizer.isAllDay(value) ? DateFormatType.date : DateFormatType.dateTime;
    return DateFormatService.formatForInput(value, context, type: formatType);
  }
}
