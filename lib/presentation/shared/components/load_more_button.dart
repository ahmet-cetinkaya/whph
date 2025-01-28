import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import '../constants/shared_translation_keys.dart';

class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  final _translationService = container.resolve<ITranslationService>();

  LoadMoreButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        _translationService.translate(SharedTranslationKeys.loadMoreButton),
        style: AppTheme.bodySmall,
      ),
    );
  }
}
