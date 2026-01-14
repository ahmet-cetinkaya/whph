import 'package:flutter/material.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_sort_fields.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/features/app_usages/models/app_usage_filter_settings.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/components/date_range_filter/date_range_filter.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/features/app_usages/components/device_select_dropdown.dart';
import 'package:whph/presentation/ui/shared/components/persistent_list_options_base.dart';
import 'package:whph/presentation/ui/shared/components/save_button.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/features/app_usages/constants/app_usage_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/components/sort_dialog_button.dart';
import 'package:whph/presentation/ui/shared/components/group_dialog_button.dart';
import 'package:acore/acore.dart' show SortDirection;
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';
import 'dart:async';

class AppUsageFilterState {
  final List<String>? tags;
  final bool showNoTagsFilter;
  final DateFilterSetting? dateFilterSetting;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? devices;
  final bool showComparison;
  final SortConfig<AppUsageSortFields>? sortConfig;
  final bool useTagColorForBars;

  const AppUsageFilterState({
    this.tags,
    this.showNoTagsFilter = false,
    this.dateFilterSetting,
    this.startDate,
    this.endDate,
    this.devices,
    this.showComparison = false,
    this.sortConfig,
    this.useTagColorForBars = false,
  });

  AppUsageFilterState copyWith({
    List<String>? tags,
    bool? showNoTagsFilter,
    DateFilterSetting? dateFilterSetting,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? devices,
    bool? showComparison,
    SortConfig<AppUsageSortFields>? sortConfig,
    bool? useTagColorForBars,
  }) {
    return AppUsageFilterState(
      tags: tags ?? this.tags,
      showNoTagsFilter: showNoTagsFilter ?? this.showNoTagsFilter,
      dateFilterSetting: dateFilterSetting ?? this.dateFilterSetting,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      devices: devices ?? this.devices,
      showComparison: showComparison ?? this.showComparison,
      sortConfig: sortConfig ?? this.sortConfig,
      useTagColorForBars: useTagColorForBars ?? this.useTagColorForBars,
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
  final _themeService = container.resolve<IThemeService>();
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

      // Calculate effective dates from DateFilterSetting if available
      DateTime? effectiveStart = settings.startDate;
      DateTime? effectiveEnd = settings.endDate;

      if (settings.dateFilterSetting != null) {
        final currentRange = settings.dateFilterSetting!.calculateCurrentDateRange();
        effectiveStart = currentRange.startDate;
        effectiveEnd = currentRange.endDate;
      }

      // Create a new state with the saved settings
      final newState = AppUsageFilterState(
        tags: settings.tags,
        showNoTagsFilter: settings.showNoTagsFilter,
        dateFilterSetting: settings.dateFilterSetting,
        startDate: effectiveStart ?? settings.startDate,
        endDate: effectiveEnd ?? settings.endDate,
        devices: settings.devices,
        showComparison: settings.showComparison,
        sortConfig: settings.sortConfig,
        useTagColorForBars: settings.useTagColorForBars,
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
          dateFilterSetting: _currentState.dateFilterSetting,
          startDate: _currentState.startDate,
          endDate: _currentState.endDate,
          devices: _currentState.devices,
          showComparison: _currentState.showComparison,
          sortConfig: _currentState.sortConfig,
          useTagColorForBars: _currentState.useTagColorForBars,
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
      dateFilterSetting: _currentState.dateFilterSetting,
      startDate: _currentState.startDate,
      endDate: _currentState.endDate,
      devices: _currentState.devices,
      showComparison: _currentState.showComparison,
      sortConfig: _currentState.sortConfig,
      useTagColorForBars: _currentState.useTagColorForBars,
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
      devices: _currentState.devices,
    );

    if (mounted) {
      setState(() => _currentState = newState);
    }

    widget.onFiltersChanged(newState);
    handleFilterChange();
  }

  void _handleDateChange(DateTime? start, DateTime? end) {
    // If both are null, this is likely a clear operation - let _handleDateSettingChange handle it
    if (start == null && end == null) {
      return; // Skip handling, wait for _handleDateSettingChange(null)
    }

    final dateNow = DateTime.now();
    final dateFilterEnd = end ?? DateTime(dateNow.year, dateNow.month, dateNow.day, 23, 59, 59);
    final dateFilterStart = start ?? dateFilterEnd.subtract(const Duration(days: 7));

    final newState = AppUsageFilterState(
      tags: _currentState.tags,
      showNoTagsFilter: _currentState.showNoTagsFilter,
      dateFilterSetting: null, // Clear dateFilterSetting when manual dates are set
      startDate: dateFilterStart,
      endDate: dateFilterEnd,
      devices: _currentState.devices,
    );

    if (mounted) {
      setState(() => _currentState = newState);
    }

    widget.onFiltersChanged(newState);
    handleFilterChange();
  }

  void _handleDateSettingChange(DateFilterSetting? dateFilterSetting) {
    DateTime? effectiveStart = _currentState.startDate;
    DateTime? effectiveEnd = _currentState.endDate;

    if (dateFilterSetting != null) {
      if (dateFilterSetting.isQuickSelection) {
        final currentRange = dateFilterSetting.calculateCurrentDateRange();
        effectiveStart = currentRange.startDate;
        effectiveEnd = currentRange.endDate;
      } else {
        effectiveStart = dateFilterSetting.startDate;
        effectiveEnd = dateFilterSetting.endDate;
      }
    } else {
      // When clearing, also clear the dates to prevent false quick selection detection
      effectiveStart = null;
      effectiveEnd = null;
    }

    final newState = AppUsageFilterState(
      tags: _currentState.tags,
      showNoTagsFilter: _currentState.showNoTagsFilter,
      dateFilterSetting: dateFilterSetting, // This will be null when clearing
      startDate: effectiveStart,
      endDate: effectiveEnd,
      devices: _currentState.devices,
    );

    if (mounted) {
      setState(() => _currentState = newState);
    }

    widget.onFiltersChanged(newState);
    handleFilterChange();
  }

  void _handleDeviceSelect(List<DropdownOption<String>> deviceOptions, bool isNoneSelected) {
    final selectedValues = deviceOptions.map((option) => option.value).toList();
    final newState = AppUsageFilterState(
      tags: _currentState.tags,
      showNoTagsFilter: _currentState.showNoTagsFilter,
      startDate: _currentState.startDate,
      endDate: _currentState.endDate,
      devices: selectedValues.isEmpty ? null : selectedValues,
      showComparison: _currentState.showComparison,
      sortConfig: _currentState.sortConfig,
    );

    if (mounted) {
      setState(() => _currentState = newState);
    }

    widget.onFiltersChanged(newState);
    handleFilterChange();
  }

  void _handleSortChange(SortConfig<AppUsageSortFields>? sortConfig) {
    setState(() {
      _currentState = _currentState.copyWith(sortConfig: sortConfig);
    });
    widget.onFiltersChanged(_currentState);
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
                ? _themeService.primaryColor
                : Colors.grey,
            tooltip: _translationService.translate(AppUsageTranslationKeys.filterTagsButton),
          ),

          // Device Filter
          DeviceSelectDropdown(
            isMultiSelect: true,
            initialSelectedDevices: _currentState.devices
                    ?.map(
                      (device) => DropdownOption(value: device, label: device),
                    )
                    .toList() ??
                [],
            onDevicesSelected: _handleDeviceSelect,
            showLength: true,
            showNoneOption: false,
            initialNoneSelected: false,
            icon: Icons.devices,
            iconSize: AppTheme.iconSizeMedium,
            color: (_currentState.devices?.isNotEmpty ?? false) ? _themeService.primaryColor : Colors.grey,
            tooltip: _translationService.translate(AppUsageTranslationKeys.filterDevicesButton),
          ),

          // Date Range Filter
          DateRangeFilter(
            selectedStartDate: _currentState.dateFilterSetting != null ? _currentState.startDate : null,
            selectedEndDate: _currentState.dateFilterSetting != null ? _currentState.endDate : null,
            dateFilterSetting: _currentState.dateFilterSetting,
            onDateFilterChange: _handleDateChange,
            onDateFilterSettingChange: _handleDateSettingChange,
          ),

          // Comparison Toggle
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            color: _currentState.showComparison ? _themeService.primaryColor : Colors.grey,
            tooltip: _translationService.translate(SharedTranslationKeys.compareWithPreviousLabel),
            onPressed: () {
              final newState = _currentState.copyWith(
                showComparison: !_currentState.showComparison,
              );
              if (mounted) {
                setState(() => _currentState = newState);
              }
              widget.onFiltersChanged(newState);
              handleFilterChange();
            },
          ),

