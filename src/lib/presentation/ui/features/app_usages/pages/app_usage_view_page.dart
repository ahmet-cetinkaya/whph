import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/presentation/ui/features/app_usages/components/app_usage_list_options.dart';
import 'package:whph/presentation/ui/features/app_usages/components/app_usage_list.dart';
import 'package:whph/presentation/ui/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/ui/features/app_usages/pages/app_usage_rules_page.dart';
import 'package:whph/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/presentation/ui/features/app_usages/pages/android_app_usage_debug_page.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/features/settings/components/app_usage_permission.dart';
import 'package:whph/presentation/ui/shared/components/tour_overlay.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';

class AppUsageViewPage extends StatefulWidget {
  static const String route = '/app-usages';

  const AppUsageViewPage({super.key});

  @override
  State<AppUsageViewPage> createState() => _AppUsageViewPageState();
}

class _AppUsageViewPageState extends State<AppUsageViewPage> {
  final _translationService = container.resolve<ITranslationService>();
  final _deviceAppUsageService = container.resolve<IAppUsageService>();
  final _appUsagesService = container.resolve<AppUsagesService>();
  final _themeService = container.resolve<IThemeService>();

  final GlobalKey _mainContentKey = GlobalKey();
  final GlobalKey _appUsageListKey = GlobalKey();
  final GlobalKey _listOptionsKey = GlobalKey();
  final GlobalKey _settingsButtonKey = GlobalKey();

  late AppUsageFilterState _filterState;
  bool _hasPermission = false;
  bool _isListVisible = false;
  bool _isCheckingPermission = true;
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();

    // Start with no date filter - user will set dates when needed
    _filterState = const AppUsageFilterState();
    _checkPermission();

