import 'package:flutter/material.dart';

class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const LoadMoreButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: const Text(
        'Load More',
        style: TextStyle(fontSize: 14),
      ),
    );
  }
}
