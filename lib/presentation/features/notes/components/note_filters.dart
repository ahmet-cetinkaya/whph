import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/search_filter.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/notes/constants/note_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'dart:async';

class NoteFilters extends StatefulWidget {
  final List<String>? selectedTagIds;
  final bool showNoTagsFilter;
  final String? search;
  final Function(List<DropdownOption<String>>, bool)? onTagFilterChange;
  final Function(String?)? onSearchChange;
  final bool showTagFilter;
  final bool showSearchFilter;
  final bool hasItems;

  const NoteFilters({
    super.key,
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.search,
    this.onTagFilterChange,
    this.onSearchChange,
    this.showTagFilter = true,
    this.showSearchFilter = true,
    this.hasItems = true,
  });

  @override
  State<NoteFilters> createState() => _NoteFiltersState();
}

class _NoteFiltersState extends State<NoteFilters> {
  final _translationService = container.resolve<ITranslationService>();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

    final bool showAnyFilters = ((widget.showTagFilter && widget.onTagFilterChange != null) ||
        (widget.showSearchFilter && widget.onSearchChange != null));

    if (!showAnyFilters) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showTagFilter && widget.onTagFilterChange != null)
            TagSelectDropdown(
              isMultiSelect: true,
              onTagsSelected: widget.onTagFilterChange!,
              icon: Icons.label,
              iconSize: iconSize,
              color:
                  (widget.selectedTagIds?.isNotEmpty ?? false) || widget.showNoTagsFilter ? primaryColor : Colors.grey,
              tooltip: _translationService.translate(NoteTranslationKeys.filterTagsTooltip),
              showLength: true,
              showNoneOption: true,
              initialSelectedTags: widget.selectedTagIds != null
                  ? widget.selectedTagIds!.map((id) => DropdownOption<String>(value: id, label: id)).toList()
                  : [],
            ),
          if (widget.showSearchFilter && widget.onSearchChange != null)
            SearchFilter(
              onSearch: _onSearchChanged,
              placeholder: _translationService.translate(NoteTranslationKeys.searchPlaceholder),
              iconSize: iconSize,
              iconColor: Colors.grey,
              expandedWidth: 200,
            ),
        ],
      ),
    );
  }
}
