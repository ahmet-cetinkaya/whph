import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/presentation/ui/features/app_usages/models/app_usage_filter_settings.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/src/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/src/presentation/ui/shared/components/date_range_filter.dart';
import 'package:whph/src/presentation/ui/shared/components/persistent_list_options_base.dart';
import 'package:whph/src/presentation/ui/shared/components/save_button.dart';
import 'package:whph/src/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/src/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/main.dart';
import 'dart:async';

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

class AppUsageListOptions extends PersistentListOptionsBase {
  final AppUsageFilterState initialState;
  final void Function(AppUsageFilterState) onFiltersChanged;

  const AppUsageListOptions({
    super.key,
    required this.initialState,
    required this.onFiltersChanged,
    super.showSaveButton = true,
    super.hasUnsavedChanges = false,
    super.settingKeyVariantSuffix,
    super.onSettingsLoaded,
    super.onSaveSettings,
  });

  @override
  State<AppUsageListOptions> createState() => _AppUsageFiltersState();
}

class _AppUsageFiltersState extends PersistentListOptionsBaseState<AppUsageListOptions> {
  final _translationService = container.resolve<ITranslationService>();
  late AppUsageFilterState _currentState;

  @override
  void initState() {
    super.initState();
    _currentState = widget.initialState;
  }

  @override
  void initSettingKey() {
    settingKey = widget.settingKeyVariantSuffix != null
        ? '${SettingKeys.appUsagesFilterSettings}_${widget.settingKeyVariantSuffix}'
        : SettingKeys.appUsagesFilterSettings;
  }

  @override
  Future<void> loadSavedListOptionSettings() async {
    final savedSettings = await filterSettingsManager.loadFilterSettings(settingKey: settingKey);

    if (savedSettings != null) {
      final settings = AppUsageFilterSettings.fromJson(savedSettings);

      // Create a new state with the saved settings
      final newState = AppUsageFilterState(
        tags: settings.tags,
        showNoTagsFilter: settings.showNoTagsFilter,
        startDate: settings.startDate,
        endDate: settings.endDate,
      );

      if (mounted) {
        setState(() {
          _currentState = newState;
        });
        widget.onFiltersChanged(newState);
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
        final settings = AppUsageFilterSettings(
          tags: _currentState.tags,
          showNoTagsFilter: _currentState.showNoTagsFilter,
          startDate: _currentState.startDate,
          endDate: _currentState.endDate,
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
    final settings = AppUsageFilterSettings(
      tags: _currentState.tags,
      showNoTagsFilter: _currentState.showNoTagsFilter,
      startDate: _currentState.startDate,
      endDate: _currentState.endDate,
    );

    final hasChanges = await filterSettingsManager.hasUnsavedChanges(
      settingKey: settingKey,
      currentSettings: settings.toJson(),
    );

    if (mounted && hasChanges != hasUnsavedChanges) {
      setState(() {
        hasUnsavedChanges = hasChanges;
      });
    }
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
    handleFilterChange();
  }

  void _handleDateChange(DateTime? start, DateTime? end) {
    final dateNow = DateTime.now();
    final dateFilterEnd = end ?? DateTime(dateNow.year, dateNow.month, dateNow.day, 23, 59, 59);
    final dateFilterStart = start ?? dateFilterEnd.subtract(const Duration(days: 7));

    final newState = AppUsageFilterState(
      tags: _currentState.tags,
      showNoTagsFilter: _currentState.showNoTagsFilter,
      startDate: dateFilterStart,
      endDate: dateFilterEnd,
    );

    if (mounted) {
      setState(() => _currentState = newState);
    }

    widget.onFiltersChanged(newState);
    handleFilterChange();
  }

  @override
  Widget build(BuildContext context) {
    if (!isSettingLoaded) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Tag Filter
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
            icon: TagUiConstants.tagIcon,
            iconSize: AppTheme.iconSizeMedium,
            color: (_currentState.tags?.isNotEmpty ?? false) || _currentState.showNoTagsFilter
                ? AppTheme.primaryColor
                : Colors.grey,
            tooltip: _translationService.translate(AppUsageTranslationKeys.filterTagsButton),
          ),

          // Date Range Filter
          DateRangeFilter(
            selectedStartDate: _currentState.startDate,
            selectedEndDate: _currentState.endDate,
            onDateFilterChange: _handleDateChange,
          ),

          // Save Button
          if (widget.showSaveButton)
            SaveButton(
              onSave: saveFilterSettings,
              tooltip: _translationService.translate(SharedTranslationKeys.saveListOptions),
              hasUnsavedChanges: hasUnsavedChanges,
              showSavedMessage: showSavedMessage,
            ),
        ],
      ),
    );
  }
}
