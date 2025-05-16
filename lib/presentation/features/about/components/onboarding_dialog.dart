import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/domain/features/settings/constants/setting_keys.dart';
import 'package:whph/domain/features/settings/setting.dart';
import 'package:whph/domain/shared/constants/app_assets.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/about/constants/about_translation_keys.dart';
import 'package:whph/presentation/features/settings/pages/permissions_page.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final _translationService = container.resolve<ITranslationService>();
  final _mediator = container.resolve<Mediator>();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<_OnboardingStep> get _steps {
    final baseSteps = [
      _OnboardingStep(
        icon: Icons.waving_hand,
        titleKey: AboutTranslationKeys.onboardingTitle1,
        descriptionKey: AboutTranslationKeys.onboardingDescription1,
      ),
      _OnboardingStep(
        icon: Icons.check_circle_outline,
        titleKey: AboutTranslationKeys.onboardingTitle2,
        descriptionKey: AboutTranslationKeys.onboardingDescription2,
      ),
      _OnboardingStep(
        icon: Icons.refresh,
        titleKey: AboutTranslationKeys.onboardingTitle3,
        descriptionKey: AboutTranslationKeys.onboardingDescription3,
      ),
      _OnboardingStep(
        icon: Icons.note_alt_outlined,
        titleKey: AboutTranslationKeys.onboardingTitle4,
        descriptionKey: AboutTranslationKeys.onboardingDescription4,
      ),
      _OnboardingStep(
        icon: Icons.bar_chart,
        titleKey: AboutTranslationKeys.onboardingTitle5,
        descriptionKey: AboutTranslationKeys.onboardingDescription5,
      ),
      _OnboardingStep(
        icon: Icons.label,
        titleKey: AboutTranslationKeys.onboardingTitle6,
        descriptionKey: AboutTranslationKeys.onboardingDescription6,
      ),
    ];

    // Add permissions step only on Android
    if (Platform.isAndroid) {
      baseSteps.add(
        _OnboardingStep(
          icon: Icons.security,
          titleKey: AboutTranslationKeys.onboardingTitle7,
          descriptionKey: AboutTranslationKeys.onboardingDescription7,
          extraWidget: (context) => Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                ResponsiveDialogHelper.showResponsiveDialog(
                  context: context,
                  child: const PermissionsPage(),
                );
              },
              icon: const Icon(Icons.lock_open),
              label: Text(_translationService.translate(AboutTranslationKeys.onboardingPermissionsButton)),
            ),
          ),
        ),
      );
    }

    // Add final motivation step
    baseSteps.add(
      _OnboardingStep(
        imageAsset: AppAssets.logo,
        titleKey: AboutTranslationKeys.onboardingTitle8,
        descriptionKey: AboutTranslationKeys.onboardingDescription8,
      ),
    );

    return baseSteps;
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.onboardingCompleted,
      value: 'true',
      valueType: SettingValueType.bool,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface1,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 320,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (step.imageAsset != null)
                        Image.asset(
                          step.imageAsset!,
                          width: 64,
                          height: 64,
                        )
                      else
                        Icon(
                          step.icon,
                          size: 64,
                          color: AppTheme.primaryColor,
                        ),
                      const SizedBox(height: 24),
                      Text(
                        _translationService.translate(step.titleKey),
                        style: AppTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _translationService.translate(step.descriptionKey),
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (step.extraWidget != null) step.extraWidget!(context),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Progress indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _previousPage,
                    child: Text(_translationService.translate(AboutTranslationKeys.onboardingButtonBack)),
                  )
                else
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(_translationService.translate(AboutTranslationKeys.onboardingButtonSkip)),
                  ),
                FilledButton(
                  onPressed: _nextPage,
                  child: Text(
                    _translationService.translate(
                      _currentPage == _steps.length - 1
                          ? AboutTranslationKeys.onboardingButtonStart
                          : AboutTranslationKeys.onboardingButtonNext,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingStep {
  final IconData? icon;
  final String? imageAsset;
  final String titleKey;
  final String descriptionKey;
  final Widget Function(BuildContext)? extraWidget;

  const _OnboardingStep({
    this.icon,
    this.imageAsset,
    required this.titleKey,
    required this.descriptionKey,
    this.extraWidget,
  }) : assert(icon != null || imageAsset != null, 'Either icon or imageAsset must be provided');
}
