import 'package:flutter/material.dart';
import 'dart:async';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/presentation/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/shared/constants/setting_keys.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/features/habits/models/habit_list_option_settings.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/components/persistent_list_options_base.dart';
import 'package:whph/presentation/shared/components/search_filter.dart';
import 'package:whph/presentation/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/shared/components/save_button.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class HabitListOptions extends PersistentListOptionsBase {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Flag to indicate if archived habits should be shown
  final bool filterByArchived;

  /// Current sort configuration
  final SortConfig<HabitSortFields>? sortConfig;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;

  /// Callback when archive filter changes
  final Function(bool)? onArchiveFilterChange;

  /// Callback when search filter changes
  final Function(String?)? onSearchChange;

  /// Callback when sort changes
  final Function(SortConfig<HabitSortFields>)? onSortChange;

  /// Whether to show the tag filter button
  final bool showTagFilter;

  /// Whether to show the archive filter
  final bool showArchiveFilter;

  /// Whether to show the search filter button
  final bool showSearchFilter;

  /// Whether to show the sort button
  final bool showSortButton;

  /// Whether there are items to filter
  final bool hasItems;

  const HabitListOptions({
    super.key,
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.filterByArchived = false,
    this.sortConfig,
    this.onTagFilterChange,
    this.onArchiveFilterChange,
    this.onSearchChange,
    this.onSortChange,
    super.onSaveSettings,
    this.showTagFilter = true,
    this.showArchiveFilter = true,
    this.showSearchFilter = true,
    this.showSortButton = true,
    super.showSaveButton = true,
    this.hasItems = true,
    super.hasUnsavedChanges = false,
    super.settingKeyVariantSuffix,
    super.onSettingsLoaded,
  });

  @override
  State<HabitListOptions> createState() => _HabitListOptionsState();
}

