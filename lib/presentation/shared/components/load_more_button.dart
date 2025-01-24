import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const LoadMoreButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        'Load More',
        style: AppTheme.bodySmall,
      ),
    );
  }
}
