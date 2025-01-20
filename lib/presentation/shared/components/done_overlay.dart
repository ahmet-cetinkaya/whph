import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class DoneOverlay extends StatelessWidget {
  const DoneOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: const Center(
          child: Icon(
        Icons.done_all,
        size: 100,
        color: AppTheme.surface3,
      )),
    );
  }
}
