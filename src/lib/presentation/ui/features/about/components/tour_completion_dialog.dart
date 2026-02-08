import 'package:flutter/material.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class TourCompletionDialog extends StatelessWidget {
  const TourCompletionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final isSmallScreen = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      backgroundColor: AppTheme.surface1,
      insetPadding: isSmallScreen ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      shape: isSmallScreen ? const RoundedRectangleBorder() : null,
      child: SafeArea(
        left: isSmallScreen,
        top: isSmallScreen,
        right: isSmallScreen,
        bottom: isSmallScreen,
        child: Container(
          width: isSmallScreen ? double.infinity : MediaQuery.sizeOf(context).width * 0.8,
          height: isSmallScreen ? double.infinity : null,
          constraints: isSmallScreen ? null : const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: isSmallScreen ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: isSmallScreen ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (isSmallScreen) const Spacer(),
              Image.asset(
                AppAssets.logo,
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 32),
              Text(
                translationService.translate(SharedTranslationKeys.tourFinishTitle),
                style: AppTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                translationService.translate(SharedTranslationKeys.tourFinishBody),
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (isSmallScreen) const Spacer(),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(translationService.translate(SharedTranslationKeys.doneButton)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
