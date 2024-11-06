import 'package:flutter/material.dart';

class NumericInput extends StatefulWidget {
  final int initialValue;
  final int minValue;
  final int maxValue;
  final int incrementValue;
  final int decrementValue;
  final void Function(int) onValueChanged;

  const NumericInput({
    super.key,
    this.initialValue = 0,
    this.minValue = 0,
    this.maxValue = 100,
    this.incrementValue = 1,
    this.decrementValue = 1,
    required this.onValueChanged,
  });

  @override
  State<NumericInput> createState() => _NumericInputState();
}

class _NumericInputState extends State<NumericInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  void _increment() {
    int? value = int.tryParse(_controller.text);
    if (value == null) return;

    int nextValue = value + widget.incrementValue;
    if (mounted) {
      setState(() {
        _controller.value =
            TextEditingValue(text: (nextValue <= widget.maxValue ? nextValue : widget.maxValue).toString());
      });
    }
    widget.onValueChanged(nextValue);
  }

  void _decrement() {
    int? value = int.tryParse(_controller.text);
    if (value == null) return;

    int nextValue = value - widget.decrementValue;
    if (mounted) {
      setState(() {
        _controller.value =
            TextEditingValue(text: (nextValue >= widget.minValue ? nextValue : widget.minValue).toString());
      });
    }
    widget.onValueChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: (int.tryParse(_controller.text) ?? 0) > widget.minValue ? _decrement : null,
          tooltip: 'Decrease',
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 12.0),
            ),
            onChanged: (value) {
              int? newValue = int.tryParse(value);
              if (newValue == null) return;
              if (newValue < widget.minValue) {
                _controller.value = TextEditingValue(text: widget.minValue.toString());
                newValue = widget.minValue;
              }
              if (newValue > widget.maxValue) {
                _controller.value = TextEditingValue(text: widget.maxValue.toString());
                newValue = widget.maxValue;
              }

              widget.onValueChanged(newValue);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: (int.tryParse(_controller.text) ?? 0) < widget.maxValue ? _increment : null,
          tooltip: 'Increase',
        ),
      ],
    );
  }
}
