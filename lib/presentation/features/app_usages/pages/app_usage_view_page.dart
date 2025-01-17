import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_list.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/features/shared/components/app_logo.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/features/shared/constants/navigation_items.dart';

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

  void _onTagFilterSelect(List<String> tags) {
    _selectedTagFilters = tags;
    _refreshAppUsages();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: Row(
        children: [
          const AppLogo(width: 32, height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: const Text('App Usages'),
          )
        ],
      ),
      appBarActions: [
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshAppUsages(),
              color: AppTheme.primaryColor,
            ),
          ),
      ],
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TagSelectDropdown(
                isMultiSelect: true,
                onTagsSelected: _onTagFilterSelect,
                showLength: true,
                icon: Icons.label,
                iconSize: 20,
                color: _selectedTagFilters?.isNotEmpty ?? false ? AppTheme.primaryColor : Colors.grey,
                tooltip: 'Filter by tags',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppUsageList(
              key: _appUsageListKey,
              mediator: widget.mediator,
              onOpenDetails: _openDetails,
              filterByTags: _selectedTagFilters,
            ),
          ),
        ],
      ),
    );
  }
}
