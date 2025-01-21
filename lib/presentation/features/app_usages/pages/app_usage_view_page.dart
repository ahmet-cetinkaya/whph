import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_list.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_tag_rules_page.dart';
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
  // Initialize with default dates (last 7 days)
  DateTime _filterStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _filterEndDate = DateTime.now();

  void _refreshAppUsages() {
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
    _refreshAppUsages();
  }

  void _onTagFilterSelect(List<DropdownOption<String>> tagOptions) {
    _selectedTagFilters = tagOptions.map((option) => option.value).toList();
    _refreshAppUsages();
  }

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    setState(() {
      _filterStartDate = start ?? DateTime.now().subtract(const Duration(days: 7));

      if (end != null) {
        end = DateTime(end!.year, end!.month, end!.day, 23, 59, 59);
      }
      _filterEndDate = end ?? DateTime.now();

      _refreshAppUsages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: 'App Usages',
      appBarActions: [
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.pushNamed(context, AppUsageTagRulesPage.route);
                  },
                  color: AppTheme.primaryColor,
                  tooltip: 'Tag Rules',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refreshAppUsages(),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ],
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
                    iconSize: 20,
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
