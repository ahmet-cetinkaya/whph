import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/src/core/application/features/app_usages/services/abstraction/i_app_usage_service.dart';
import 'package:whph/src/presentation/ui/features/app_usages/components/app_usage_list_options.dart';
import 'package:whph/src/presentation/ui/features/app_usages/components/app_usage_list.dart';
import 'package:whph/src/presentation/ui/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/src/presentation/ui/features/app_usages/pages/app_usage_rules_page.dart';
import 'package:whph/src/presentation/ui/features/app_usages/services/app_usages_service.dart';
import 'package:whph/src/presentation/ui/features/app_usages/pages/android_app_usage_debug_page.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/src/presentation/ui/shared/components/help_menu.dart';
import 'package:whph/src/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/presentation/ui/features/settings/components/app_usage_permission.dart';

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

  late AppUsageFilterState _filterState;
  bool _hasPermission = false;
  bool _isListVisible = false;
  bool _isCheckingPermission = true;

  @override
  void initState() {
    super.initState();

    // Start with no date filter - user will set dates when needed
    _filterState = const AppUsageFilterState();
    _checkPermission();
  }

  void _onSettingsLoaded() {
    if (!mounted) return;
    setState(() {
      _isListVisible = true;
    });
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
      if (_filterState.dateFilterSetting!.isQuickSelection) {
        final currentRange = _filterState.dateFilterSetting!.calculateCurrentDateRange();
        return currentRange.startDate ?? _filterState.startDate;
      } else {
        return _filterState.dateFilterSetting!.startDate ?? _filterState.startDate;
      }
    }
    return _filterState.startDate;
  }

  DateTime? _getEffectiveEndDate() {
    if (_filterState.dateFilterSetting != null) {
      if (_filterState.dateFilterSetting!.isQuickSelection) {
        final currentRange = _filterState.dateFilterSetting!.calculateCurrentDateRange();
        return currentRange.endDate ?? _filterState.endDate;
      } else {
        return _filterState.dateFilterSetting!.endDate ?? _filterState.endDate;
      }
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
        HelpMenu(
          titleKey: AppUsageTranslationKeys.viewHelpTitle,
          markdownContentKey: AppUsageTranslationKeys.viewHelpContent,
        ),
      ],
      builder: (context) => Column(
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
                    onOpenDetails: _openDetails,
                    filterByTags: _filterState.tags,
                    showNoTagsFilter: _filterState.showNoTagsFilter,
                    filterStartDate: _getEffectiveStartDate(),
                    filterEndDate: _getEffectiveEndDate(),
                    filterByDevices: _filterState.devices),
              ),
          ],
        ],
      ),
    );
  }
}
