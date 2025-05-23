import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';

/// A reusable save button component
class SaveButton extends StatelessWidget {
  /// Function to call when save button is pressed
  final VoidCallback onSave;

  /// Tooltip text to show on hover
  final String tooltip;

  /// Constructor
  const SaveButton({
    super.key,
    required this.onSave,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: const Icon(Icons.save_outlined),
        iconSize: AppTheme.iconSizeMedium,
        color: Theme.of(context).primaryColor,
        onPressed: onSave,
      ),
    );
  }
}
