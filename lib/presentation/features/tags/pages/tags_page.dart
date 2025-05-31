import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/presentation/features/tags/constants/tag_defaults.dart';
import 'package:whph/presentation/shared/components/help_menu.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/features/tags/components/tag_list_options.dart';
import 'package:whph/presentation/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/features/tags/components/tags_list.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/features/tags/pages/tag_details_page.dart';
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

  // Main List Options
  static const String _mainSettingKeyVariantSuffix = 'MAIN';
  List<String>? _selectedTagIds;
  bool _showArchived = false;
  bool _showNoTagsFilter = false;

  // Tag Time Chart Options
  static const String _timeChartSettingKeyVariantSuffix = 'TIME_CHART';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  // List Options
  static const String _listSettingKeyVariantSuffix = 'LIST';
  String? _searchFilterQuery;
  SortConfig<TagSortFields> _sortConfig = TagDefaults.sorting;

  Future<void> _openDetails(String id) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.max,
      child: TagDetailsPage(
        tagId: id,
      ),
    );
  }

  void _onTagFilterChange(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    final List<String>? newFilters = tagOptions.isEmpty ? null : tagOptions.map((option) => option.value).toList();

    if (!CollectionUtils.areListsEqual(_selectedTagIds, newFilters) || _showNoTagsFilter != isNoneSelected) {
      setState(() {
        _selectedTagIds = newFilters;
        _showNoTagsFilter = isNoneSelected;
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

  void _onListSearchChange(String? query) {
    if (mounted) {
      setState(() {
        _searchFilterQuery = query;
      });
    }
  }

  void _onListSortConfigChange(SortConfig<TagSortFields> newConfig) {
    if (mounted) {
      setState(() {
        _sortConfig = newConfig;
      });
    }
  }

  bool _mainListOptionLoaded = false;
  void _onMainSettingsLoaded() {
    if (mounted) {
      setState(() {
        _mainListOptionLoaded = true;
      });
    }
  }

  bool _listOptionLoaded = false;
  void _onListOptionLoaded() {
    if (mounted) {
      setState(() {
        _listOptionLoaded = true;
      });
    }
  }

  bool _tagTimeChartOptionsLoaded = false;
  void _onTagTimeChartOptionsLoaded() {
    if (mounted) {
      setState(() {
        _tagTimeChartOptionsLoaded = true;
      });
    }
  }

  void _onTimeChartCategoryChanged(categories) {
    setState(() {
      _selectedCategories = categories;
    });
  }

  void _onArchivedToggle(show) {
    setState(() {
      _showArchived = show;
    });
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
          initialName: _searchFilterQuery,
          initialArchived: _showArchived,
        ),
        HelpMenu(
          titleKey: TagTranslationKeys.overviewHelpTitle,
          markdownContentKey: TagTranslationKeys.overviewHelpContent,
        ),
        const SizedBox(width: 8),
      ],
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main List Options
          TagListOptions(
            settingKeyVariantSuffix: _mainSettingKeyVariantSuffix,
            onSettingsLoaded: _onMainSettingsLoaded,
            selectedTagIds: _selectedTagIds,
            showNoTagsFilter: _showNoTagsFilter,
            showArchived: _showArchived,
            onTagFilterChange: _onTagFilterChange,
            onArchivedToggle: _onArchivedToggle,
            showSearchFilter: false,
            showSortButton: false,
          ),

          // Tag Time Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall, vertical: AppTheme.sizeSmall),
            child: Row(
              children: [
                Text(
                  _translationService.translate(TagTranslationKeys.timeDistribution),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                TagTimeChartOptions(
                  selectedStartDate: _startDate,
                  selectedEndDate: _endDate,
                  onDateFilterChange: _onDateFilterChange,
                  selectedCategories: _selectedCategories,
                  onCategoriesChanged: _onTimeChartCategoryChanged,
                  settingKeyVariantSuffix: _timeChartSettingKeyVariantSuffix,
                  onSettingsLoaded: _onTagTimeChartOptionsLoaded,
                ),
              ],
            ),
          ),

          // Tag Time Chart
          if (_mainListOptionLoaded && _tagTimeChartOptionsLoaded)
            Padding(
              padding: const EdgeInsets.all(AppTheme.sizeSmall),
              child: Center(
                child: TagTimeChart(
                  filterByTags: _selectedTagIds,
                  startDate: _startDate,
                  endDate: _endDate,
                  filterByIsArchived: _showArchived,
                  selectedCategories: _selectedCategories,
                ),
              ),
            ),

          // List Options
          Padding(
            padding: const EdgeInsets.all(AppTheme.sizeSmall),
            child: Row(
              children: [
                Text(
                  _translationService.translate(TagTranslationKeys.listSectionTitle),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: AppTheme.sizeSmall),
                TagListOptions(
                  onSettingsLoaded: _onListOptionLoaded,
                  showSearchFilter: true,
                  search: _searchFilterQuery,
                  onSearchChange: _onListSearchChange,
                  showSortButton: true,
                  sortConfig: _sortConfig,
                  onSortChange: _onListSortConfigChange,
                  showTagFilter: false,
                  showArchivedToggle: false,
                  settingKeyVariantSuffix: _listSettingKeyVariantSuffix,
                ),
              ],
            ),
          ),

          // List
          if (_mainListOptionLoaded && _listOptionLoaded)
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
                  child: TagsList(
                    onClickTag: (tag) => _openDetails(tag.id),
                    filterByTags: _selectedTagIds,
                    search: _searchFilterQuery,
                    showArchived: _showArchived,
                    sortConfig: _sortConfig,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