class _HabitListOptionsState extends PersistentListOptionsBaseState<HabitListOptions> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  @override
  void initSettingKey() {
    settingKey = widget.settingKeyVariantSuffix != null
        ? "${SettingKeys.habitsListOptionsSettings}_${widget.settingKeyVariantSuffix}"
        : SettingKeys.habitsListOptionsSettings;
  }

  @override
  Future<void> loadSavedListOptionSettings() async {
    final savedSettings = await filterSettingsManager.loadFilterSettings(
      settingKey: settingKey,
    );

    if (savedSettings != null && mounted) {
      final filterSettings = HabitListOptionSettings.fromJson(savedSettings);

      setState(() {
        lastSearchQuery = filterSettings.search;
      });

      if (widget.onTagFilterChange != null) {
        final tagIds = filterSettings.selectedTagIds ?? [];
        final showNoTags = filterSettings.showNoTagsFilter;

        widget.onTagFilterChange!(
          tagIds.map((id) => DropdownOption<String>(value: id, label: id)).toList(),
          showNoTags,
        );
      }

      if (widget.onSearchChange != null && filterSettings.search != null) {
        widget.onSearchChange!(filterSettings.search);
      }

      if (widget.onArchiveFilterChange != null) {
        widget.onArchiveFilterChange!(filterSettings.filterByArchived);
      }

      if (widget.onSortChange != null && filterSettings.sortConfig != null) {
        widget.onSortChange!(filterSettings.sortConfig!);
      }
    }

    if (mounted) {
      setState(() {
        isSettingLoaded = true;
      });
    }
    widget.onSettingsLoaded?.call();
  }

  @override
  Future<void> saveFilterSettings() async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.savingError),
      operation: () async {
        final settings = HabitListOptionSettings(
          selectedTagIds: widget.selectedTagIds,
          showNoTagsFilter: widget.showNoTagsFilter,
          filterByArchived: widget.filterByArchived,
          search: lastSearchQuery,
          sortConfig: widget.sortConfig,
        );

        await filterSettingsManager.saveFilterSettings(
          settingKey: settingKey,
          filterSettings: settings.toJson(),
        );

        if (mounted) {
          setState(() {
            hasUnsavedChanges = false;
          });

          showSavedMessageTemporarily();
          widget.onSaveSettings?.call();
        }
      },
    );
  }

  @override
  Future<void> checkForUnsavedChanges() async {
    final currentSettings = HabitListOptionSettings(
      selectedTagIds: widget.selectedTagIds,
      showNoTagsFilter: widget.showNoTagsFilter,
      filterByArchived: widget.filterByArchived,
      search: lastSearchQuery,
      sortConfig: widget.sortConfig,
    ).toJson();

    final hasChanges = await filterSettingsManager.hasUnsavedChanges(
      settingKey: settingKey,
      currentSettings: currentSettings,
    );

    if (mounted && hasUnsavedChanges != hasChanges) {
      setState(() {
        hasUnsavedChanges = hasChanges;
      });
    }
  }

  bool _hasFilterChanges(HabitListOptions oldWidget) {
    final hasNonSearchChanges = widget.selectedTagIds != oldWidget.selectedTagIds ||
        widget.showNoTagsFilter != oldWidget.showNoTagsFilter ||
        widget.filterByArchived != oldWidget.filterByArchived ||
        widget.sortConfig != oldWidget.sortConfig;

    if (hasNonSearchChanges) {
      return true;
    }

    return false;
  }

  bool _hasSearchChanges(HabitListOptions oldWidget) {
    return false; // This will be checked separately when search changes
  }

  @override
  void didUpdateWidget(HabitListOptions oldWidget) {
    super.didUpdateWidget(oldWidget);

    final hasFilterChanges = _hasFilterChanges(oldWidget);
    final hasSearchChanges = _hasSearchChanges(oldWidget);
    final isFromSearchCallback = searchDebounce?.isActive == true || searchStateCheckTimer?.isActive == true;

    if (hasFilterChanges || (hasSearchChanges && !isFromSearchCallback)) {
      Future.microtask(handleFilterChange);
    }
  }

  void _onSearchChanged(String? query) {
    searchDebounce?.cancel();
    searchStateCheckTimer?.cancel();

    lastSearchQuery = query;

    void processSearchChange() {
      if (!mounted) return;

      widget.onSearchChange?.call(query);
      handleFilterChange();

      searchStateCheckTimer?.cancel();
      searchStateCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (timer.tick >= 50) {
          timer.cancel();
          handleFilterChange(); // Force one last check
        }
      });
    }

    if (query == null || query.isEmpty) {
      processSearchChange();
    } else {
      final debounceTime = query.length == 1 ? const Duration(milliseconds: 100) : const Duration(milliseconds: 500);
      searchDebounce = Timer(debounceTime, processSearchChange);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // Calculate whether we need the filter row at all
    final bool showAnyFilters = ((widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showArchiveFilter && widget.onArchiveFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null) ||
        (widget.showSortButton && widget.onSortChange != null));

    // If no filters to show or settings not loaded, don't render anything
    if (!showAnyFilters || !isSettingLoaded) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filter by tags
                if (widget.showTagFilter && widget.onTagFilterChange != null)
                  TagSelectDropdown(
                    key: ValueKey({
                      'showNoTagsFilter': widget.showNoTagsFilter,
                      'selectedTags': widget.selectedTagIds?.join(',') ?? '',
                    }.toString()),
                    isMultiSelect: true,
                    onTagsSelected: widget.onTagFilterChange!,
                    icon: TagUiConstants.tagIcon,
                    iconSize: AppTheme.iconSizeMedium,
                    color: (widget.selectedTagIds?.isNotEmpty ?? false) || widget.showNoTagsFilter
                        ? primaryColor
                        : Colors.grey,
                    tooltip: _translationService.translate(HabitTranslationKeys.filterByTagsTooltip),
                    showLength: true,
                    showNoneOption: true,
                    initialSelectedTags: widget.selectedTagIds != null
                        ? widget.selectedTagIds!.map((id) => DropdownOption<String>(value: id, label: id)).toList()
                        : [],
                    initialShowNoTagsFilter: widget.showNoTagsFilter,
                    initialNoneSelected: widget.showNoTagsFilter,
                  ),

                // Archive filter
                if (widget.showArchiveFilter && widget.onArchiveFilterChange != null)
                  FilterIconButton(
                    icon: widget.filterByArchived ? Icons.archive : Icons.archive_outlined,
                    iconSize: AppTheme.iconSizeMedium,
                    color: widget.filterByArchived ? primaryColor : Colors.grey,
                    tooltip: _translationService.translate(
                      widget.filterByArchived ? HabitTranslationKeys.hideArchived : HabitTranslationKeys.showArchived,
                    ),
                    onPressed: () => widget.onArchiveFilterChange!(!widget.filterByArchived),
                  ),

                // Search filter
                if (widget.showSearchFilter && widget.onSearchChange != null)
                  SearchFilter(
                    key: ValueKey<String?>(lastSearchQuery),
                    initialValue: lastSearchQuery,
                    onSearch: _onSearchChanged,
                    placeholder: _translationService.translate(SharedTranslationKeys.searchPlaceholder),
                    iconSize: AppTheme.iconSizeMedium,
                    iconColor: (lastSearchQuery != null && lastSearchQuery!.isNotEmpty) ? primaryColor : Colors.grey,
                    expandedWidth: 200,
                    isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
                  ),

                // Sort button
                if (widget.showSortButton && widget.onSortChange != null)
                  SortDialogButton<HabitSortFields>(
                    iconColor: Theme.of(context).primaryColor,
                    tooltip: _translationService.translate(SharedTranslationKeys.sort),
                    config: widget.sortConfig ??
                        SortConfig<HabitSortFields>(
                          orderOptions: [
                            SortOptionWithTranslationKey(
                              field: HabitSortFields.name,
                              direction: SortDirection.asc,
                              translationKey: SharedTranslationKeys.nameLabel,
                            ),
                            SortOptionWithTranslationKey(
                              field: HabitSortFields.createdDate,
                              direction: SortDirection.desc,
                              translationKey: SharedTranslationKeys.createdDateLabel,
                            ),
                          ],
                          useCustomOrder: false,
                        ),
                    defaultConfig: SortConfig<HabitSortFields>(
                      orderOptions: [
                        SortOptionWithTranslationKey(
                          field: HabitSortFields.name,
                          direction: SortDirection.asc,
                          translationKey: SharedTranslationKeys.nameLabel,
                        ),
                        SortOptionWithTranslationKey(
                          field: HabitSortFields.createdDate,
                          direction: SortDirection.desc,
                          translationKey: SharedTranslationKeys.createdDateLabel,
                        ),
                      ],
                      useCustomOrder: false,
                    ),
                    onConfigChanged: widget.onSortChange!,
                    availableOptions: [
                      SortOptionWithTranslationKey(
                        field: HabitSortFields.name,
                        direction: SortDirection.asc,
                        translationKey: SharedTranslationKeys.nameLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: HabitSortFields.createdDate,
                        direction: SortDirection.desc,
                        translationKey: SharedTranslationKeys.createdDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: HabitSortFields.modifiedDate,
                        direction: SortDirection.desc,
                        translationKey: SharedTranslationKeys.modifiedDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: HabitSortFields.archivedDate,
                        direction: SortDirection.desc,
                        translationKey: HabitTranslationKeys.archivedDateLabel,
                      ),
                    ],
                    isActive: widget.sortConfig?.orderOptions.isNotEmpty ?? false,
                  ),

                // Save button
                if (widget.showSaveButton)
                  SaveButton(
                    hasUnsavedChanges: hasUnsavedChanges,
                    showSavedMessage: showSavedMessage,
                    onSave: saveFilterSettings,
                    tooltip: _translationService.translate(SharedTranslationKeys.saveListOptions),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
