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
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
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

  late AppUsageFilterState _filterState;
  bool _hasPermission = false;
  bool _isListVisible = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _filterState = AppUsageFilterState(
      startDate: DateTime(now.year, now.month, now.day, 23, 59, 59).subtract(const Duration(days: 7)),
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _checkPermission();
  }

  void _onSettingsLoaded() {
    if (!mounted) return;
    setState(() {
      _isListVisible = true;
    });
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _deviceAppUsageService.checkUsageStatsPermission();
    setState(() {
      _hasPermission = hasPermission;
    });
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
            color: AppTheme.primaryColor,
            tooltip: 'Debug Usage Statistics',
          ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showTagRulesSettings,
          color: AppTheme.primaryColor,
          tooltip: _translationService.translate(AppUsageTranslationKeys.tagRulesButton),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _onRefresh,
          color: AppTheme.primaryColor,
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
          if (!_hasPermission)
            AppUsagePermission(
              onPermissionGranted: _onPermissionGranted,
            ),

          // Filters
          if (_hasPermission) ...[
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
                    filterStartDate: _filterState.startDate,
                    filterEndDate: _filterState.endDate,
                    filterByDevices: _filterState.devices),
              ),
          ],
        ],
      ),
    );
  }
}
