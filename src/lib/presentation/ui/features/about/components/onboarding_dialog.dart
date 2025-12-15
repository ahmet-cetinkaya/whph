// ignore: unused_import
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:acore/acore.dart' show PlatformUtils;
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/shared/constants/app_assets.dart';
import 'package:whph/core/domain/shared/constants/app_info.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/about/constants/about_translation_keys.dart';
import 'package:whph/presentation/ui/features/settings/pages/permissions_page.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/language_dropdown.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  final _mediator = container.resolve<Mediator>();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedLanguageCode;
  late List<_OnboardingStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
  }

  List<_OnboardingStep> _buildSteps() {
    final baseSteps = [
      // Welcome
      _OnboardingStep(
        icon: Icons.waving_hand,
        titleKey: AboutTranslationKeys.onboardingTitle1,
        descriptionKey: AboutTranslationKeys.onboardingDescription1,
        extraWidget: (context) => LanguageDropdown(
          initialLanguageCode: _selectedLanguageCode,
          onLanguageChanged: _onLanguageChanged,
          showPlaceholder: true,
        ),
      ),
      // Work Hard Play Hard Motto
      _OnboardingStep(
        icon: Icons.balance,
        titleKey: AboutTranslationKeys.onboardingTitle2,
        descriptionKey: AboutTranslationKeys.onboardingDescription2,
      ),
    ];

    // Permissions intro (only on Android)
    if (PlatformUtils.isMobile) {
      baseSteps.add(
        _OnboardingStep(
          icon: Icons.security,
          titleKey: AboutTranslationKeys.onboardingTitle7,
          descriptionKey: AboutTranslationKeys.onboardingDescription7,
          extraWidget: (context) => OutlinedButton.icon(
            onPressed: () => _showPermissionsPage(context),
            icon: const Icon(Icons.lock_open),
            label: Text(_translationService.translate(AboutTranslationKeys.onboardingPermissionsButton)),
          ),
        ),
      );
    }

    // Final motivation intro
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

  Future<void> _startTour() async {
    // Complete onboarding first
    await _completeOnboarding();
    // Start the multi-page tour after dialog is fully closed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TourNavigationService.startMultiPageTour(context);
    });
  }

  Future<void> _skipTour() async {
    // Mark tour as skipped
    await TourNavigationService.skipMultiPageTour();
    // Complete onboarding without starting tour
    _completeOnboarding();
  }

  void _showPermissionsPage(BuildContext context) {
    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const PermissionsPage(),
      size: DialogSize.large,
    );
  }

  Future<void> _onLanguageChanged(String languageCode) async {
    _selectedLanguageCode = languageCode;
    await _translationService.changeLanguageWithoutNavigation(context, languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface1,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.8,
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
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
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
                              color: _themeService.primaryColor,
                            ),
                          const SizedBox(height: 24),
                          Text(
                            _translationService.translate(
                              step.titleKey,
                              namedArgs: step.titleKey == AboutTranslationKeys.onboardingTitle1
                                  ? {'appName': AppInfo.name}
                                  : null,
                            ),
                            style: AppTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _translationService.translate(
                              step.descriptionKey,
                              namedArgs: step.descriptionKey == AboutTranslationKeys.onboardingDescription7
                                  ? {'appName': AppInfo.name}
                                  : null,
                            ),
                            style: AppTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (step.extraWidget != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppTheme.size2XLarge),
                              child: SizedBox(
                                width: double.infinity,
                                child: step.extraWidget!(context),
                              ),
                            ),
                        ],
                      ),
                    ),
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
                    color: _currentPage == index
                        ? _themeService.primaryColor
                        : _themeService.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Different button layout for the last step
            if (_currentPage == _steps.length - 1)
              Row(
                children: [
                  // Skip Tour button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _skipTour,
                      child: Text(_translationService.translate(SharedTranslationKeys.skipTour)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Start Tour button
                  Expanded(
                    child: FilledButton(
                      onPressed: _startTour,
                      child: Text(_translationService.translate(SharedTranslationKeys.startTour)),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  // Back button
                  if (_currentPage > 0)
                    Expanded(
                      child: TextButton(
                        onPressed: _previousPage,
                        child: Text(_translationService.translate(AboutTranslationKeys.onboardingButtonBack)),
                      ),
                    )
                  else
                    const Spacer(),

                  const SizedBox(width: 8),

                  // Next button
                  Expanded(
                    child: FilledButton(
                      onPressed: _nextPage,
                      child: Text(_translationService.translate(AboutTranslationKeys.onboardingButtonNext)),
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
