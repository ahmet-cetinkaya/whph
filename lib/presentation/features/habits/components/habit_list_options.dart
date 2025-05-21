import 'package:flutter/material.dart';
import 'package:whph/application/features/habits/queries/get_list_habits_query.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/components/search_filter.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/habits/constants/habit_translation_keys.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'dart:async';

class HabitListOptions extends StatefulWidget {
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
    this.showTagFilter = true,
    this.showArchiveFilter = true,
    this.showSearchFilter = true,
    this.showSortButton = true,
    this.hasItems = true,
  });

  @override
  State<HabitListOptions> createState() => _HabitListOptionsState();
}

class _HabitListOptionsState extends State<HabitListOptions> {
  final _translationService = container.resolve<ITranslationService>();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String? query) {
    _searchDebounce?.cancel();

    // If query is null or empty, immediately call the callback
    if (query == null || query.isEmpty) {
      widget.onSearchChange?.call(query);
      return;
    }

    // For single character searches, use a shorter debounce time
    final debounceTime = query.length == 1 ? const Duration(milliseconds: 100) : const Duration(milliseconds: 500);

    _searchDebounce = Timer(debounceTime, () {
      widget.onSearchChange?.call(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // Calculate whether we need the filter row at all
    final bool showAnyFilters = ((widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showArchiveFilter && widget.onArchiveFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null) ||
        (widget.showSortButton && widget.onSortChange != null));

    // If no filters to show, don't render anything
    if (!showAnyFilters) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Row(
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
                      onSearch: _onSearchChanged,
                      placeholder: _translationService.translate(SharedTranslationKeys.searchPlaceholder),
                      iconSize: AppTheme.iconSizeMedium,
                      iconColor: Colors.grey,
                      expandedWidth: 200,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
