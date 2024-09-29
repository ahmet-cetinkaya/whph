import 'package:flutter/material.dart';
import 'dart:math';

class BarChartComponent extends StatelessWidget {
  final String title;
  final double value;
  final double maxValue; // Max value for scaling
  final Color? barColor;
  final String unit;

  final List<Color> _pastelColors = [
    const Color(0xFFB6E3E9), // Light Blue
    const Color(0xFFFFC2C2), // Light Pink
    const Color(0xFFFFE7C2), // Light Orange
    const Color(0xFFC2FFC2), // Light Green
    const Color(0xFFD1C2FF), // Light Purple
    const Color(0xFFFFF5C2), // Light Yellow
    const Color(0xFFE9C2FF), // Soft Lavender
    const Color(0xFFFFD9C2), // Soft Peach
    const Color(0xFFC2FFF5), // Light Aqua
    const Color(0xFFC2E0FF), // Soft Sky Blue
    const Color(0xFFFFF2C2), // Soft Banana
    const Color(0xFFC2FFC2), // Light Lime Green
    const Color(0xFFC2C2FF), // Soft Periwinkle
  ];

  BarChartComponent({
    super.key,
    required this.title,
    required this.value,
    required this.maxValue,
    this.barColor, // Opsiyonel renk
    this.unit = "",
  });

  @override
  Widget build(BuildContext context) {
    Color finalBarColor = barColor ?? _pastelColors[Random().nextInt(_pastelColors.length)];
    double barWidth = (MediaQuery.of(context).size.width - 100) * (value / maxValue);

    return ListTile(
      title: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          // Bar
          Container(
            height: 50,
            width: barWidth,
            decoration: BoxDecoration(
              color: finalBarColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Positioned(
            left: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Label
                Text('${value.toStringAsFixed(1)} $unit'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
