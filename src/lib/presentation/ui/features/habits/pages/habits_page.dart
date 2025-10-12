import 'package:flutter/material.dart';
import 'package:whph/core/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_add_button.dart';
import 'package:whph/presentation/ui/features/habits/components/habit_list_options.dart';
import 'package:whph/presentation/ui/features/habits/components/habits_list.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_defaults.dart';
import 'package:whph/presentation/ui/features/habits/pages/habit_details_page.dart';
import 'package:whph/presentation/ui/features/habits/services/habits_service.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/components/loading_overlay.dart';
import 'package:whph/presentation/ui/shared/components/responsive_scaffold_layout.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/components/kebab_menu.dart';
import 'package:whph/presentation/ui/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/components/tour_overlay.dart';
import 'package:whph/presentation/ui/shared/services/tour_navigation_service.dart';

class HabitsPage extends StatefulWidget {
  static const String route = '/habits';

  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  // Calendar layout constants
  static const double _calendarDayWidth = 46.0;
  static const double _dragHandleWidth =
      AppTheme.iconSizeMedium + AppTheme.sizeSmall + AppTheme.size2XSmall + AppTheme.size2XSmall;
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();
  final _themeService = container.resolve<IThemeService>();

  @override
  void initState() {
    super.initState();
    // Auto-start tour if multi-page tour is active
    _checkAndStartTour();
  }

