import 'package:flutter/material.dart';
import 'package:whph/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/core/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_time_chart_options.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_defaults.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_add_button.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_list_options.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_time_chart.dart';
import 'package:whph/presentation/ui/features/tags/components/tags_list.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/features/tags/pages/tag_details_page.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/tour_overlay.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';

class TagsPage extends StatefulWidget {
  static const String route = '/tags';

  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  // Tour keys
  final GlobalKey _addTagButtonKey = GlobalKey();
  final GlobalKey _mainFiltersKey = GlobalKey();
  final GlobalKey _timeChartSectionKey = GlobalKey();
  final GlobalKey _timeChartKey = GlobalKey();
  final GlobalKey _listOptionsKey = GlobalKey();
  final GlobalKey _tagsListKey = GlobalKey();
  final GlobalKey _mainContentKey = GlobalKey();

  // Main List Options
  static const String _mainSettingKeyVariantSuffix = 'MAIN';
  List<String>? _selectedTagIds;
  bool _showArchived = false;
  bool _showNoTagsFilter = false;

  // Tag Time Chart Options
  static const String _timeChartSettingKeyVariantSuffix = 'TIME_CHART';

  @override
  void initState() {
    super.initState();
    // Auto-start tour if multi-page tour is active
    _checkAndStartTour();
  }

