import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:domain/shared/utils/logger.dart';
import 'package:application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/main.dart';
import 'package:whph/features/habits/components/habit_add_button.dart';
import 'package:whph/features/habits/components/habit_list_options.dart';
import 'package:whph/features/habits/components/habits_list.dart';
import 'package:whph/shared/enums/pagination_mode.dart';
import 'package:whph/features/habits/models/habit_list_style.dart';
import 'package:whph/features/habits/constants/habit_defaults.dart';
import 'package:whph/features/habits/constants/habit_ui_constants.dart';
import 'package:whph/features/habits/pages/habit_details_page.dart';
import 'package:whph/features/habits/services/habits_service.dart';
import 'package:whph/shared/constants/app_theme.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/models/sort_config.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/shared/utils/app_theme_helper.dart';
import 'package:acore/acore.dart';
import 'package:whph/shared/components/loading_overlay.dart';
import 'package:whph/shared/components/responsive_scaffold_layout.dart';
import 'package:application/features/settings/queries/get_setting_query.dart';
import 'package:domain/features/settings/setting.dart';
import 'package:whph/shared/constants/setting_keys.dart';
import 'package:whph/shared/models/dropdown_option.dart';
import 'package:whph/shared/components/kebab_menu.dart';
import 'package:whph/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/shared/components/tour_overlay/tour_overlay.dart';
import 'package:whph/shared/services/tour_navigation_service.dart';

class HabitsPage extends StatefulWidget {
  static const String route = '/habits';

  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  // Calendar layout constants
  // static const double _calendarDayWidth = 46.0; // Moved to dynamic calculation
  static double get _dragHandleWidth => HabitUiConstants.dragHandleTotalWidth;
  final _translationService = container.resolve<ITranslationService>();
  final _habitsService = container.resolve<HabitsService>();
  final _themeService = container.resolve<IThemeService>();

