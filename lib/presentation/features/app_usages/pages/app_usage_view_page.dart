import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_list.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_rules_page.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';

class AppUsageViewPage extends StatefulWidget {
  static const String route = '/app-usages';

  final Mediator mediator = container.resolve<Mediator>();

  AppUsageViewPage({super.key});

  @override
  State<AppUsageViewPage> createState() => _AppUsageViewPageState();
}

class _AppUsageViewPageState extends State<AppUsageViewPage> {
  Key _appUsageListKey = UniqueKey();
  List<String>? _selectedTagFilters;
  DateTime _filterStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _filterEndDate = DateTime.now();

  void _refreshList() {
    if (mounted) {
      setState(() {
        _appUsageListKey = UniqueKey();
      });
    }
  }

  Future<void> _openDetails(String id) async {
    await Navigator.of(context).pushNamed(
      AppUsageDetailsPage.route,
      arguments: {'id': id},
    );
    _refreshList();
  }

  void _onTagFilterSelect(List<DropdownOption<String>> tagOptions) {
    setState(() {
      _selectedTagFilters = tagOptions.map((option) => option.value).toList();
      _refreshList();
    });
  }

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    setState(() {
      _filterStartDate = start ?? DateTime.now().subtract(const Duration(days: 7));

      if (end != null) {
        end = DateTime(end!.year, end!.month, end!.day, 23, 59, 59);
      }
      _filterEndDate = end ?? DateTime.now();

      _refreshList();
    });
  }

  void _showHelpModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'App Usage Overview Help',
                      style: AppTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '📊 App Usage tracking helps you understand how you spend time on your applications.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚡ Features',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Automatic Tracking:',
                  '  - Monitor application usage',
                  '  - Track active windows',
                  '  - Record time spent',
                  '• Tag Integration:',
                  '  - Automatic tag assignment',
                  '  - Rule-based categorization',
                  '  - Time tracking by category',
                  '• Analysis Tools:',
                  '  - Filter by date ranges',
                  '  - Filter by tags',
                  '  - View detailed statistics',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '⚙️ Management',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Configure Tag Rules:',
                  '  - Set up automatic tagging',
                  '  - Create ignore rules',
                  '  - Manage app categories',
                  '• Data Controls:',
                  '  - Refresh tracking data',
                  '  - Filter view periods',
                  '  - Customize tag filters',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '💡 Tips',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Set up tag rules early',
                  '• Use meaningful tag categories',
                  '• Review data regularly',
                  '• Adjust rules as needed',
                  '• Group similar applications',
                  '• Keep tracking rules updated',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: 'App Usages',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () async {
            await Navigator.pushNamed(context, AppUsageRulesPage.route);
            _refreshList();
          },
          color: AppTheme.primaryColor,
          tooltip: 'Tag Rules',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshList,
          color: AppTheme.primaryColor,
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpModal,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => ListView(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Tag Filter
                  TagSelectDropdown(
                    isMultiSelect: true,
                    onTagsSelected: _onTagFilterSelect,
                    showLength: true,
                    icon: Icons.label,
                    iconSize: AppTheme.iconSizeSmall,
                    color: _selectedTagFilters?.isNotEmpty ?? false ? AppTheme.primaryColor : Colors.grey,
                    tooltip: 'Filter by tags',
                  ),

                  // Date Range Filter
                  DateRangeFilter(
                    selectedStartDate: _filterStartDate,
                    selectedEndDate: _filterEndDate,
                    onDateFilterChange: _onDateFilterChange,
                  ),
                ],
              ),
            ),
          ),

          // App Usage List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppUsageList(
              key: _appUsageListKey,
              mediator: widget.mediator,
              onOpenDetails: _openDetails,
              filterByTags: _selectedTagFilters,
              filterStartDate: _filterStartDate,
              filterEndDate: _filterEndDate,
            ),
          ),
        ],
      ),
    );
  }
}