  void _checkAndStartTour() async {
    final tourAlreadyDone = await TourNavigationService.isTourCompletedOrSkipped();
    if (tourAlreadyDone) return;

    if (TourNavigationService.isMultiPageTourActive && TourNavigationService.currentTourIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        while (!_isPageFullyLoaded && mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (mounted) {
          _startTour(isMultiPageTour: true);
        }
      });
    }
  }

  // Tour keys
  final GlobalKey _addHabitButtonKey = GlobalKey();
  final GlobalKey _habitFiltersKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _habitsListKey = GlobalKey();
  final GlobalKey _mainContentKey = GlobalKey();

  List<String> _selectedFilterTags = [];
  bool _showNoTagsFilter = false;
  bool _filterByArchived = false;
  String? _searchQuery;
  SortConfig<HabitSortFields> _sortConfig = HabitDefaults.sorting;
  bool _forceOriginalLayout = false;
  String? _handledHabitId;
  bool _isHabitListVisible = false;
  bool _isHabitDataLoaded = false;

  Future<void> _openDetails(String habitId, BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: HabitDetailsPage(
        habitId: habitId,
      ),
      size: DialogSize.large,
    );
  }

  void _onFilterTagsSelect(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    if (!mounted) return;

    setState(() {
      _selectedFilterTags = tagOptions.isEmpty ? [] : tagOptions.map((option) => option.value).toList();
      _showNoTagsFilter = isNoneSelected;
    });
  }

  void _onToggleArchived(bool showArchived) {
    if (!mounted) return;
    setState(() {
      _filterByArchived = showArchived;
    });
  }

  void _onSearchChange(String? query) {
    if (!mounted) return;
    setState(() {
      _searchQuery = query;
    });
  }

  // Handle sort configuration changes
  void _onSortConfigChange(SortConfig<HabitSortFields> newConfig) {
    if (mounted) {
      setState(() {
        _sortConfig = newConfig;
      });
    }
  }

  // Handle layout toggle changes
  void _onLayoutToggleChange(bool forceOriginalLayout) {
    if (mounted) {
      setState(() {
        _forceOriginalLayout = forceOriginalLayout;
      });
    }
  }

  void _onSettingsLoaded() {
    if (!mounted) return;
    setState(() {
      _isHabitListVisible = true;
    });
  }

  void _onHabitsListed(int count) {
    if (mounted) {
      setState(() {
        _isHabitDataLoaded = true;
      });
    }
  }

  /// Check if all page data has finished loading
  bool get _isPageFullyLoaded {
    return _isHabitListVisible && _isHabitDataLoaded;
  }

  Widget _buildCalendarDay(DateTime date, DateTime today) {
    final bool isToday = DateTimeHelper.isSameDay(date, today);
    final color = isToday ? _themeService.primaryColor : AppTheme.textColor;

    return SizedBox(
      width: 46,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _translationService.translate(SharedTranslationKeys.getWeekDayTranslationKey(date.weekday, short: true)),
            style: AppTheme.bodySmall.copyWith(color: color),
          ),
          Text(
            date.day.toString(),
            style: AppTheme.bodySmall.copyWith(color: color),
          )
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we have arguments to show habit details
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && (args.containsKey('habitId'))) {
      final habitId = args['habitId'] as String;

      // Only handle the habit if we haven't already handled it
      if (_handledHabitId != habitId) {
        _handledHabitId = habitId;

        // Schedule the dialog to open after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openDetails(habitId, context);
          }
        });
      }
    } else {
      // Check if we have a route name that includes a habit ID
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != null && routeName.startsWith('/habits/') && routeName != '/habits/details') {
        final habitId = routeName.substring('/habits/'.length);

        // Only handle the habit if we haven't already handled it
        if (_handledHabitId != habitId) {
          _handledHabitId = habitId;

          // Schedule the dialog to open after the build is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openDetails(habitId, context);
            }
          });
        }
      }
    }
  }

  /// Calculate calendar header width based on days shown and reordering state
  double _calculateCalendarHeaderWidth(int daysToShow) {
    final baseWidth = daysToShow * _calendarDayWidth;
    final baseSpacing = AppTheme.size3XSmall;
    final dragHandleSpacing = (_sortConfig.useCustomOrder && !_forceOriginalLayout) ? _dragHandleWidth : 0;

    return baseWidth + baseSpacing + dragHandleSpacing;
  }

  /// Calculate calendar spacing width to align with habit cards
  double _calculateCalendarSpacingWidth() {
    final baseSpacing = AppTheme.size3XSmall;
    final dragHandleSpacing = (_sortConfig.useCustomOrder && !_forceOriginalLayout) ? _dragHandleWidth : 0;

    return baseSpacing + dragHandleSpacing;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    int daysToShow = 7;

    if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall)) {
      daysToShow = 1;
    } else if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium)) {
      daysToShow = 2;
    } else if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenLarge)) {
      daysToShow = 4;
    }

    List<DateTime> lastDays = List.generate(daysToShow, (index) => today.subtract(Duration(days: index)));

    const String habitListOptionsSettingKeySuffix = 'HABITS_PAGE';

    return ResponsiveScaffoldLayout(
      title: _translationService.translate(HabitTranslationKeys.pageTitle),
      appBarActions: [
        HabitAddButton(
          key: _addHabitButtonKey,
          onHabitCreated: (String habitId) {
            if (!mounted) return;

            // Notify the service that a habit was created
            _habitsService.notifyHabitCreated(habitId);

            _openDetails(habitId, context);
          },
          buttonColor: _themeService.primaryColor,
          initialTagIds: _showNoTagsFilter
              ? []
              : _selectedFilterTags.isEmpty
                  ? null
                  : _selectedFilterTags,
          initialName: _searchQuery,
          initialArchived: _filterByArchived,
        ),
        KebabMenu(
          helpTitleKey: HabitTranslationKeys.overviewHelpTitle,
          helpMarkdownContentKey: HabitTranslationKeys.overviewHelpContent,
          onStartTour: _startIndividualTour,
        ),
      ],
      builder: (context) => LoadingOverlay(
        isLoading: !_isPageFullyLoaded,
        child: Column(
          key: _mainContentKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters and Calendar row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters and sorting
                Expanded(
                  child: HabitListOptions(
                    key: _habitFiltersKey,
                    selectedTagIds: _selectedFilterTags.isEmpty ? null : _selectedFilterTags,
                    showNoTagsFilter: _showNoTagsFilter,
                    filterByArchived: _filterByArchived,
                    sortConfig: _sortConfig,
                    forceOriginalLayout: _forceOriginalLayout,
                    onTagFilterChange: _onFilterTagsSelect,
                    onArchiveFilterChange: _onToggleArchived,
                    onSearchChange: _onSearchChange,
                    onSortChange: _onSortConfigChange,
                    onLayoutToggleChange: _onLayoutToggleChange,
                    showSearchFilter: true,
                    showSortButton: true,
                    showSaveButton: true,
                    settingKeyVariantSuffix: habitListOptionsSettingKeySuffix,
                    onSettingsLoaded: _onSettingsLoaded,
                  ),
                ),

                // Calendar
                if (_isHabitListVisible &&
                    AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenSmall) &&
                    !_filterByArchived)
                  SizedBox(
                    key: _calendarKey,
                    width: _calculateCalendarHeaderWidth(daysToShow),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ...lastDays.map((date) => _buildCalendarDay(date, today)),
                        // Add spacing to match calendar right padding and drag handle width
                        SizedBox(
                          width: _calculateCalendarSpacingWidth(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // List
            if (_isHabitListVisible)
              Expanded(
                child: HabitsList(
                  key: _habitsListKey,
                  dateRange: daysToShow,
                  filterByTags: _selectedFilterTags,
                  filterNoTags: _showNoTagsFilter,
                  filterByArchived: _filterByArchived,
                  search: _searchQuery,
                  sortConfig: _sortConfig,
                  enableReordering: _sortConfig.useCustomOrder,
                  forceOriginalLayout: _forceOriginalLayout,
                  useParentScroll: false,
                  onClickHabit: (item) {
                    _openDetails(item.id, context);
                  },
                  onListing: _onHabitsListed,
                  onReorderComplete: () {
                    // Refresh the habits list to ensure correct order
                    setState(() {});
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _startTour({bool isMultiPageTour = false}) {
    final tourSteps = [
      // 1. Page introduce
      TourStep(
        title: _translationService.translate(HabitTranslationKeys.tourHabitBuildingTitle),
        description: _translationService.translate(HabitTranslationKeys.tourHabitBuildingDescription),
        icon: Icons.refresh,
        targetKey: _mainContentKey,
        position: TourPosition.bottom,
      ),
      // 2. Add Habit button introduce
      TourStep(
        title: _translationService.translate(HabitTranslationKeys.tourCreateHabitsTitle),
        description: _translationService.translate(HabitTranslationKeys.tourCreateHabitsDescription),
        targetKey: _addHabitButtonKey,
        position: TourPosition.bottom,
      ),
      // 3. Habit list introduce
      TourStep(
        title: _translationService.translate(HabitTranslationKeys.tourYourHabitsTitle),
        description: _translationService.translate(HabitTranslationKeys.tourYourHabitsDescription),
        targetKey: _habitsListKey,
        position: TourPosition.top,
      ),
      // 4. Calendar introduce
      TourStep(
        title: _translationService.translate(HabitTranslationKeys.tourCalendarViewTitle),
        description: _translationService.translate(HabitTranslationKeys.tourCalendarViewDescription),
        targetKey: _calendarKey,
        position: TourPosition.bottom,
      ),
      // 5. List options introduce
      TourStep(
        title: _translationService.translate(HabitTranslationKeys.tourFilterSearchTitle),
        description: _translationService.translate(HabitTranslationKeys.tourFilterSearchDescription),
        targetKey: _habitFiltersKey,
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
      ),
    );
  }

  void _startIndividualTour() {
    _startTour(isMultiPageTour: false);
  }
}