  final Completer<void> _pageReadyCompleter = Completer<void>();
  int _loadedComponents = 0;
  static const int _totalComponentsToLoad = 2;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Auto-start tour if multi-page tour is active
    _checkAndStartTour();
    _habitsService.onSettingsChanged.addListener(_onHabitSettingsChanged);
  }

  @override
  void dispose() {
    _habitsService.onSettingsChanged.removeListener(_onHabitSettingsChanged);
    super.dispose();
  }

  void _onHabitSettingsChanged() {
    _loadSettings();
  }

  void _checkAndStartTour() async {
    if (TourNavigationService.isMultiPageTourActive && TourNavigationService.currentTourIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _pageReadyCompleter.future;
        if (mounted) {
          _startTour(isMultiPageTour: true);
        }
      });
      return;
    }

    final tourAlreadyDone = await TourNavigationService.isTourCompletedOrSkipped();
    if (tourAlreadyDone) return;
  }

  void _componentLoaded() {
    _loadedComponents++;
    if (_loadedComponents >= _totalComponentsToLoad && !_pageReadyCompleter.isCompleted) {
      _pageReadyCompleter.complete();
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
  final HabitListStyle _habitListStyle = HabitListStyle.calendar;
  bool _isThreeStateEnabled = false;
  bool _reverseDayOrder = false;

  Future<void> _openDetails(String habitId, BuildContext context) async {
    await ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: HabitDetailsPage(
        habitId: habitId,
      ),
      size: DialogSize.max,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final setting = await container.resolve<Mediator>().send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.habitThreeStateEnabled),
          );
      final reverseOrderSetting = await container.resolve<Mediator>().send<GetSettingQuery, Setting?>(
            GetSettingQuery(key: SettingKeys.habitReverseDayOrder),
          );

      if (mounted) {
        setState(() {
          if (setting != null) {
            _isThreeStateEnabled = setting.getValue<bool>();
          }
          if (reverseOrderSetting != null) {
            _reverseDayOrder = reverseOrderSetting.getValue<bool>();
          }
        });
      }
    } catch (e, stackTrace) {
      DomainLogger.error("Failed to load habit settings in HabitsPage", error: e, stackTrace: stackTrace);
    }
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
    _componentLoaded();
  }

  void _onHabitsListed(int count) {
    if (mounted) {
      setState(() {
        _isHabitDataLoaded = true;
      });
      _componentLoaded();
    }
  }

  /// Check if all page data has finished loading
  bool get _isPageFullyLoaded {
    return _isHabitListVisible && _isHabitDataLoaded;
  }

  Widget _buildCalendarDay(DateTime date, DateTime today, double width) {
    final bool isToday = DateTimeHelper.isSameDay(date, today);
    final color = isToday ? _themeService.primaryColor : AppTheme.textColor;

    return SizedBox(
      width: width,
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

  /// Calculate calendar spacing width to align with habit cards
  double _calculateCalendarSpacingWidth(bool isCompactView) {
    // Match HabitCard content padding + trailing padding + wrapper padding
    final rightPadding =
        isCompactView ? HabitUiConstants.calendarPaddingMobile : HabitUiConstants.calendarPaddingDesktop;
    // Base spacing = Right Padding + Calendar Trailing Spacer (2.0) + Wrapper Padding (1.0)
    // The wrapper padding (AppTheme.size4XSmall) accounts for the padding applied to HabitCard in HabitsList
    final baseSpacing = HabitUiConstants.calendarTrailingSpacer + rightPadding + AppTheme.size4XSmall;
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
                    habitListStyle: _habitListStyle,
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
                    _habitListStyle == HabitListStyle.calendar &&
                    AppThemeHelper.isScreenGreaterThan(context, AppTheme.screenSmall) &&
                    !_filterByArchived) ...[
                  Builder(builder: (context) {
                    final isMobile = AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium);
                    // Use 36.0 for mobile to match HabitCard, 46.0 otherwise
                    final daySize = isMobile ? 36.0 : HabitUiConstants.calendarDaySize;
                    // Calculate spacing based on view compactness
                    final spacing = _calculateCalendarSpacingWidth(isMobile);

                    return SizedBox(
                      key: _calendarKey,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...(_reverseDayOrder ? lastDays : lastDays.reversed.toList()).asMap().entries.expand((entry) {
                            final index = entry.key;
                            final date = entry.value;
                            return [
                              if (index > 0) const SizedBox(width: HabitUiConstants.calendarDaySpacing),
                              _buildCalendarDay(date, today, daySize),
                            ];
                          }),
                          // Add spacing to match calendar right padding and drag handle width
                          SizedBox(
                            width: spacing,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),

            // List
            if (_isHabitListVisible)
              Expanded(
                child: HabitsList(
                  key: _habitsListKey,
                  style: _habitListStyle,
                  dateRange: daysToShow,
                  filterByTags: _selectedFilterTags,
                  filterNoTags: _showNoTagsFilter,
                  filterByArchived: _filterByArchived,
                  search: _searchQuery,
                  sortConfig: _sortConfig,
                  enableReordering: _sortConfig.useCustomOrder,
                  forceOriginalLayout: _forceOriginalLayout,
                  useParentScroll: false,
                  isThreeStateEnabled: _isThreeStateEnabled,
                  isReverseDayOrder: _reverseDayOrder,
                  paginationMode: PaginationMode.infinityScroll,
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
      builder: (overlayContext) => TourOverlay(
        steps: tourSteps,
        onComplete: () {
          Navigator.of(overlayContext).pop();
          if (isMultiPageTour) {
            TourNavigationService.onPageTourCompleted(overlayContext);
          }
        },
        onSkip: () async {
          if (isMultiPageTour) {
            await TourNavigationService.skipMultiPageTour();
          }
          if (overlayContext.mounted) Navigator.of(overlayContext).pop();
        },
        onBack: isMultiPageTour && TourNavigationService.canNavigateBack
            ? () => TourNavigationService.navigateBackInTour(overlayContext)
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
