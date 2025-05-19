import 'package:flutter/material.dart';
import 'package:whph/application/features/tags/models/tag_time_category.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/shared/components/date_range_filter.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/core/acore/utils/collection_utils.dart';
import 'package:whph/main.dart';

class TimeChartFilters extends StatefulWidget {
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final Set<TagTimeCategory> selectedCategories;
  final bool showDateFilter;
  final bool showCategoryFilter;

  final void Function(DateTime, DateTime)? onDateFilterChange;
  final void Function(Set<TagTimeCategory>)? onCategoriesChanged;

  const TimeChartFilters({
    super.key,
    this.selectedStartDate,
    this.selectedEndDate,
    this.onDateFilterChange,
    this.selectedCategories = const {TagTimeCategory.all},
    this.onCategoriesChanged,
    this.showDateFilter = true,
    this.showCategoryFilter = true,
  });

  @override
  State<TimeChartFilters> createState() => _TimeChartFiltersState();
}

class _TimeChartFiltersState extends State<TimeChartFilters> {
  late Set<TagTimeCategory> _selectedCategories;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _selectedCategories = {...widget.selectedCategories};
  }

  @override
  void didUpdateWidget(TimeChartFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!CollectionUtils.areSetsEqual(oldWidget.selectedCategories, widget.selectedCategories)) {
      _selectedCategories = {...widget.selectedCategories};
    }
  }

  String _getCategoryTranslationKey(TagTimeCategory category) {
    switch (category) {
      case TagTimeCategory.all:
        return TagTranslationKeys.categoryAll;
      case TagTimeCategory.tasks:
        return TagTranslationKeys.categoryTasks;
      case TagTimeCategory.appUsage:
        return TagTranslationKeys.categoryAppUsage;
      case TagTimeCategory.habits:
        return TagTranslationKeys.categoryHabits;
    }
  }

  String _buildTooltipMessage() {
    if (_selectedCategories.contains(TagTimeCategory.all)) {
      return _translationService.translate(TagTranslationKeys.allCategories);
    }
    return _selectedCategories.map((c) => _translationService.translate(_getCategoryTranslationKey(c))).join(', ');
  }

  Future<void> _showCategoryDialog() async {
    final result = await showDialog<Set<TagTimeCategory>>(
      context: context,
      builder: (BuildContext context) {
        return _CategorySelectionDialog(
          selectedCategories: _selectedCategories,
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedCategories = result;
      });
      widget.onCategoriesChanged?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Date Range Filter
            if (widget.showDateFilter)
              DateRangeFilter(
                selectedStartDate: widget.selectedStartDate,
                selectedEndDate: widget.selectedEndDate,
                onDateFilterChange: (start, end) {
                  if (start != null && end != null) {
                    end = DateTime(end.year, end.month, end.day, 23, 59, 59);
                    widget.onDateFilterChange?.call(start, end);
                  }
                },
                iconColor: Colors.grey,
              ),

            // Category Filter
            if (widget.showCategoryFilter)
              Tooltip(
                message: _buildTooltipMessage(),
                child: IconButton(
                  onPressed: _showCategoryDialog,
                  visualDensity: VisualDensity.compact,
                  padding: _selectedCategories.contains(TagTimeCategory.all)
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 8),
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_selectedCategories.contains(TagTimeCategory.all))
                        Icon(
                          TagUiConstants.getTagTimeCategoryIcon(
                            TagTimeCategory.all,
                          ),
                          size: AppTheme.iconSizeMedium,
                          color: Colors.grey,
                        )
                      else ...[
                        for (int i = 0; i < _selectedCategories.length; i++)
                          if (i == 0 || i == _selectedCategories.length - 1)
                            Icon(
                              TagUiConstants.getTagTimeCategoryIcon(
                                _selectedCategories.elementAt(i),
                              ),
                              size: AppTheme.iconSizeMedium,
                              color: Colors.amber,
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                TagUiConstants.getTagTimeCategoryIcon(
                                  _selectedCategories.elementAt(i),
                                ),
                                size: AppTheme.iconSizeMedium,
                                color: Colors.amber,
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategorySelectionDialog extends StatefulWidget {
  final Set<TagTimeCategory> selectedCategories;

  const _CategorySelectionDialog({
    required this.selectedCategories,
  });

  @override
  State<_CategorySelectionDialog> createState() => _CategorySelectionDialogState();
}

class _CategorySelectionDialogState extends State<_CategorySelectionDialog> {
  late Set<TagTimeCategory> _selectedCategories;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _selectedCategories = {...widget.selectedCategories};
  }

  String _getCategoryTranslationKey(TagTimeCategory category) {
    switch (category) {
      case TagTimeCategory.all:
        return TagTranslationKeys.categoryAll;
      case TagTimeCategory.tasks:
        return TagTranslationKeys.categoryTasks;
      case TagTimeCategory.appUsage:
        return TagTranslationKeys.categoryAppUsage;
      case TagTimeCategory.habits:
        return TagTranslationKeys.categoryHabits;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_translationService.translate(TagTranslationKeys.selectCategory)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...TagTimeCategory.values.map((category) {
              final isSelected = _selectedCategories.contains(category) ||
                  (category == TagTimeCategory.all && _selectedCategories.isEmpty);

              return ListTile(
                leading: Icon(
                  TagUiConstants.getTagTimeCategoryIcon(category),
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(_translationService.translate(_getCategoryTranslationKey(category))),
                selected: isSelected,
                onTap: () {
                  setState(() {
                    if (category == TagTimeCategory.all) {
                      _selectedCategories = {TagTimeCategory.all};
                    } else {
                      _selectedCategories.remove(TagTimeCategory.all);
                      if (isSelected) {
                        _selectedCategories.remove(category);
                        if (_selectedCategories.isEmpty) {
                          _selectedCategories.add(TagTimeCategory.all);
                        }
                      } else {
                        _selectedCategories.add(category);
                        // If all categories are selected, switch to "All"
                        if (_selectedCategories.length == TagTimeCategory.values.length - 1) {
                          // -1 for "All" itself
                          _selectedCategories = {TagTimeCategory.all};
                        }
                      }
                    }
                  });
                },
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedCategories),
          child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
        ),
      ],
    );
  }
}
