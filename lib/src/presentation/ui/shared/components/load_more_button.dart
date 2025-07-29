import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';

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
    final isSmallScreen = AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);
    final buttonText = _translationService.translate(SharedTranslationKeys.loadMoreButton);

    // For very small screens, use a more compact layout
    if (isSmallScreen) {
      return TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sizeSmall,
            vertical: AppTheme.size3XSmall,
          ),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: _isLoading
            ? null
            : () async {
                await AsyncErrorHandler.executeWithLoading(
                  context: context,
                  setLoading: (loading) => setState(() => _isLoading = loading),
                  operation: widget.onPressed,
                );
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.expand_more,
              size: AppTheme.iconSizeSmall,
            ),
            const SizedBox(width: AppTheme.size3XSmall),
            Flexible(
              child: Text(
                buttonText,
                style: const TextStyle(fontSize: AppTheme.fontSizeSmall),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }

    // For larger screens, use the original layout
    return TextButton.icon(
      icon: const Icon(Icons.expand_more),
      label: Text(buttonText),
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