  void _checkAndStartTour() async {
    final tourAlreadyDone = await TourNavigationService.isTourCompletedOrSkipped();
    if (tourAlreadyDone) return;

    if (TourNavigationService.isMultiPageTourActive && TourNavigationService.currentTourIndex == 3) {
      // Delay to ensure the page is fully built and laid out
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _startTour(isMultiPageTour: true);
          }
        });
      });
    }
  }

  DateFilterSetting? _dateFilterSetting;
  DateTime? _startDate;
  DateTime? _endDate;
  Set<TagTimeCategory> _selectedCategories = {TagTimeCategory.all};

  // List Options
  static const String _listSettingKeyVariantSuffix = 'LIST';
  String? _searchFilterQuery;
  SortConfig<TagSortFields> _sortConfig = TagDefaults.sorting;

  bool _isDataLoaded = false;

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
    } else {
      // When cleared (null values), clear internal dates too for consistency
      setState(() {
        _startDate = null;
        _endDate = null;
      });
    }
  }

  void _onDateFilterSettingChange(DateFilterSetting? dateFilterSetting) {
    if (_dateFilterSetting != dateFilterSetting) {
      setState(() {
        _dateFilterSetting = dateFilterSetting;
        if (dateFilterSetting != null) {
          final currentRange = dateFilterSetting.calculateCurrentDateRange();
          _startDate = currentRange.startDate;
          _endDate = currentRange.endDate;
        } else {
          _startDate = null;
          _endDate = null;
        }
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

  void _onTimeChartCategoryChanged(Set<TagTimeCategory> categories) {
    setState(() {
      _selectedCategories = categories;
    });
  }

  void _onArchivedToggle(bool show) {
    setState(() {
      _showArchived = show;
    });
  }

  void _onDataListed(int count) {
    if (mounted) {
      setState(() {
        _isDataLoaded = true;
      });
    }
  }

  bool get _isPageFullyLoaded {
    return _mainListOptionLoaded && _listOptionLoaded && _tagTimeChartOptionsLoaded && _isDataLoaded;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffoldLayout(
      title: _translationService.translate(TagTranslationKeys.title),
      appBarActions: [
        TagAddButton(
          key: _addTagButtonKey,
          onTagCreated: (tagId) {
            _openDetails(tagId);
          },
          buttonColor: _themeService.primaryColor,
          tooltip: _translationService.translate(TagTranslationKeys.addTagTooltip),
          initialName: _searchFilterQuery,
          initialArchived: _showArchived,
        ),
        KebabMenu(
          helpTitleKey: TagTranslationKeys.overviewHelpTitle,
          helpMarkdownContentKey: TagTranslationKeys.overviewHelpContent,
          onStartTour: _startIndividualTour,
        ),
      ],
      builder: (context) => LoadingOverlay(
        isLoading: !_isPageFullyLoaded,
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: Column(
              key: _mainContentKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main List Options
                TagListOptions(
                  key: _mainFiltersKey,
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
                  key: _timeChartSectionKey,
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
                    key: _timeChartKey,
                    padding: const EdgeInsets.all(AppTheme.sizeSmall),
                    child: Center(
                      child: TagTimeChart(
                        filterByTags: _selectedTagIds,
                        startDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                        endDate: _endDate ?? DateTime.now(),
                        filterByIsArchived: _showArchived,
                        selectedCategories: _selectedCategories,
                      ),
                    ),
                  ),

                // List Options
                Padding(
                  key: _listOptionsKey,
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
                    key: _tagsListKey,
                    onClickTag: (tag) => _openDetails(tag.id),
                    onList: _onDataListed,
                    filterByTags: _selectedTagIds,
                    search: _searchFilterQuery,
                    showArchived: _showArchived,
                    sortConfig: _sortConfig,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startTour({bool isMultiPageTour = false}) {
    final tourSteps = [
      // 1. Page introduce
      TourStep(
        title: _translationService.translate(TagTranslationKeys.tourSmartTaggingTitle),
        description: _translationService.translate(TagTranslationKeys.tourSmartTaggingDescription),
        icon: Icons.label_outline,
        targetKey: _mainContentKey,
        position: TourPosition.bottom,
      ),
      // 2. Tag list introduce
      TourStep(
        title: _translationService.translate(TagTranslationKeys.tourYourTagsTitle),
        description: _translationService.translate(TagTranslationKeys.tourYourTagsDescription),
        targetKey: _tagsListKey,
        position: TourPosition.top,
      ),
      // 3. General list options (tag and archived filter)
      TourStep(
        title: _translationService.translate(TagTranslationKeys.tourTagArchiveFiltersTitle),
        description: _translationService.translate(TagTranslationKeys.tourTagArchiveFiltersDescription),
        targetKey: _mainFiltersKey,
        position: TourPosition.bottom,
      ),
      // 4. List options introduce
      TourStep(
        title: _translationService.translate(TagTranslationKeys.tourSearchSortTitle),
        description: _translationService.translate(TagTranslationKeys.tourSearchSortDescription),
        targetKey: _listOptionsKey,
        position: TourPosition.bottom,
      ),
      // 5. Time distribution introduce
      TourStep(
        title: _translationService.translate(TagTranslationKeys.tourTimeDistributionChartTitle),
        description: _translationService.translate(TagTranslationKeys.tourTimeDistributionChartDescription),
        targetKey: _timeChartSectionKey,
        position: TourPosition.bottom,
      ),
      // 6. Chart filter options introduce
      TourStep(
        title: _translationService.translate(TagTranslationKeys.tourChartCustomizationTitle),
        description: _translationService.translate(TagTranslationKeys.tourChartCustomizationDescription),
        targetKey: _timeChartKey,
        position: TourPosition.top,
      ),
      // 7. Add tag button introduce
      TourStep(
        title: _translationService.translate(TagTranslationKeys.tourCreateTagsTitle),
        description: _translationService.translate(TagTranslationKeys.tourCreateTagsDescription),
        targetKey: _addTagButtonKey,
        position: TourPosition.bottom,
      ),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => TourOverlay(
        steps: tourSteps,
        onComplete: () {
          Navigator.of(context).pop();
          if (isMultiPageTour) {
            TourNavigationService.onPageTourCompleted(context);
          }
        },
        onSkip: () async {
          if (isMultiPageTour) {
            await TourNavigationService.skipMultiPageTour();
          }
          if (context.mounted) Navigator.of(context).pop();
        },
        onBack: isMultiPageTour && TourNavigationService.canNavigateBack
            ? () => TourNavigationService.navigateBackInTour(context)
            : null,
        showBackButton: isMultiPageTour,
        isFinalPageOfTour: !isMultiPageTour || TourNavigationService.currentTourIndex == 5, // Notes page is final
        translationService: _translationService,
      ),
    );
  }

  void _startIndividualTour() {
    _startTour(isMultiPageTour: false);
  }
}
