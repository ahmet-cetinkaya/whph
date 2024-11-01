import 'package:flutter/material.dart';
import 'package:whph/domain/features/shared/constants/app_theme.dart';

class ColorPreview extends StatelessWidget {
  final Color color;

  const ColorPreview({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surface3),
      ),
    );
  }
}
