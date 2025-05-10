import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';

class LoadMoreButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  const LoadMoreButton({
    super.key,
    required this.onPressed,
  });

  @override
  State<LoadMoreButton> createState() => _LoadMoreButtonState();
}

class _LoadMoreButtonState extends State<LoadMoreButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _isLoading
          ? null
          : () async {
              await AsyncErrorHandler.executeWithLoading(
                context: context,
                setLoading: (loading) => setState(() => _isLoading = loading),
                operation: widget.onPressed,
              );
            },
      child: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
    );
  }
}
