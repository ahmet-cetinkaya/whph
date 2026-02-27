import 'package:flutter/material.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/utils/task_date_time_normalizer.dart';

/// Presentation helper for rendering task dates with all-day semantics.
class TaskDateDisplayHelper {
  TaskDateDisplayHelper._();

  static String formatForInput(DateTime? value, BuildContext context) {
    if (value == null) return '';
    final formatType = TaskDateTimeNormalizer.isAllDay(value) ? DateFormatType.date : DateFormatType.dateTime;
    return DateFormatService.formatForInput(value, context, type: formatType);
  }
}
