import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class DateTimePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(DateTime?) onConfirm;

  const DateTimePickerField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onConfirm,
  });

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(DateTime.now()),
      );

      if (pickedTime != null && context.mounted) {
        final DateTime pickedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Format the selected DateTime for better readability
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
