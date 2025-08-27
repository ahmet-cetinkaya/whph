import 'package:flutter/material.dart';
import 'package:whph/src/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/src/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_defaults.dart';
import 'package:whph/src/presentation/ui/shared/components/help_menu.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_add_button.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_list_options.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_time_chart.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tags_list.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/src/presentation/ui/features/tags/pages/tag_details_page.dart';
import 'package:whph/src/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/src/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:acore/acore.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/presentation/ui/shared/models/date_filter_setting.dart';

class TagsPage extends StatefulWidget {
  static const String route = '/tags';

  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  // Main List Options
  static const String _mainSettingKeyVariantSuffix = 'MAIN';
  List<String>? _selectedTagIds;
  bool _showArchived = false;
  bool _showNoTagsFilter = false;

  // Tag Time Chart Options
  static const String _timeChartSettingKeyVariantSuffix = 'TIME_CHART';
  DateFilterSetting? _dateFilterSetting;
  DateTime? _startDate;
  DateTime? _endDate;
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  // List Options
  static const String _listSettingKeyVariantSuffix = 'LIST';
  String? _searchFilterQuery;
  SortConfig<TagSortFields> _sortConfig = TagDefaults.sorting;

  Future<void> _openDetails(String id) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: TagDetailsPage(
        tagId: id,
      ),
      size: DialogSize.large,
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
    if (startDate != null && endDate != null) {
      if (CollectionUtils.hasValueChanged(_startDate, startDate) ||
          CollectionUtils.hasValueChanged(_endDate, endDate)) {
        setState(() {
          _startDate = startDate;
          _endDate = endDate;
        });
      }
    }
    // When cleared (null values), don't change internal dates
    // Keep existing dates for chart display but filter is cleared
  }

  void _onDateFilterSettingChange(DateFilterSetting? dateFilterSetting) {
    if (_dateFilterSetting != dateFilterSetting) {
      setState(() {
        _dateFilterSetting = dateFilterSetting;
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
          buttonColor: _themeService.primaryColor,
          tooltip: _translationService.translate(TagTranslationKeys.addTagTooltip),
          initialName: _searchFilterQuery,
          initialArchived: _showArchived,
        ),
        HelpMenu(
          titleKey: TagTranslationKeys.overviewHelpTitle,
          markdownContentKey: TagTranslationKeys.overviewHelpContent,
        ),
      ],
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeSmall),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        _translationService.translate(TagTranslationKeys.timeDistribution),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: AppTheme.sizeSmall),
                      TagTimeChartOptions(
                        dateFilterSetting: _dateFilterSetting,
                        selectedStartDate: _dateFilterSetting != null ? _startDate : null,
                        selectedEndDate: _dateFilterSetting != null ? _endDate : null,
                        onDateFilterChange: _onDateFilterChange,
                        onDateFilterSettingChange: _onDateFilterSettingChange,
                        selectedCategories: _selectedCategories,
                        onCategoriesChanged: _onTimeChartCategoryChanged,
                        settingKeyVariantSuffix: _timeChartSettingKeyVariantSuffix,
                        onSettingsLoaded: _onTagTimeChartOptionsLoaded,
                      ),
                    ],
                  ),
                ),
              ),

              // Tag Time Chart
              if (_mainListOptionLoaded && _tagTimeChartOptionsLoaded)
                Padding(
                  padding: const EdgeInsets.all(AppTheme.sizeSmall),
                  child: Center(
                    child: TagTimeChart(
                      filterByTags: _selectedTagIds,
                      startDate: _dateFilterSetting != null ? (_startDate ?? DateTime.now().subtract(const Duration(days: 30))) : DateTime.now().subtract(const Duration(days: 30)),
                      endDate: _dateFilterSetting != null ? (_endDate ?? DateTime.now()) : DateTime.now(),
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
                    Expanded(
                      child: TagListOptions(
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
                    ),
                  ],
                ),
              ),

              // List
              if (_mainListOptionLoaded && _listOptionLoaded)
                TagsList(
                  onClickTag: (tag) => _openDetails(tag.id),
                  filterByTags: _selectedTagIds,
                  search: _searchFilterQuery,
                  showArchived: _showArchived,
                  sortConfig: _sortConfig,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
