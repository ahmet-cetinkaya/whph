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
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_notification_service.dart';
import 'package:acore/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/language_select_dialog.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> with WidgetsBindingObserver {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();
  final _mediator = container.resolve<Mediator>();
  final _notificationService = container.resolve<INotificationService>();

  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool _permissionsReviewed = false;
  late List<_OnboardingStep> _steps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _steps = _buildSteps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    // Only check on mobile to avoid unnecessary calls on desktop
    if (!PlatformUtils.isMobile) return;

    final hasPermission = await _notificationService.checkPermissionStatus();
    if (hasPermission != _permissionsReviewed) {
      if (mounted) {
        setState(() {
          _permissionsReviewed = hasPermission;
          _steps = _buildSteps();
        });
      }
    }
  }

  List<_OnboardingStep> _buildSteps() {
    final baseSteps = [
      // Welcome
      _OnboardingStep(
        icon: Icons.waving_hand,
        titleKey: AboutTranslationKeys.onboardingTitle1,
        descriptionKey: AboutTranslationKeys.onboardingDescription1,
        extraWidget: (context) => OutlinedButton.icon(
          onPressed: () => _onShowLanguageDialog(context),
          icon: const Icon(Icons.language),
          label: Text(
            _translationService.translate(SettingsTranslationKeys.languageTitle),
          ),
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
            icon: Icon(_permissionsReviewed ? Icons.check : Icons.lock_open),
            label: Text(_translationService.translate(AboutTranslationKeys.onboardingPermissionsButton)),
            style: _permissionsReviewed
                ? OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.successColor,
                    side: const BorderSide(color: AppTheme.successColor),
                  )
                : null,
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

  Future<void> _showPermissionsPage(BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const PermissionsPage(),
      size: DialogSize.xLarge,
    );
    // Refresh permissions after dialog closes
    await _checkPermissions();
  }

  Future<void> _onShowLanguageDialog(BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: LanguageSelectDialog(
        onLanguageChanged: (languageCode) {
          _onLanguageChanged(languageCode);
          Navigator.pop(context);
        },
      ),
      size: DialogSize.max,
    );
  }

  Future<void> _onLanguageChanged(String languageCode) async {
    await _translationService.changeLanguageWithoutNavigation(context, languageCode);
    if (mounted) {
      setState(() {
        _steps = _buildSteps();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.sizeOf(context).width < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentPage > 0) {
          _previousPage();
        }
      },
      child: Dialog(
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
                if (isSmallScreen)
                  Flexible(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _steps.length,
                      onPageChanged: (page) => setState(() => _currentPage = page),
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (step.imageAsset != null)
                                    Image.asset(
                                      step.imageAsset!,
                                      width: 80,
                                      height: 80,
                                    )
                                  else
                                    Icon(
                                      step.icon,
                                      size: 80,
                                      color: _themeService.primaryColor,
                                    ),
                                  const SizedBox(height: 32),
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
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 300),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: step.extraWidget!(context),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  SizedBox(
                    height: 400,
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _steps.length,
                      onPageChanged: (page) => setState(() => _currentPage = page),
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (step.imageAsset != null)
                                    Image.asset(
                                      step.imageAsset!,
                                      width: 80,
                                      height: 80,
                                    )
                                  else
                                    Icon(
                                      step.icon,
                                      size: 80,
                                      color: _themeService.primaryColor,
                                    ),
                                  const SizedBox(height: 32),
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
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 300),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: step.extraWidget!(context),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
        ),
      ),
    );
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
