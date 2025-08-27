import 'package:flutter/material.dart';
import 'dart:async';
import 'package:whph/src/core/application/features/tags/models/tag_time_category.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/src/presentation/ui/features/tags/models/tag_time_chart_option_settings.dart';
import 'package:whph/src/presentation/ui/shared/components/date_range_filter.dart';
import 'package:whph/src/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/src/presentation/ui/shared/components/persistent_list_options_base.dart';
import 'package:whph/src/presentation/ui/shared/components/save_button.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:acore/acore.dart' show CollectionUtils;
import 'package:whph/main.dart';

class TagTimeChartOptions extends PersistentListOptionsBase {
  /// Date filter setting with support for quick selections
  final DateFilterSetting? dateFilterSetting;

  /// Selected start date for filtering (deprecated - use dateFilterSetting)
  final DateTime? selectedStartDate;

  /// Selected end date for filtering (deprecated - use dateFilterSetting)
  final DateTime? selectedEndDate;

  /// Selected categories for filtering
  final Set<TagTimeCategory> selectedCategories;

  /// Whether to show date filter
  final bool showDateFilter;

  /// Whether to show category filter
  final bool showCategoryFilter;

  /// Whether there are items to filter
  final bool hasItems;

  /// Callback when date filter changes
  final void Function(DateTime?, DateTime?)? onDateFilterChange;

  /// Callback when date filter setting changes (with quick selection support)
  final Function(DateFilterSetting?)? onDateFilterSettingChange;

  /// Callback when categories filter changes
  final void Function(Set<TagTimeCategory>)? onCategoriesChanged;

  const TagTimeChartOptions({
    super.key,
    this.dateFilterSetting,
    this.selectedStartDate,
    this.selectedEndDate,
    this.onDateFilterChange,
    this.onDateFilterSettingChange,
    this.selectedCategories = const {TagTimeCategory.all},
    this.onCategoriesChanged,
    this.showDateFilter = true,
    this.showCategoryFilter = true,
    this.hasItems = true,
    super.showSaveButton = true,
    super.hasUnsavedChanges = false,
    super.settingKeyVariantSuffix,
    super.onSettingsLoaded,
    super.onSaveSettings,
  });

  @override
  State<TagTimeChartOptions> createState() => _TagTimeChartOptionsState();
}

