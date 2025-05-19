import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/filter_icon_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class TagFilters extends StatefulWidget {
  final List<String>? selectedFilters;
  final bool showArchived;
  final Function(List<DropdownOption<String>>) onTagFiltersChange;
  final Function(bool) onArchivedToggle;

  const TagFilters({
    super.key,
    this.selectedFilters,
    required this.showArchived,
    required this.onTagFiltersChange,
    required this.onArchivedToggle,
  });

  @override
  State<TagFilters> createState() => _TagFiltersState();
}

class _TagFiltersState extends State<TagFilters> {
  final Mediator _mediator = container.resolve<Mediator>();
  final _translationService = container.resolve<ITranslationService>();

  @override
  void didUpdateWidget(TagFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showArchived != widget.showArchived && widget.selectedFilters != null) {
      _revalidateSelectedFilters();
    }
  }

  Future<void> _revalidateSelectedFilters() async {
    if (widget.selectedFilters == null || widget.selectedFilters!.isEmpty) return;

    final query = GetListTagsQuery(
      pageIndex: 0,
      pageSize: widget.selectedFilters!.length,
      filterByTags: widget.selectedFilters,
      showArchived: widget.showArchived,
    );

    final result = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

    // Only keep selected filters that exist in the current archive state
    final validSelectedTags = result.items
        .where((tag) => widget.selectedFilters!.contains(tag.id))
        .map((tag) => DropdownOption(value: tag.id, label: tag.name))
        .toList();

    widget.onTagFiltersChange(validSelectedTags);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          TagSelectDropdown(
            isMultiSelect: true,
            showArchived: widget.showArchived,
            initialSelectedTags:
                widget.selectedFilters?.map((id) => DropdownOption(value: id, label: '')).toList() ?? [],
            onTagsSelected: (selectedTags, _) => widget.onTagFiltersChange(selectedTags),
            icon: Icons.label,
            iconSize: AppTheme.iconSizeMedium,
            color: widget.selectedFilters?.isNotEmpty ?? false ? AppTheme.primaryColor : Colors.grey,
            tooltip: _translationService.translate(TagTranslationKeys.filterTagsTooltip),
            showLength: true,
          ),
          FilterIconButton(
            icon: widget.showArchived ? Icons.archive : Icons.archive_outlined,
            iconSize: AppTheme.iconSizeMedium,
            color: widget.showArchived ? AppTheme.primaryColor : null,
            tooltip: _translationService.translate(
              widget.showArchived ? TagTranslationKeys.hideArchived : TagTranslationKeys.showArchived,
            ),
            onPressed: () => widget.onArchivedToggle(!widget.showArchived),
          ),
        ],
      ),
    );
  }
}
