import 'package:flutter/material.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/shared/components/date_range_filter.dart';
import 'package:whph/presentation/features/shared/components/search_filter.dart';
import 'package:whph/presentation/features/shared/models/dropdown_option.dart';

class TaskFilters extends StatefulWidget {
  final List<String>? selectedTagIds;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final Function(List<DropdownOption<String>>) onTagFilterChange;
  final Function(DateTime?, DateTime?) onDateFilterChange;
  final Function(String?) onSearchChange;
  final bool showTagFilter;
  final bool showDateFilter;
  final bool showSearchFilter;

  const TaskFilters({
    super.key,
    this.selectedTagIds,
    this.selectedStartDate,
    this.selectedEndDate,
    required this.onTagFilterChange,
    required this.onDateFilterChange,
    required this.onSearchChange,
    this.showTagFilter = true,
    this.showDateFilter = true,
    this.showSearchFilter = true,
  });

  @override
  State<TaskFilters> createState() => _TaskFiltersState();
}

class _TaskFiltersState extends State<TaskFilters> {
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final iconSize = 20.0;

    return Container(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Tag filter
            if (widget.showTagFilter)
              TagSelectDropdown(
                isMultiSelect: true,
                onTagsSelected: widget.onTagFilterChange,
                icon: Icons.label,
                iconSize: iconSize,
                color: widget.selectedTagIds?.isNotEmpty ?? false ? primaryColor : Colors.grey,
                tooltip: 'Filter by tags',
                showLength: true,
              ),

            // Date filter
            if (widget.showDateFilter)
              DateRangeFilter(
                selectedStartDate: widget.selectedStartDate,
                selectedEndDate: widget.selectedEndDate,
                onDateFilterChange: widget.onDateFilterChange,
                iconSize: iconSize,
                iconColor: Colors.grey,
              ),

            // Search filter
            if (widget.showSearchFilter)
              SearchFilter(
                onSearch: widget.onSearchChange,
                placeholder: 'Search tasks',
                iconSize: iconSize,
                iconColor: Colors.grey,
                expandedWidth: 200,
              ),
          ],
        ),
      ),
    );
  }
}
