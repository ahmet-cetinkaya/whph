import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final String text;
  final int level;

  const Header({
    super.key,
    required this.text,
    this.level = 1,
  }) : assert(level >= 1 && level <= 6, 'Header level must be between 1 and 6');

  @override
  Widget build(BuildContext context) {
    double fontSize;
    FontWeight fontWeight;

    switch (level) {
      case 2:
        fontSize = 28;
        fontWeight = FontWeight.bold;
        break;
      case 3:
        fontSize = 24;
        fontWeight = FontWeight.bold;
        break;
      case 4:
        fontSize = 20;
        fontWeight = FontWeight.w600;
        break;
      case 5:
        fontSize = 16;
        fontWeight = FontWeight.w600;
        break;
      case 6:
        fontSize = 14;
        fontWeight = FontWeight.w600;
        break;
      default: // 1
        fontSize = 32;
        fontWeight = FontWeight.bold;
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}