    // Auto-start tour if multi-page tour is active
    _checkAndStartTour();
  }

  void _checkAndStartTour() {
    if (TourNavigationService.isMultiPageTourActive && TourNavigationService.currentTourIndex == 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        while (!_isPageFullyLoaded && mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (mounted) {
          _startTour(isMultiPageTour: true);
        }
      });
    }
  }

  void _onSettingsLoaded() {
    if (!mounted) return;
    setState(() {
      _isListVisible = true;
    });
  }

  void _onDataListed(int count) {
    if (mounted) {
      setState(() {
        _isDataLoaded = true;
      });
    }
  }

  bool get _isPageFullyLoaded {
    return _isListVisible && _isDataLoaded;
  }

  Future<void> _checkPermission() async {
    try {
      final hasPermission = await _deviceAppUsageService.checkUsageStatsPermission();
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _isCheckingPermission = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isCheckingPermission = false;
        });
      }
    }
  }

  Future<void> _openDetails(String id) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: AppUsageDetailsPage(
        appUsageId: id,
      ),
      size: DialogSize.large,
    );
  }

  void _handleFiltersChanged(AppUsageFilterState newState) {
    if (!mounted) return;
    setState(() {
      _filterState = newState;
    });
  }

  DateTime? _getEffectiveStartDate() {
    if (_filterState.dateFilterSetting != null) {
      final currentRange = _filterState.dateFilterSetting!.calculateCurrentDateRange();
      return currentRange.startDate ?? _filterState.startDate;
    }
    return _filterState.startDate;
  }

  DateTime? _getEffectiveEndDate() {
    if (_filterState.dateFilterSetting != null) {
      final currentRange = _filterState.dateFilterSetting!.calculateCurrentDateRange();
      return currentRange.endDate ?? _filterState.endDate;
    }
    return _filterState.endDate;
  }

  void _onPermissionGranted() {
    if (!mounted) return;
    setState(() {
      _hasPermission = true;
    });
  }

  void _onRefresh() {
    _appUsagesService.notifyRefresh();
  }

  Future<void> _showTagRulesSettings() async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: const AppUsageRulesPage(),
      size: DialogSize.large,
    );
    setState(() {}); // Trigger rebuild to refresh list
  }

  Future<void> _showAndroidDebugScreen() async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: AndroidAppUsageDebugPage(),
      size: DialogSize.large,
    );
  }

  void _startTour({bool isMultiPageTour = false}) {
    final tourSteps = [
      // 1. Page introduce
      TourStep(
        title: _translationService.translate(AppUsageTranslationKeys.tourAppUsageInsightsTitle),
        description: _translationService.translate(AppUsageTranslationKeys.tourAppUsageInsightsDescription),
        icon: Icons.bar_chart,
        targetKey: _mainContentKey,
        position: TourPosition.bottom,
      ),
      // 2. App usage graph list introduce
      TourStep(
        title: _translationService.translate(AppUsageTranslationKeys.tourUsageStatisticsTitle),
        description: _translationService.translate(AppUsageTranslationKeys.tourUsageStatisticsDescription),
        targetKey: _appUsageListKey,
        position: TourPosition.top,
      ),
      // 3. List options introduce
      TourStep(
        title: _translationService.translate(AppUsageTranslationKeys.tourFilterSortTitle),
        description: _translationService.translate(AppUsageTranslationKeys.tourFilterSortDescription),
        targetKey: _listOptionsKey,
        position: TourPosition.bottom,
      ),
      // 4. App tracking settings button introduce
      TourStep(
        title: _translationService.translate(AppUsageTranslationKeys.tourTrackingSettingsTitle),
        description: _translationService.translate(AppUsageTranslationKeys.tourTrackingSettingsDescription),
        targetKey: _settingsButtonKey,
        position: TourPosition.bottom,
      ),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => TourOverlay(
        steps: tourSteps,
        onComplete: () {
          Navigator.of(context).pop();
          if (isMultiPageTour) {
            TourNavigationService.onPageTourCompleted(context);
          }
        },
        onSkip: () {
          Navigator.of(context).pop();
        },
        onBack: isMultiPageTour && TourNavigationService.canNavigateBack
            ? () => TourNavigationService.navigateBackInTour(context)
            : null,
        showBackButton: isMultiPageTour,
        isFinalPageOfTour: !isMultiPageTour || TourNavigationService.currentTourIndex == 5, // Notes page is final
      ),
    );
  }

  void _startIndividualTour() {
    _startTour(isMultiPageTour: false);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(AppUsageTranslationKeys.viewTitle),
      appBarActions: [
        if (Platform.isAndroid && kDebugMode)
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _showAndroidDebugScreen,
            color: _themeService.primaryColor,
            tooltip: 'Debug Usage Statistics',
          ),
        IconButton(
          key: _settingsButtonKey,
          icon: const Icon(Icons.settings),
          onPressed: _showTagRulesSettings,
          color: _themeService.primaryColor,
          tooltip: _translationService.translate(AppUsageTranslationKeys.tagRulesButton),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _onRefresh,
          color: _themeService.primaryColor,
          tooltip: _translationService.translate(SharedTranslationKeys.refreshTooltip),
        ),
        KebabMenu(
          helpTitleKey: AppUsageTranslationKeys.viewHelpTitle,
          helpMarkdownContentKey: AppUsageTranslationKeys.viewHelpContent,
          onStartTour: _startIndividualTour,
        ),
      ],
      builder: (context) => LoadingOverlay(
        isLoading: !_isPageFullyLoaded,
        child: Column(
          key: _mainContentKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show loading indicator while checking permission
            if (_isCheckingPermission)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            // Show permission card only if permission check is complete and permission is not granted
            else if (!_hasPermission)
              AppUsagePermission(
                onPermissionGranted: _onPermissionGranted,
              )
            // Show filters and list if permission is granted
            else ...[
              AppUsageListOptions(
                key: _listOptionsKey,
                initialState: _filterState,
                onFiltersChanged: _handleFiltersChanged,
                onSettingsLoaded: _onSettingsLoaded,
                onSaveSettings: () {
                  // Force refresh the list when settings are saved
                  setState(() {});
                },
              ),

              // List
              if (_isListVisible)
                Expanded(
                  child: AppUsageList(
                      key: _appUsageListKey,
                      onOpenDetails: _openDetails,
                      onList: _onDataListed,
                      filterByTags: _filterState.tags,
                      showNoTagsFilter: _filterState.showNoTagsFilter,
                      filterStartDate: _getEffectiveStartDate(),
                      filterEndDate: _getEffectiveEndDate(),
                      filterByDevices: _filterState.devices),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
