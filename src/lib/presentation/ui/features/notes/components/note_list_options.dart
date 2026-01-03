import 'package:flutter/material.dart';
import 'package:whph/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/ui/features/notes/models/note_list_option_settings.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/persistent_list_options_base.dart';
import 'package:whph/presentation/ui/shared/components/save_button.dart';
import 'package:whph/presentation/ui/shared/components/search_filter.dart';
import 'package:whph/presentation/ui/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'dart:async';

class NoteListOptions extends PersistentListOptionsBase {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Search query
  final String? search;

  /// Current sort configuration
  final SortConfig<NoteSortFields>? sortConfig;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;

  /// Callback when search filter changes
  final Function(String?)? onSearchChange;

  /// Callback when sort changes
  final Function(SortConfig<NoteSortFields>)? onSortChange;

  /// Whether to show the tag filter button
  final bool showTagFilter;

  /// Whether to show the search filter button
  final bool showSearchFilter;

  /// Whether to show the sort button
  final bool showSortButton;

  /// Whether there are items to filter
  final bool hasItems;

  const NoteListOptions({
    super.key,
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.search,
    this.sortConfig,
    this.onTagFilterChange,
    this.onSearchChange,
    this.onSortChange,
    this.showTagFilter = true,
    this.showSearchFilter = true,
    this.showSortButton = true,
    this.hasItems = true,
    super.showSaveButton = true,
    super.hasUnsavedChanges = false,
    super.settingKeyVariantSuffix,
    super.onSettingsLoaded,
    super.onSaveSettings,
  });

  @override
  State<NoteListOptions> createState() => _NoteListOptionsState();
}

class _NoteListOptionsState extends PersistentListOptionsBaseState<NoteListOptions> {
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initSettingKey() {
    settingKey = widget.settingKeyVariantSuffix != null
        ? '${SettingKeys.notesListOptionsSettings}_${widget.settingKeyVariantSuffix}'
        : SettingKeys.notesListOptionsSettings;
  }

  @override
  Future<void> loadSavedListOptionSettings() async {
    final savedSettings = await filterSettingsManager.loadFilterSettings(
      settingKey: settingKey,
    );

    if (savedSettings != null && mounted) {
      final filterSettings = NoteListOptionSettings.fromJson(savedSettings);

      // Set search state
      setState(() {
        lastSearchQuery = filterSettings.search;
      });

      // Apply tag filters
      if (widget.onTagFilterChange != null) {
        final tagIds = filterSettings.selectedTagIds ?? [];
        final showNoTags = filterSettings.showNoTagsFilter;

        widget.onTagFilterChange!(
          tagIds.map((id) => DropdownOption<String>(value: id, label: id)).toList(),
          showNoTags,
        );
      }

      // Apply search filter
      if (widget.onSearchChange != null && filterSettings.search != null) {
        widget.onSearchChange!(filterSettings.search);
      }

      // Apply sort configuration
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
        final settings = NoteListOptionSettings(
          selectedTagIds: widget.selectedTagIds,
          showNoTagsFilter: widget.showNoTagsFilter,
          search: lastSearchQuery ?? widget.search,
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
    final currentSettings = NoteListOptionSettings(
      selectedTagIds: widget.selectedTagIds,
      showNoTagsFilter: widget.showNoTagsFilter,
      search: lastSearchQuery ?? widget.search,
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

  void _onSearchChanged(String? query) {
    searchDebounce?.cancel();

    // Store the query locally for comparison
    setState(() {
      lastSearchQuery = query;
    });

    if (query == null || query.isEmpty) {
      widget.onSearchChange?.call(query);
      handleFilterChange();
      return;
    }

    searchDebounce = Timer(SharedUiConstants.searchDebounceTime, () {
      widget.onSearchChange?.call(query);
      handleFilterChange();
    });
  }

  bool _hasChanges(NoteListOptions oldWidget) {
    return widget.selectedTagIds != oldWidget.selectedTagIds ||
        widget.showNoTagsFilter != oldWidget.showNoTagsFilter ||
        widget.search != oldWidget.search ||
        widget.sortConfig != oldWidget.sortConfig;
  }

  @override
  void didUpdateWidget(NoteListOptions oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_hasChanges(oldWidget)) {
      handleFilterChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final iconSize = AppTheme.iconSizeMedium;

    final bool showAnyFilters = (widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null) ||
        (widget.showSortButton && widget.onSortChange != null) ||
        (widget.showSaveButton && hasUnsavedChanges);

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
                    isMultiSelect: true,
                    onTagsSelected: (tags, isNoneSelected) {
                      widget.onTagFilterChange!(tags, isNoneSelected);
                      handleFilterChange();
                    },
                    icon: TagUiConstants.tagIcon,
                    iconSize: iconSize,
                    color: (widget.selectedTagIds?.isNotEmpty ?? false) || widget.showNoTagsFilter
                        ? primaryColor
                        : Colors.grey,
                    tooltip: _translationService.translate(NoteTranslationKeys.filterTagsTooltip),
                    showLength: true,
                    showNoneOption: true,
                    initialSelectedTags: widget.selectedTagIds != null
                        ? widget.selectedTagIds!.map((id) => DropdownOption<String>(value: id, label: id)).toList()
                        : [],
                    initialNoneSelected: widget.showNoTagsFilter,
                  ),

                // Search filter
                if (widget.showSearchFilter && widget.onSearchChange != null)
                  SearchFilter(
                    initialValue: lastSearchQuery ?? widget.search,
                    onSearch: _onSearchChanged,
                    placeholder: _translationService.translate(NoteTranslationKeys.searchPlaceholder),
                    iconSize: iconSize,
                    iconColor: (lastSearchQuery != null && lastSearchQuery!.isNotEmpty) ? primaryColor : Colors.grey,
                    expandedWidth: 200,
                    isDense: AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenMedium),
                  ),

                // Sort button
                if (widget.showSortButton && widget.onSortChange != null)
                  SortDialogButton<NoteSortFields>(
                    iconColor: Theme.of(context).primaryColor,
                    tooltip: _translationService.translate(SharedTranslationKeys.sortAndGroup),
                    config: widget.sortConfig ??
                        SortConfig<NoteSortFields>(
                          orderOptions: [
                            SortOptionWithTranslationKey(
                              field: NoteSortFields.createdDate,
                              direction: SortDirection.desc,
                              translationKey: SharedTranslationKeys.createdDateLabel,
                            ),
                          ],
                          useCustomOrder: false,
                        ),
                    defaultConfig: SortConfig<NoteSortFields>(
                      orderOptions: [
                        SortOptionWithTranslationKey(
                          field: NoteSortFields.createdDate,
                          direction: SortDirection.desc,
                          translationKey: SharedTranslationKeys.createdDateLabel,
                        ),
                      ],
                      useCustomOrder: false,
                    ),
                    onConfigChanged: (config) {
                      widget.onSortChange!(config);
                      handleFilterChange();
                    },
                    availableOptions: [
                      SortOptionWithTranslationKey(
                        field: NoteSortFields.title,
                        direction: SortDirection.asc,
                        translationKey: NoteTranslationKeys.titleLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: NoteSortFields.createdDate,
                        direction: SortDirection.desc,
                        translationKey: SharedTranslationKeys.createdDateLabel,
                      ),
                      SortOptionWithTranslationKey(
                        field: NoteSortFields.modifiedDate,
                        direction: SortDirection.desc,
                        translationKey: SharedTranslationKeys.modifiedDateLabel,
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
                  )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
