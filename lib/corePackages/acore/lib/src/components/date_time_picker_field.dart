import 'package:flutter/material.dart';
import '../time/date_format_service.dart';

class DateTimePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final void Function(DateTime?) onConfirm;
  final DateTime? minDateTime;
  final DateTime? maxDateTime;
  final bool showClearButton;
  final String? clearButtonTooltip;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
  final InputDecoration? decoration;
  final double? iconSize;
  final Color? iconColor;

  const DateTimePickerField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onConfirm,
    this.minDateTime,
    this.maxDateTime,
    this.showClearButton = true,
    this.clearButtonTooltip,
    this.textStyle,
    this.hintStyle,
    this.decoration,
    this.iconSize,
    this.iconColor,
  });

  // Helper method to normalize DateTime to minute precision (ignoring seconds and milliseconds)
  DateTime _normalizeToMinute(DateTime dateTime) {
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    );
  }

  // Helper method to compare dates ignoring seconds and milliseconds
  bool _isBeforeIgnoringSeconds(DateTime date1, DateTime date2) {
    final normalized1 = _normalizeToMinute(date1);
    final normalized2 = _normalizeToMinute(date2);
    return normalized1.isBefore(normalized2);
  }

  bool _isAfterIgnoringSeconds(DateTime date1, DateTime date2) {
    final normalized1 = _normalizeToMinute(date1);
    final normalized2 = _normalizeToMinute(date2);
    return normalized1.isAfter(normalized2);
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final now = DateTime.now();

    // Parse the current date from the controller or use now
    DateTime initialDate;

    try {
      if (controller.text.isNotEmpty) {
        final parsedDate = DateTime.tryParse(controller.text);
        initialDate = parsedDate ?? now;
      } else {
        initialDate = now;
      }
    } catch (e) {
      initialDate = now;
    }

    // Ensure initialDate is not before minDateTime
    if (minDateTime != null && _isBeforeIgnoringSeconds(initialDate, minDateTime!)) {
      initialDate = minDateTime!;
    }

    // Ensure initialDate is not after maxDateTime
    if (maxDateTime != null && _isAfterIgnoringSeconds(initialDate, maxDateTime!)) {
      initialDate = maxDateTime!;
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDateTime ?? DateTime(1980),
      lastDate: maxDateTime ?? DateTime(2101),
    );

    if (pickedDate != null && context.mounted) {
      // Get current time from controller or use now
      DateTime currentDateTime = DateTime.tryParse(controller.text) ?? now;

      // If the current date is invalid, use the picked date with current time
      if (currentDateTime.year < 2000) {
        currentDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          now.hour,
          now.minute,
        );
      }

      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentDateTime),
      );

      if (pickedTime != null && context.mounted) {
        final DateTime pickedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if ((minDateTime != null && _isBeforeIgnoringSeconds(pickedDateTime, minDateTime!)) ||
            (maxDateTime != null && _isAfterIgnoringSeconds(pickedDateTime, maxDateTime!))) {
          return;
        }

        // Format the date for display using centralized service
        final String formattedDateTime = DateFormatService.formatForInput(
          pickedDateTime,
          context,
          type: DateFormatType.dateTime,
        );
        controller.text = formattedDateTime;

        // Call the callback with the selected date in local timezone
        onConfirm(pickedDateTime);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextStyle = textStyle ?? theme.textTheme.bodyMedium;
    final effectiveHintStyle = hintStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
        );
    final effectiveIconSize = iconSize ?? 16.0;
    final effectiveIconColor = iconColor ?? theme.iconTheme.color?.withValues(alpha: 0.7);

    return TextFormField(
      controller: controller,
      readOnly: true,
      style: effectiveTextStyle,
      decoration: decoration?.copyWith(
            hintText: hintText,
            hintStyle: effectiveHintStyle,
            suffixIcon: _buildSuffixIcons(context, effectiveIconSize, effectiveIconColor),
          ) ??
          InputDecoration(
            hintText: hintText,
            hintStyle: effectiveHintStyle,
            suffixIcon: _buildSuffixIcons(context, effectiveIconSize, effectiveIconColor),
            isDense: true,
            contentPadding: const EdgeInsets.all(0),
          ),
      onTap: () async {
        await _selectDateTime(context);
      },
    );
  }

  Widget _buildSuffixIcons(BuildContext context, double iconSize, Color? iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Clear button
        if (showClearButton && controller.text.isNotEmpty)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                controller.clear();
                onConfirm(null);
              },
              child: Tooltip(
                message: clearButtonTooltip,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.clear,
                    size: iconSize,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        // Edit button
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              await _selectDateTime(context);
            },
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.edit,
                size: iconSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
