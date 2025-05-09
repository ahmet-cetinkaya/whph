import 'package:flutter/material.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';

class AppUsageFilterState {
  final List<String>? tags;
  final bool showNoTagsFilter;
  final DateTime startDate;
  final DateTime endDate;

  const AppUsageFilterState({
    this.tags,
    this.showNoTagsFilter = false,
    required this.startDate,
    required this.endDate,
  });

  AppUsageFilterState copyWith({
    List<String>? tags,
    bool? showNoTagsFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return AppUsageFilterState(
      tags: tags ?? this.tags,
      showNoTagsFilter: showNoTagsFilter ?? this.showNoTagsFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class AppUsageFilters extends StatefulWidget {
  final AppUsageFilterState initialState;
  final void Function(AppUsageFilterState) onFiltersChanged;

  const AppUsageFilters({
    super.key,
    required this.initialState,
    required this.onFiltersChanged,
  });

  @override
  State<AppUsageFilters> createState() => _AppUsageFiltersState();
}

class _AppUsageFiltersState extends State<AppUsageFilters> {
  final _translationService = container.resolve<ITranslationService>();
  late AppUsageFilterState _currentState;

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
  }

  void _handleTagSelect(List<DropdownOption<String>> tagOptions, bool isNoneSelected) {
    final selectedValues = tagOptions.map((option) => option.value).toList();
    final newState = AppUsageFilterState(
      tags: selectedValues.isEmpty ? null : selectedValues,
      showNoTagsFilter: isNoneSelected,
      startDate: _currentState.startDate,
      endDate: _currentState.endDate,
    );

    if (mounted) {
      setState(() => _currentState = newState);
    }

    widget.onFiltersChanged(newState);
  }

  void _handleDateChange(DateTime? start, DateTime? end) {
    final effectiveStart = start ?? DateTime.now().subtract(const Duration(days: 7));
    var effectiveEnd = end ?? DateTime.now();

    // Always set end date to end of day for consistent filtering
    effectiveEnd = DateTime(
      effectiveEnd.year,
      effectiveEnd.month,
      effectiveEnd.day,
      23,
      59,
      59,
    );

    final newState = AppUsageFilterState(
      tags: _currentState.tags,
      showNoTagsFilter: _currentState.showNoTagsFilter,
      startDate: effectiveStart,
      endDate: effectiveEnd,
    );

    if (mounted) {
      setState(() => _currentState = newState);
    }

    widget.onFiltersChanged(newState);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          TagSelectDropdown(
            isMultiSelect: true,
            initialSelectedTags: _currentState.tags
                    ?.map(
                      (tag) => DropdownOption(value: tag, label: ''),
                    )
                    .toList() ??
                [],
            onTagsSelected: _handleTagSelect,
            showLength: true,
            showNoneOption: true,
            initialNoneSelected: _currentState.showNoTagsFilter,
            icon: Icons.label,
            iconSize: AppTheme.iconSizeMedium,
            color: (_currentState.tags?.isNotEmpty ?? false) || _currentState.showNoTagsFilter
                ? AppTheme.primaryColor
                : Colors.grey,
            tooltip: _translationService.translate(AppUsageTranslationKeys.filterTagsButton),
          ),
          const SizedBox(width: AppTheme.sizeXSmall),
          DateRangeFilter(
            selectedStartDate: _currentState.startDate,
            selectedEndDate: _currentState.endDate,
            onDateFilterChange: _handleDateChange,
            iconSize: AppTheme.iconSizeMedium,
          ),
        ],
      ),
    );
  }
}
