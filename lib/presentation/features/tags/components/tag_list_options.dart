import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/components/search_filter.dart';
import 'package:whph/presentation/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'dart:async';

class TagListOptions extends StatefulWidget {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Search query
  final String? search;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Whether to show archived tags
  final bool showArchived;

  /// Current sort configuration
  final SortConfig<TagSortFields>? sortConfig;

  /// Callback when tag filter changes
  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;

  /// Callback when search filter changes
  final Function(String?)? onSearchChange;

  /// Callback when sort changes
  final Function(SortConfig<TagSortFields>)? onSortChange;

  /// Callback when archived toggle changes
  final Function(bool)? onArchivedToggle;

  /// Whether to show the tag filter button
  final bool showTagFilter;

  /// Whether to show the search filter button
  final bool showSearchFilter;

  /// Whether to show the sort button
  final bool showSortButton;

  /// Whether to show the archived toggle button
  final bool showArchivedToggle;

  /// Whether there are items to filter
  final bool hasItems;

  const TagListOptions({
    super.key,
    this.selectedTagIds,
    this.search,
    this.showNoTagsFilter = false,
    this.showArchived = false,
    this.sortConfig,
    this.onTagFilterChange,
    this.onSearchChange,
    this.onSortChange,
    this.onArchivedToggle,
    this.showTagFilter = true,
    this.showSearchFilter = true,
    this.showSortButton = true,
    this.showArchivedToggle = true,
    this.hasItems = true,
  });

  @override
  State<TagListOptions> createState() => _TagListOptionsState();
}

class _TagListOptionsState extends State<TagListOptions> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  final Mediator _mediator = container.resolve<Mediator>();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _revalidateSelectedFilters() async {
    if (widget.selectedTagIds == null || widget.selectedTagIds!.isEmpty) return;

    final query = GetListTagsQuery(
      pageIndex: 0,
      pageSize: widget.selectedTagIds!.length,
      filterByTags: widget.selectedTagIds,
      showArchived: widget.showArchived,
    );

    final result = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

    // Only keep selected filters that exist in the current archive state
    final validSelectedTags = result.items
        .where((tag) => widget.selectedTagIds!.contains(tag.id))
        .map((tag) => DropdownOption(value: tag.id, label: tag.name))
        .toList();

    widget.onTagFilterChange?.call(validSelectedTags, widget.showNoTagsFilter);
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
  void didUpdateWidget(TagListOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showArchived != widget.showArchived && widget.selectedTagIds != null) {
      _revalidateSelectedFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // Calculate whether we need the filter row at all
    final bool showAnyFilters = ((widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null) ||
        (widget.showSortButton && widget.onSortChange != null) ||
        (widget.showArchivedToggle && widget.onArchivedToggle != null && widget.hasItems));

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
                  // Tag filter
                  if (widget.showTagFilter && widget.onTagFilterChange != null)
                    TagSelectDropdown(
                      isMultiSelect: true,
                      showArchived: widget.showArchived,
                      initialSelectedTags:
                          widget.selectedTagIds?.map((id) => DropdownOption(value: id, label: '')).toList() ?? [],
                      onTagsSelected: (tags, isNoneSelected) {
                        widget.onTagFilterChange?.call(tags, isNoneSelected);
                      },
                      icon: TagUiConstants.tagIcon,
                      iconSize: AppTheme.iconSizeMedium,
                      color: widget.selectedTagIds?.isNotEmpty ?? false ? primaryColor : Colors.grey,
                      tooltip: _translationService.translate(TagTranslationKeys.filterTagsTooltip),
                      showLength: true,
                    ),

                  // Search filter
                  if (widget.showSearchFilter && widget.onSearchChange != null)
                    SearchFilter(
                      expandedWidth: 200,
                      initialValue: widget.search,
                      onSearch: _onSearchChanged,
                      placeholder: _translationService.translate(SharedTranslationKeys.searchPlaceholder),
                    ),

                  // Sort button
                  if (widget.showSortButton && widget.onSortChange != null && widget.hasItems)
                    SortDialogButton<TagSortFields>(
                      isActive: widget.sortConfig?.orderOptions.isNotEmpty ?? false,
                      tooltip: _translationService.translate(SharedTranslationKeys.sort),
                      availableOptions: [
                        SortOptionWithTranslationKey(
                          field: TagSortFields.name,
                          translationKey: TagTranslationKeys.nameLabel,
                        ),
                        SortOptionWithTranslationKey(
                          field: TagSortFields.createdDate,
                          translationKey: SharedTranslationKeys.createdDateLabel,
                        ),
                        SortOptionWithTranslationKey(
                          field: TagSortFields.modifiedDate,
                          translationKey: SharedTranslationKeys.modifiedDateLabel,
                        ),
                      ],
                      config: widget.sortConfig ?? const SortConfig(orderOptions: []),
                      defaultConfig: const SortConfig(
                        orderOptions: [
                          SortOptionWithTranslationKey(
                            field: TagSortFields.name,
                            translationKey: TagTranslationKeys.nameLabel,
                            direction: SortDirection.asc,
                          ),
                        ],
                      ),
                      onConfigChanged: (config) {
                        widget.onSortChange?.call(config);
                      },
                    ),

                  // Archived toggle button
                  if (widget.showArchivedToggle && widget.onArchivedToggle != null && widget.hasItems)
                    FilterIconButton(
                      icon: widget.showArchived ? Icons.archive : Icons.archive_outlined,
                      iconSize: AppTheme.iconSizeMedium,
                      color: widget.showArchived ? primaryColor : null,
                      tooltip: _translationService.translate(
                        widget.showArchived ? TagTranslationKeys.hideArchived : TagTranslationKeys.showArchived,
                      ),
                      onPressed: () => widget.onArchivedToggle!(!widget.showArchived),
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
