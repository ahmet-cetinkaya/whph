import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/time_chart_filters.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/features/tags/components/tag_filters.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tags/components/tags_list.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';
import 'package:whph/presentation/features/tags/services/tags_service.dart';
import 'package:whph/presentation/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/core/acore/utils/collection_utils.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

class TagsPage extends StatefulWidget {
  static const String route = '/tags';

  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final _translationService = container.resolve<ITranslationService>();
  final _tagsService = container.resolve<TagsService>();

  List<String>? _selectedFilters;
  bool _showArchived = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};
  final GlobalKey<TagsListState> _tagsListKey = GlobalKey<TagsListState>();

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _removeEventListeners();
    super.dispose();
  }

  void _setupEventListeners() {
    _tagsService.onTagCreated.addListener(_handleTagChange);
    _tagsService.onTagUpdated.addListener(_handleTagChange);
    _tagsService.onTagDeleted.addListener(_handleTagChange);
  }

  void _removeEventListeners() {
    _tagsService.onTagCreated.removeListener(_handleTagChange);
    _tagsService.onTagUpdated.removeListener(_handleTagChange);
    _tagsService.onTagDeleted.removeListener(_handleTagChange);
  }

  void _handleTagChange() {
    _tagsListKey.currentState?.refresh();
  }

  Future<void> _openDetails(String id) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: TagDetailsPage(
        tagId: id,
      ),
    );
  }

  void _onFilterTags(List<DropdownOption<String>> tagOptions) {
    final List<String>? newFilters = tagOptions.isEmpty ? null : tagOptions.map((option) => option.value).toList();

    if (!CollectionUtils.areListsEqual(_selectedFilters, newFilters)) {
      setState(() {
        _selectedFilters = newFilters;
      });
    }
  }

  void _onDateFilterChange(DateTime? startDate, DateTime? endDate) {
    final DateTime newStartDate = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final DateTime newEndDate = endDate ?? DateTime.now();

    if (CollectionUtils.hasValueChanged(_startDate, newStartDate) ||
        CollectionUtils.hasValueChanged(_endDate, newEndDate)) {
      setState(() {
        _startDate = newStartDate;
        _endDate = newEndDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(TagTranslationKeys.title),
      appBarActions: [
        TagAddButton(
          onTagCreated: (tagId) {
            _openDetails(tagId);
          },
          buttonColor: AppTheme.primaryColor,
          tooltip: _translationService.translate(TagTranslationKeys.addTagTooltip),
        ),
        HelpMenu(
          titleKey: TagTranslationKeys.overviewHelpTitle,
          markdownContentKey: TagTranslationKeys.overviewHelpContent,
        ),
        const SizedBox(width: 8),
      ],
      builder: (context) => ListView(
        children: [
          // Tag Filters section
          TagFilters(
            selectedFilters: _selectedFilters,
            showArchived: _showArchived,
            onTagFiltersChange: _onFilterTags,
            onArchivedToggle: (show) {
              setState(() {
                _showArchived = show;
              });
            },
          ),

          // Tag Times Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall, vertical: AppTheme.sizeSmall),
            child: Row(
              children: [
                Text(
                  _translationService.translate(TagTranslationKeys.timeDistribution),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                TimeChartFilters(
                  selectedStartDate: _startDate,
                  selectedEndDate: _endDate,
                  onDateFilterChange: _onDateFilterChange,
                  selectedCategories: _selectedCategories,
                  onCategoriesChanged: (categories) {
                    setState(() {
                      _selectedCategories = categories;
                    });
                  },
                ),
              ],
            ),
          ),

          // Chart
          Padding(
            padding: const EdgeInsets.all(AppTheme.sizeSmall),
            child: Center(
              child: TagTimeChart(
                filterByTags: _selectedFilters,
                startDate: _startDate,
                endDate: _endDate,
                filterByIsArchived: _showArchived,
                selectedCategories: _selectedCategories,
              ),
            ),
          ),

          // Tags Section Title
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.sizeSmall,
              right: AppTheme.sizeSmall,
              top: AppTheme.sizeMedium,
              bottom: AppTheme.sizeXSmall,
            ),
            child: Text(
              _translationService.translate(TagTranslationKeys.listSectionTitle),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),

          // List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
            child: TagsList(
              key: _tagsListKey,
              onClickTag: (tag) => _openDetails(tag.id),
              filterByTags: _selectedFilters,
              showArchived: _showArchived,
            ),
          ),
        ],
      ),
    );
  }
}
