import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:acore/utils/color_contrast_helper.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

/// Navigation buttons for the tour overlay (Skip, Previous, Next/Finish).
class TourNavigationButtons extends StatelessWidget {
  final bool isFirstStep;
  final bool isLastStep;
  final bool isFinalPageOfTour;
  final bool showBackButton;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Future<void> Function() onSkip;
  final VoidCallback? onBack;
  final ITranslationService translationService;

  const TourNavigationButtons({
    super.key,
    required this.isFirstStep,
    required this.isLastStep,
    required this.isFinalPageOfTour,
    required this.showBackButton,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    this.onBack,
    required this.translationService,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + AppTheme.sizeMedium,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSkipButton(),
              const SizedBox(height: AppTheme.sizeSmall),
              _buildPrevNextRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton.icon(
        onPressed: () async => await onSkip(),
        icon: const Icon(Icons.close, size: 18),
        label: Text(translationService.translate(SharedTranslationKeys.skipTour)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sizeMedium,
            vertical: AppTheme.sizeSmall,
          ),
          backgroundColor: AppTheme.surface1.withValues(alpha: 0.9),
          foregroundColor: AppTheme.primaryColor,
          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  Widget _buildPrevNextRow() {
    return Row(
      children: [
        Expanded(child: _buildPreviousButton()),
        const SizedBox(width: AppTheme.sizeXSmall),
        Expanded(child: _buildNextButton()),
      ],
    );
  }

  Widget _buildPreviousButton() {
    final isDisabled = isFirstStep && !(showBackButton && onBack != null);
    final buttonAction = _getPreviousButtonAction();
    final buttonText = _getPreviousButtonText();

    return OutlinedButton(
      onPressed: buttonAction,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.sizeMedium,
          horizontal: AppTheme.sizeSmall,
        ),
        backgroundColor: AppTheme.surface1,
        foregroundColor: AppTheme.primaryColor,
        side: BorderSide(
          color:
              isDisabled ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.arrow_back,
            size: 18,
            color: isDisabled ? AppTheme.primaryColor.withValues(alpha: 0.3) : null,
          ),
          const SizedBox(height: AppTheme.size4XSmall),
          Text(
            buttonText,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: isDisabled ? AppTheme.primaryColor.withValues(alpha: 0.3) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return FilledButton(
      onPressed: onNext,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.sizeMedium,
          horizontal: AppTheme.sizeSmall,
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: ColorContrastHelper.getContrastingTextColor(AppTheme.primaryColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            (isLastStep && isFinalPageOfTour) ? Icons.check : Icons.arrow_forward,
            size: 18,
          ),
          const SizedBox(height: AppTheme.size4XSmall),
          Text(
            (isLastStep && isFinalPageOfTour) ? 'Finish' : 'Next',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  VoidCallback? _getPreviousButtonAction() {
    if (isFirstStep && showBackButton && onBack != null) return onBack;
    if (!isFirstStep) return onPrevious;
    return null;
  }

  String _getPreviousButtonText() {
    if (isFirstStep && showBackButton && onBack != null) {
      return translationService.translate(SharedTranslationKeys.backButton);
    }
    return translationService.translate(SharedTranslationKeys.previousButton);
  }
}
