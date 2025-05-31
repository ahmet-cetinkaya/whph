import 'package:flutter/material.dart';

class NumericInput extends StatefulWidget {
  final int initialValue;
  final int? minValue;
  final int? maxValue;
  final int incrementValue;
  final int decrementValue;
  final void Function(int) onValueChanged;
  final String? decrementTooltip;
  final String? incrementTooltip;
  final String? valueSuffix;
  final double? iconSize;
  final Color? iconColor;

  const NumericInput({
    super.key,
    this.initialValue = 0,
    this.minValue,
    this.maxValue,
    this.incrementValue = 1,
    this.decrementValue = 1,
    required this.onValueChanged,
    this.decrementTooltip,
    this.incrementTooltip,
    this.valueSuffix,
    this.iconSize,
    this.iconColor,
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
    final maxValue = widget.maxValue;
    if (maxValue != null && nextValue > maxValue) {
      nextValue = maxValue;
    }

    if (mounted) {
      setState(() {
        _controller.value = TextEditingValue(text: nextValue.toString());
      });
    }
    widget.onValueChanged(nextValue);
  }

  void _decrement() {
    int? value = int.tryParse(_controller.text);
    if (value == null) return;

    int nextValue = value - widget.decrementValue;
    final minValue = widget.minValue;
    if (minValue != null && nextValue < minValue) {
      nextValue = minValue;
    }

    if (mounted) {
      setState(() {
        _controller.value = TextEditingValue(text: nextValue.toString());
      });
    }
    widget.onValueChanged(nextValue);
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = int.tryParse(_controller.text) ?? 0;
    final minValue = widget.minValue;
    final maxValue = widget.maxValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.remove,
            size: widget.iconSize,
            color: widget.iconColor,
          ),
          onPressed: minValue == null || currentValue > minValue ? _decrement : null,
          tooltip: widget.decrementTooltip ?? 'Decrease',
        ),
        SizedBox(
          width: _controller.text.length * 10.0, // Adjust width based on text length
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(0),
              isDense: true,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            onChanged: (value) {
              int? newValue = int.tryParse(value);
              if (newValue == null) return;

              final minValue = widget.minValue;
              final maxValue = widget.maxValue;

              if (minValue != null && newValue < minValue) {
                _controller.value = TextEditingValue(text: minValue.toString());
                newValue = minValue;
              }
              if (maxValue != null && newValue > maxValue) {
                _controller.value = TextEditingValue(text: maxValue.toString());
                newValue = maxValue;
              }

              widget.onValueChanged(newValue);
            },
          ),
        ),
        if (widget.valueSuffix != null)
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                widget.valueSuffix!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1,
                    ),
              ),
            ),
          ),
        IconButton(
          icon: Icon(
            Icons.add,
            size: widget.iconSize,
            color: widget.iconColor,
          ),
          onPressed: maxValue == null || currentValue < maxValue ? _increment : null,
          tooltip: widget.incrementTooltip ?? 'Increase',
        ),
      ],
    );
  }
}
