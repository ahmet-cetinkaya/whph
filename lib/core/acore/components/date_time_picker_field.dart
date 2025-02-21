import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class DateTimePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(DateTime?) onConfirm;
  final DateTime? minDateTime;
  final DateTime? maxDateTime;

  const DateTimePickerField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onConfirm,
    this.minDateTime,
    this.maxDateTime,
  });

  Future<void> _selectDateTime(BuildContext context) async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? now,
      firstDate: minDateTime ?? DateTime(1980),
      lastDate: maxDateTime ?? DateTime(2101),
    );

    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(DateTime.tryParse(controller.text) ?? now),
      );

      if (pickedTime != null && context.mounted) {
        final DateTime pickedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if ((minDateTime != null && pickedDateTime.isBefore(minDateTime!)) ||
            (maxDateTime != null && pickedDateTime.isAfter(maxDateTime!))) {
          return;
        }

        final String formattedDateTime = DateFormat('yyyy-MM-dd HH:mm').format(pickedDateTime);
        controller.text = formattedDateTime;
        onConfirm(pickedDateTime);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: AppTheme.bodySmall,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTheme.bodySmall,
        suffixIcon: const Icon(Icons.edit, size: AppTheme.iconSizeSmall),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onTap: () async {
        await _selectDateTime(context);
      },
    );
  }
}
