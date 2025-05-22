import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
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
  final _translationService = container.resolve<ITranslationService>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.expand_more),
      label: Text(_translationService.translate(SharedTranslationKeys.loadMoreButton)),
      onPressed: _isLoading
          ? null
          : () async {
              await AsyncErrorHandler.executeWithLoading(
                context: context,
                setLoading: (loading) => setState(() => _isLoading = loading),
                operation: widget.onPressed,
              );
            },
    );
  }
}
