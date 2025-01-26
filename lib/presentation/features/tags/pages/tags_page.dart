import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tags/components/tags_list.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';

class TagsPage extends StatefulWidget {
  static const String route = '/tags';

  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final Mediator _mediator = container.resolve<Mediator>();

  List<String>? _selectedFilters;

  Key _tagsListKey = UniqueKey();
  bool _showArchived = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  Key _chartKey = UniqueKey();

  void _refreshChart() {
    setState(() {
      _chartKey = UniqueKey();
    });
  }

  void _refreshAllElements() {
    setState(() {
      _selectedFilters = null;
      _tagsListKey = UniqueKey();
      _chartKey = UniqueKey();
    });
  }

  Future<void> _openTagDetails(String tagId) async {
    await Navigator.of(context).pushNamed(
      TagDetailsPage.route,
      arguments: {'id': tagId},
    );
    _refreshAllElements();
  }

  void _onFilterTags(List<DropdownOption<String>> tagOptions) {
    setState(() {
      _selectedFilters = tagOptions.map((option) => option.value).toList();
      _refreshAllElements();
    });
  }

  void _onDateFilterChange(DateTime? startDate, DateTime? endDate) {
    setState(() {
      _startDate = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      _endDate = endDate ?? DateTime.now();
      _refreshChart();
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
                      'Tags Overview Help',
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
                  '🏷️ Tags help you organize and track time investments across your tasks.',
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  '📊 Time Analysis',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• View time distribution by tag',
                  '• Track time investments over custom periods',
                  '• Compare time spent across different areas',
                  '• Monitor daily and weekly patterns',
                  '• Analyze focus distribution',
                ].map((text) => Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 8),
                      child: Text(text, style: AppTheme.bodyMedium),
                    )),
                const SizedBox(height: 16),
                const Text(
                  '⚡ Features',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                ...const [
                  '• Filter by multiple tags',
                  '• Archive completed project tags',
                  '• Create tag hierarchies',
                  '• Track related tag groups',
                  '• Time tracking across tasks',
                  '• Tag-based organization',
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
                  '• Use meaningful tag names',
                  '• Create hierarchical structures:',
                  '  - Projects under departments',
                  '  - Subtasks under main projects',
                  '  - Categories under areas',
                  '• Review time charts regularly',
                  '• Archive completed projects',
                  '• Use tag filters to focus analysis',
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
      title: 'Tags',
      appBarActions: [
        TagAddButton(
          onTagCreated: (tagId) {
            _openTagDetails(tagId);
          },
          buttonColor: AppTheme.primaryColor,
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpModal,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 2),
      ],
      builder: (context) => Padding(
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
                iconSize: AppTheme.iconSizeSmall,
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
                      iconSize: AppTheme.iconSizeSmall,
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
                child: TagTimeChart(
                  key: _chartKey,
                  filterByTags: _selectedFilters,
                  startDate: _startDate,
                  endDate: _endDate,
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
                          _refreshAllElements();
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
              onTagAdded: _refreshAllElements,
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
