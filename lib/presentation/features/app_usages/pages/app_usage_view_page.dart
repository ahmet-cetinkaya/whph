import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/app_usages/components/app_usage_list.dart';
import 'package:whph/presentation/features/app_usages/pages/app_usage_details_page.dart';
import 'package:whph/presentation/features/shared/components/secondary_app_bar.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';

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
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => AppUsageDetailsPage(appUsageId: id)));
    _refreshAppUsages();
  }

  void _onTagFilterSelect(List<String> tags) {
    _selectedTagFilters = tags;
    _refreshAppUsages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SecondaryAppBar(
          context: context,
          title: const Text('App Usages'),
          actions: [
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _refreshAppUsages();
                  },
                  color: AppTheme.primaryColor,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(AppTheme.surface2),
                  ),
                ),
              ),
          ],
        ),
        body: ListView(
          children: [
            // Filters
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: TagSelectDropdown(
                  isMultiSelect: true,
                  onTagsSelected: _onTagFilterSelect,
                  buttonLabel: "Filter by tags",
                ),
              ),
            ),

            AppUsageList(
                key: _appUsageListKey,
                mediator: widget.mediator,
                onOpenDetails: _openDetails,
                filterByTags: _selectedTagFilters),
          ],
        ));
  }
}
