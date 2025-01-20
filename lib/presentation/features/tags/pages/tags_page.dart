import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/app_logo.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tags/components/tags_list.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/constants/navigation_items.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';

class TagsPage extends StatefulWidget {
  static const String route = '/tags';

  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final Mediator _mediator = container.resolve<Mediator>();

  List<String>? _selectedFilters; // Rename from _selectedTagIds to _selectedFilters for clarity
  Key _tagsListKey = UniqueKey();
  Key _addButtonKey = const ValueKey('tagAddButton');
  bool _showArchived = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  Key _chartKey = UniqueKey();

  void _refreshTags() {
    setState(() {
      _selectedFilters = null;
      _tagsListKey = UniqueKey();
      _addButtonKey = ValueKey(DateTime.now().toString());
    });
  }

  Future<void> _openTagDetails(String tagId) async {
    await Navigator.of(context).pushNamed(
      TagDetailsPage.route,
      arguments: {'id': tagId},
    );
    _refreshTags();
  }

  void _onFilterTags(List<DropdownOption<String>> tagOptions) {
    setState(() {
      _selectedFilters = tagOptions.map((option) => option.value).toList();
      _tagsListKey = UniqueKey();
      _chartKey = UniqueKey();
    });
  }

  void _onDateFilterChange(DateTime? startDate, DateTime? endDate) {
    // Make parameters nullable
    setState(() {
      _startDate = startDate ?? DateTime.now().subtract(const Duration(days: 7)); // Use default if null
      _endDate = endDate ?? DateTime.now(); // Use default if null
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      appBarTitle: Row(
        children: [
          const AppLogo(width: 32, height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: const Text('Tags'),
          )
        ],
      ),
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TagAddButton(
            key: _addButtonKey,
            onTagCreated: (tagId) {
              _openTagDetails(tagId);
            },
            buttonColor: AppTheme.primaryColor,
          ),
        ),
      ],
      topNavItems: NavigationItems.topNavItems,
      bottomNavItems: NavigationItems.bottomNavItems,
      routes: {},
      defaultRoute: (context) => Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(
          children: [
            // Tag filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TagSelectDropdown(
                isMultiSelect: true,
                onTagsSelected: _onFilterTags,
                icon: Icons.label,
                iconSize: 20,
                color: _selectedFilters?.isNotEmpty ?? false ? AppTheme.primaryColor : Colors.grey,
                tooltip: 'Filter by tags',
                showLength: true,
              ),
            ),

            // Tag Times Section with Date Filter
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Row(
                children: [
                  Text(
                    'Tag Times',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: DateRangeFilter(
                      selectedStartDate: _startDate,
                      selectedEndDate: _endDate,
                      onDateFilterChange: (start, end) {
                        _onDateFilterChange(start, end);
                      },
                      iconSize: 20,
                      iconColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // Chart
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: SizedBox(
                  height: 300,
                  width: 300,
                  child: TagTimeChart(
                    key: _chartKey,
                    filterByTags: _selectedFilters,
                    startDate: _startDate,
                    endDate: _endDate,
                  ),
                ),
              ),
            ),

            // Tags Section with Archive Filter
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Row(
                children: [
                  Text(
                    'Tags',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: FilterIconButton(
                      icon: _showArchived ? Icons.archive : Icons.archive_outlined,
                      color: _showArchived ? AppTheme.primaryColor : null,
                      tooltip: _showArchived ? 'Hide archived tags' : 'Show archived tags',
                      onPressed: () {
                        setState(() {
                          _showArchived = !_showArchived;
                          _tagsListKey = UniqueKey();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            // List
            TagsList(
              key: _tagsListKey,
              mediator: _mediator,
              onTagAdded: _refreshTags,
              onClickTag: (tag) => _openTagDetails(tag.id),
              filterByTags: _selectedFilters,
              showArchived: _showArchived,
            ),
          ],
        ),
      ),
    );
  }
}
