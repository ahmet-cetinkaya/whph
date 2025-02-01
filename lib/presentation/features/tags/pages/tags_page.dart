import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tags/components/tags_list.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TagsPage extends StatefulWidget {
  static const String route = '/tags';

  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

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

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(TagTranslationKeys.title),
      appBarActions: [
        TagAddButton(
          onTagCreated: (tagId) {
            _openTagDetails(tagId);
          },
          buttonColor: AppTheme.primaryColor,
          tooltip: _translationService.translate(TagTranslationKeys.addTagTooltip),
        ),
        HelpMenu(
          titleKey: TagTranslationKeys.overviewHelpTitle,
          markdownContentKey: TagTranslationKeys.overviewHelpContent,
        ),
        const SizedBox(width: 8), // Adjusted spacing
      ],
      builder: (context) => ListView(
        children: [
          // Tag filter with translation
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: TagSelectDropdown(
              isMultiSelect: true,
              onTagsSelected: _onFilterTags,
              icon: Icons.label,
              color: _selectedFilters?.isNotEmpty ?? false ? AppTheme.primaryColor : Colors.grey,
              tooltip: _translationService.translate(TagTranslationKeys.filterTagsTooltip),
              showLength: true,
            ),
          ),

          // Tag Times Section with translation
          Row(
            children: [
              Text(
                _translationService.translate(TagTranslationKeys.timesSectionTitle),
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

          // Chart
          Center(
            child: TagTimeChart(
              key: _chartKey,
              filterByTags: _selectedFilters,
              startDate: _startDate,
              endDate: _endDate,
            ),
          ),

          // Tags Section with translation
          Row(
            children: [
              Text(
                _translationService.translate(TagTranslationKeys.listSectionTitle),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: FilterIconButton(
                  icon: _showArchived ? Icons.archive : Icons.archive_outlined,
                  color: _showArchived ? AppTheme.primaryColor : null,
                  tooltip: _translationService
                      .translate(_showArchived ? TagTranslationKeys.hideArchived : TagTranslationKeys.showArchived),
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
    );
  }
}
