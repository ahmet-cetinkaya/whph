import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // To format the date and time

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

        controller.text = formattedDateTime; // Update the controller with formatted date & time
        onConfirm(pickedDateTime); // Trigger the callback
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
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero),
    );
  }
}