class _TagTimeChartOptionsState extends PersistentListOptionsBaseState<TagTimeChartOptions> {
  late Set<TagTimeCategory> _selectedCategories;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _selectedCategories = {...widget.selectedCategories};
  }

  @override
  void initSettingKey() {
    settingKey = widget.settingKeyVariantSuffix != null
        ? "${SettingKeys.tagTimeChartOptionsSettings}_${widget.settingKeyVariantSuffix}"
        : SettingKeys.tagTimeChartOptionsSettings;
  }

  @override
  Future<void> loadSavedListOptionSettings() async {
    // Set initial state
    if (mounted) {
      setState(() {
        isSettingLoaded = false;
      });
    }

    await AsyncErrorHandler.executeVoid(
      context: context,
      operation: () async {
        final savedSettings = await filterSettingsManager.loadFilterSettings(
          settingKey: settingKey,
        );

        if (savedSettings != null) {
          final filterSettings = TagTimeChartOptionSettings.fromJson(savedSettings);

          // Convert List<TagTimeCategory> to Set<TagTimeCategory>
          final categories = filterSettings.selectedCategories.toSet();

          if (categories.isNotEmpty && widget.onCategoriesChanged != null) {
            widget.onCategoriesChanged!(categories);
          }

          if (widget.onDateFilterChange != null || widget.onDateFilterSettingChange != null) {
            final dateFilterSetting = filterSettings.dateFilterSetting;

            if (dateFilterSetting != null) {
              // Load any date settings (both quick selections and manual ranges)
              final currentRange = dateFilterSetting.calculateCurrentDateRange();
              widget.onDateFilterChange?.call(currentRange.startDate, currentRange.endDate);
              widget.onDateFilterSettingChange?.call(dateFilterSetting);
            } else {
              // No date settings, clear filter
              widget.onDateFilterChange?.call(null, null);
              widget.onDateFilterSettingChange?.call(null);
            }
          }
        } else {
          // No saved settings - start with empty filter (no default)
          if (widget.onDateFilterChange != null || widget.onDateFilterSettingChange != null) {
            widget.onDateFilterChange?.call(null, null);
            widget.onDateFilterSettingChange?.call(null);
          }
        }
      },
      finallyAction: () {
        if (mounted) {
          setState(() {
            isSettingLoaded = true;
          });
        }
        widget.onSettingsLoaded?.call();
      },
    );
  }

  @override
  Future<void> saveFilterSettings() async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.savingError),
      operation: () async {

        // For auto-refresh quick selections, ignore selectedStartDate/selectedEndDate
        // since they are dynamically calculated and shouldn't be saved
        final isAutoRefreshSelection = widget.dateFilterSetting?.isQuickSelection == true &&
            widget.dateFilterSetting?.isAutoRefreshEnabled == true;

        // If dateFilterSetting is null (cleared), save null dates too
        final isFilterCleared = widget.dateFilterSetting == null;


        final settings = TagTimeChartOptionSettings(
          dateFilterSetting: widget.dateFilterSetting,
          selectedStartDate: (isAutoRefreshSelection || isFilterCleared) ? null : widget.selectedStartDate,
          selectedEndDate: (isAutoRefreshSelection || isFilterCleared) ? null : widget.selectedEndDate,
          selectedCategories: widget.selectedCategories.toList(),
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
        }

        // Notify parent that settings were saved
        widget.onSaveSettings?.call();
      },
    );
  }

  @override
  Future<void> checkForUnsavedChanges() async {
    // For auto-refresh quick selections, ignore selectedStartDate/selectedEndDate
    // since they are dynamically calculated and shouldn't be compared
    final isAutoRefreshSelection =
        widget.dateFilterSetting?.isQuickSelection == true && widget.dateFilterSetting?.isAutoRefreshEnabled == true;

    // If dateFilterSetting is null (cleared), ignore dates for comparison too
    final isFilterCleared = widget.dateFilterSetting == null;

    final currentSettings = TagTimeChartOptionSettings(
      dateFilterSetting: widget.dateFilterSetting,
      selectedStartDate: (isAutoRefreshSelection || isFilterCleared) ? null : widget.selectedStartDate,
      selectedEndDate: (isAutoRefreshSelection || isFilterCleared) ? null : widget.selectedEndDate,
      selectedCategories: widget.selectedCategories.toList(),
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

  @override
  void didUpdateWidget(TagTimeChartOptions oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!CollectionUtils.areSetsEqual(oldWidget.selectedCategories, widget.selectedCategories) ||
        widget.dateFilterSetting != oldWidget.dateFilterSetting ||
        widget.selectedStartDate != oldWidget.selectedStartDate ||
        widget.selectedEndDate != oldWidget.selectedEndDate) {
      _selectedCategories = {...widget.selectedCategories};

      // Force immediate check for unsaved changes
      Future.microtask(handleFilterChange);
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

  void _onDateFilterChange(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      // Don't force default dates when cleared - let parent handle it
      widget.onDateFilterChange?.call(null, null);
    } else {
      end = DateTime(end.year, end.month, end.day, 23, 59, 59);
      widget.onDateFilterChange?.call(start, end);
    }

    // Force immediate check for unsaved changes
    Future.microtask(handleFilterChange);
  }

  void _onDateFilterSettingChange(DateFilterSetting? dateFilterSetting) {
    widget.onDateFilterSettingChange?.call(dateFilterSetting);

    // Force immediate check for unsaved changes
    Future.microtask(handleFilterChange);
  }

  String _buildTooltipMessage() {
    if (_selectedCategories.contains(TagTimeCategory.all)) {
      return _translationService.translate(TagTranslationKeys.allCategories);
    }
    return _selectedCategories.map((c) => _translationService.translate(_getCategoryTranslationKey(c))).join(', ');
  }

  Future<void> _showCategoryDialog() async {
    final result = await ResponsiveDialogHelper.showResponsiveDialog<Set<TagTimeCategory>>(
      context: context,
      size: DialogSize.min,
      child: _CategorySelectionDialog(
        selectedCategories: _selectedCategories,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCategories = result;
      });
      widget.onCategoriesChanged?.call(result);

      // Force immediate check for unsaved changes
      Future.microtask(handleFilterChange);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showAnyFilters = widget.hasItems &&
        ((widget.showDateFilter && widget.onDateFilterChange != null) ||
            (widget.showCategoryFilter && widget.onCategoriesChanged != null) ||
            (widget.showSaveButton && (hasUnsavedChanges || showSavedMessage)));

    if (!isSettingLoaded || !showAnyFilters) return const SizedBox.shrink();

    return Container(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Date Range Filter
            if (widget.showDateFilter &&
                (widget.onDateFilterChange != null || widget.onDateFilterSettingChange != null))
              DateRangeFilter(
                selectedStartDate: widget.selectedStartDate,
                selectedEndDate: widget.selectedEndDate,
                dateFilterSetting: widget.dateFilterSetting,
                onDateFilterChange: _onDateFilterChange,
                onDateFilterSettingChange: _onDateFilterSettingChange,
                iconColor: Colors.grey,
              ),

            // Category Filter
            if (widget.showCategoryFilter && widget.onCategoriesChanged != null)
              SizedBox(
                height: kMinInteractiveDimension - 6,
                child: Tooltip(
                  message: _buildTooltipMessage(),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: _showCategoryDialog,
                      borderRadius: BorderRadius.circular(kMinInteractiveDimension / 2),
                      child: Container(
                        constraints: BoxConstraints(
                          minWidth: kMinInteractiveDimension - 6,
                          minHeight: kMinInteractiveDimension - 6,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
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
                                Icon(
                                  TagUiConstants.getTagTimeCategoryIcon(
                                    _selectedCategories.elementAt(i),
                                  ),
                                  size: AppTheme.iconSizeMedium,
                                  color: Theme.of(context).primaryColor,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Save Button
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
