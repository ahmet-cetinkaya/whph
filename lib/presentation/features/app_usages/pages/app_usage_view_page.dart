import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_filters.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_list.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_rules_page.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';

class AppUsageViewPage extends StatefulWidget {
  static const String route = '/app-usages';

  const AppUsageViewPage({super.key});

  @override
  State<AppUsageViewPage> createState() => _AppUsageViewPageState();
}

class _AppUsageViewPageState extends State<AppUsageViewPage> {
  final _translationService = container.resolve<ITranslationService>();

  late AppUsageFilterState _filterState;

  @override
  void initState() {
    super.initState();
    _filterState = AppUsageFilterState(
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      endDate: DateTime.now(),
    );
  }

  Future<void> _openDetails(String id) async {
    await Navigator.of(context).pushNamed(
      AppUsageDetailsPage.route,
      arguments: {'id': id},
    );

    // setState çağrısına artık gerek yok, liste AppUsagesService event listenerlari
    // sayesinde otomatik olarak güncellenecek
  }

  void _handleFiltersChanged(AppUsageFilterState newState) {
    setState(() {
      _filterState = newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(AppUsageTranslationKeys.viewTitle),
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            await Navigator.pushNamed(context, AppUsageRulesPage.route);
            setState(() {}); // Trigger rebuild to refresh list
          },
          color: AppTheme.primaryColor,
          tooltip: _translationService.translate(AppUsageTranslationKeys.tagRulesButton),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() {}), // Trigger rebuild to refresh list
          color: AppTheme.primaryColor,
          tooltip: _translationService.translate(SharedTranslationKeys.refreshTooltip),
        ),
        HelpMenu(
          titleKey: AppUsageTranslationKeys.viewHelpTitle,
          markdownContentKey: AppUsageTranslationKeys.viewHelpContent,
        ),
        const SizedBox(width: 8),
      ],
      builder: (context) => ListView(
        children: [
          // Filters
          AppUsageFilters(
            initialState: _filterState,
            onFiltersChanged: _handleFiltersChanged,
          ),

          // List
          AppUsageList(
            onOpenDetails: _openDetails,
            filterByTags: _filterState.tags,
            showNoTagsFilter: _filterState.showNoTagsFilter,
            filterStartDate: _filterState.startDate,
            filterEndDate: _filterState.endDate,
          ),
        ],
      ),
    );
  }
}
