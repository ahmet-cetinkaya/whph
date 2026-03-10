import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';

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
            horizontal: AppTheme.sizeMedium,
            vertical: AppTheme.sizeSmall,
          ),
          minimumSize: const Size(double.infinity, AppTheme.buttonSizeXLarge),
          tapTargetSize: MaterialTapTargetSize.padded,
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
            if (_isLoading)
              SizedBox(
                width: AppTheme.iconSizeMedium,
                height: AppTheme.iconSizeMedium,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.expand_more,
                size: AppTheme.iconSizeMedium,
              ),
            const SizedBox(width: AppTheme.size3XSmall),
            Flexible(
              child: Text(
                buttonText,
                style: const TextStyle(fontSize: AppTheme.fontSizeMedium),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }

    // For larger screens, use a more compact layout
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sizeSmall,
          vertical: AppTheme.size2XSmall,
        ),
        minimumSize: const Size(double.infinity, AppTheme.buttonSizeXLarge),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: _isLoading
          ? SizedBox(
              width: AppTheme.iconSizeXSmall,
              height: AppTheme.iconSizeXSmall,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.expand_more,
              size: AppTheme.iconSizeXSmall,
            ),
      label: Text(
        buttonText,
        style: const TextStyle(fontSize: AppTheme.fontSizeXSmall),
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
    );
  }
}
