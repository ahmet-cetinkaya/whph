import 'package:flutter/material.dart';
import 'package:whph/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/core/acore/repository/models/sort_direction.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/search_filter.dart';
import 'package:whph/presentation/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/shared/models/sort_config.dart';
import 'package:whph/presentation/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'dart:async';

class NoteListOptions extends StatefulWidget {
  final List<String>? selectedTagIds;
  final bool showNoTagsFilter;
  final String? search;
  final SortConfig<NoteSortFields>? sortConfig;

  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;
  final Function(String?)? onSearchChange;
  final Function(SortConfig<NoteSortFields>)? onSortChange;

  final bool showTagFilter;
  final bool showSearchFilter;
  final bool showSortButton;
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
  });

  @override
  State<NoteListOptions> createState() => _NoteListOptionsState();
}

class _NoteListOptionsState extends State<NoteListOptions> {
  final _translationService = container.resolve<ITranslationService>();
  Timer? _searchDebounce;
  Timer? _tagFilterDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tagFilterDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String? query) {
    _searchDebounce?.cancel();

    if (query == null || query.isEmpty) {
      widget.onSearchChange?.call(query);
      return;
    }

    final debounceTime = query.length == 1 ? const Duration(milliseconds: 100) : const Duration(milliseconds: 500);
    _searchDebounce = Timer(debounceTime, () {
      widget.onSearchChange?.call(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final iconSize = AppTheme.iconSizeMedium;

    final bool showAnyFilters = (widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null) ||
        (widget.showSortButton && widget.onSortChange != null);

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
                    ),

                  // Search filter
                  if (widget.showSearchFilter && widget.onSearchChange != null)
                    SearchFilter(
                      onSearch: _onSearchChanged,
                      placeholder: _translationService.translate(NoteTranslationKeys.searchPlaceholder),
                      iconSize: iconSize,
                      iconColor: Colors.grey,
                      expandedWidth: 200,
                    ),

                  // Sort button
                  if (widget.showSortButton && widget.onSortChange != null)
                    SortDialogButton<NoteSortFields>(
                      iconColor: Theme.of(context).primaryColor,
                      tooltip: _translationService.translate(SharedTranslationKeys.sort),
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
                      onConfigChanged: widget.onSortChange!,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
