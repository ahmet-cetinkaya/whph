import 'package:flutter/material.dart';

class DateTimePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(DateTime) onConfirm;

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
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    // Guard against context usage after async gap
    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(DateTime.now()),
      );

      // Guard against context usage after async gap
      if (pickedTime != null && context.mounted) {
        final DateTime pickedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        controller.text = pickedDateTime.toString();
        onConfirm(pickedDateTime); // Trigger the callback when the date and time are confirmed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _selectDateTime(context),
      decoration: InputDecoration(
        hintText: hintText,
      ),
    );
  }
}