          // Use Tag Color For Bars Toggle
          IconButton(
            icon: const Icon(Icons.palette),
            color: _currentState.useTagColorForBars ? _themeService.primaryColor : Colors.grey,
            tooltip: _translationService.translate(AppUsageTranslationKeys.useTagColorForBarsTooltip),
            onPressed: () {
              final newState = _currentState.copyWith(
                useTagColorForBars: !_currentState.useTagColorForBars,
              );
              if (mounted) {
                setState(() => _currentState = newState);
              }
              widget.onFiltersChanged(newState);
              handleFilterChange();
            },
          ),

          // Sort Button
          SortDialogButton<AppUsageSortFields>(
            tooltip: _translationService.translate(SharedTranslationKeys.sort),
            availableOptions: [
              SortOptionWithTranslationKey(
                field: AppUsageSortFields.name,
                translationKey: AppUsageTranslationKeys.sortName,
              ),
              SortOptionWithTranslationKey(
                field: AppUsageSortFields.duration,
                translationKey: AppUsageTranslationKeys.sortDuration,
              ),
              SortOptionWithTranslationKey(
                field: AppUsageSortFields.device,
                translationKey: AppUsageTranslationKeys.sortDevice,
              ),
            ],
            config: _currentState.sortConfig ??
                SortConfig(
                  orderOptions: [
                    SortOptionWithTranslationKey(
                      field: AppUsageSortFields.duration,
                      translationKey: AppUsageTranslationKeys.sortDuration,
                      direction: SortDirection.desc,
                    ),
                  ],
                ),
            defaultConfig: SortConfig(
              orderOptions: [
                SortOptionWithTranslationKey(
                  field: AppUsageSortFields.duration,
                  translationKey: AppUsageTranslationKeys.sortDuration,
                  direction: SortDirection.desc,
                ),
              ],
              enableGrouping: false,
            ),
            onConfigChanged: _handleSortChange,
          ),

          // Group Button
          GroupDialogButton<AppUsageSortFields>(
            iconColor: _themeService.primaryColor,
            tooltip: _translationService.translate(SharedTranslationKeys.sortEnableGrouping),
            config: _currentState.sortConfig ??
                SortConfig(
                  orderOptions: [
                    SortOptionWithTranslationKey(
                      field: AppUsageSortFields.duration,
                      translationKey: AppUsageTranslationKeys.sortDuration,
                      direction: SortDirection.desc,
                    ),
                  ],
                ),
            onConfigChanged: _handleSortChange,
            availableOptions: [
              SortOptionWithTranslationKey(
                field: AppUsageSortFields.name,
                translationKey: AppUsageTranslationKeys.sortName,
              ),
              SortOptionWithTranslationKey(
                field: AppUsageSortFields.device,
                translationKey: AppUsageTranslationKeys.sortDevice,
              ),
              SortOptionWithTranslationKey(
                field: AppUsageSortFields.duration,
                translationKey: AppUsageTranslationKeys.sortDuration,
              ),
            ],
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
