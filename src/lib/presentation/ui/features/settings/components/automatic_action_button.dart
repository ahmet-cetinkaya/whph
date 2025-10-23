import 'package:flutter/material.dart';

class AutomaticActionButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;

  const AutomaticActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  State<AutomaticActionButton> createState() => _AutomaticActionButtonState();
}

class _AutomaticActionButtonState extends State<AutomaticActionButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return _isLoading
        ? FilledButton.icon(
            onPressed: null,
            icon: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.white70 : Colors.white,
                ),
              ),
            ),
            style: FilledButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 36),
              backgroundColor: Colors.green,
            ),
            label: Text(widget.label),
          )
        : FilledButton.icon(
            onPressed: _handlePressed,
            icon: const Icon(Icons.play_arrow),
            style: FilledButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 36),
              backgroundColor: Colors.green,
            ),
            label: Text(widget.label),
          );
  }

  Future<void> _handlePressed() async {
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
