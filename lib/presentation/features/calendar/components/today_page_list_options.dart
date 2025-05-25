import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mediatr/mediatr.dart';
import 'package:whph/application/features/tags/queries/get_list_tags_query.dart';
import 'package:whph/presentation/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/shared/constants/setting_keys.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/features/tags/constants/tag_translation_keys.dart';
import 'package:whph/presentation/shared/components/persistent_list_options_base.dart';
import 'package:whph/presentation/shared/components/save_button.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/features/calendar/models/today_page_list_option_settings.dart';

class TodayPageListOptions extends PersistentListOptionsBase {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Callback when tag filter changes
  final Function(List<String>?, bool)? onFilterChange;

  const TodayPageListOptions({
    super.key,
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.onFilterChange,
    super.onSettingsLoaded,
    super.showSaveButton = true,
    super.hasUnsavedChanges = false,
    super.settingKeyVariantSuffix,
  });

  @override
  State<TodayPageListOptions> createState() => _TodayPageListOptionsState();
}

class _TodayPageListOptionsState extends PersistentListOptionsBaseState<TodayPageListOptions> {
  final Mediator _mediator = container.resolve<Mediator>();
  final ITranslationService _translationService = container.resolve<ITranslationService>();

  @override
  void initSettingKey() {
    settingKey = widget.settingKeyVariantSuffix != null
        ? "${SettingKeys.todayPageListOptionsSettings}_${widget.settingKeyVariantSuffix}"
        : SettingKeys.todayPageListOptionsSettings;
  }

  @override
  Future<void> loadSavedListOptionSettings() async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.loadingError),
      operation: () async {
        final savedSettings = await filterSettingsManager.loadFilterSettings(
          settingKey: settingKey,
        );

        if (savedSettings != null && mounted) {
          final filterSettings = TodayPageListOptionSettings.fromJson(savedSettings);

          if (filterSettings.selectedTagIds != null && filterSettings.selectedTagIds!.isNotEmpty) {
            // Fetch actual tag data to populate the dropdown
            final query = GetListTagsQuery(
              pageIndex: 0,
              pageSize: filterSettings.selectedTagIds!.length,
              filterByTags: filterSettings.selectedTagIds!,
            );

            final tagResult = await _mediator.send<GetListTagsQuery, GetListTagsQueryResponse>(query);

            // Only update if we have valid tags
            if (tagResult.items.isNotEmpty) {
              widget.onFilterChange?.call(filterSettings.selectedTagIds, filterSettings.showNoTagsFilter);
            }
          } else if (filterSettings.showNoTagsFilter) {
            // Handle "None" filter case
            widget.onFilterChange?.call(null, true);
          }
        }

        if (mounted) {
          setState(() {
            isSettingLoaded = true;
          });
        }

        widget.onSettingsLoaded?.call();
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
  Future<void> handleFilterChange() async {
    if (!mounted) return;

    setState(() {
      hasUnsavedChanges = true;
    });
    await checkForUnsavedChanges();
  }

  @override
  Future<void> saveFilterSettings() async {
    await AsyncErrorHandler.executeVoid(
      context: context,
      errorMessage: _translationService.translate(SharedTranslationKeys.savingError),
      operation: () async {
        final settings = TodayPageListOptionSettings(
          selectedTagIds: widget.selectedTagIds,
          showNoTagsFilter: widget.showNoTagsFilter,
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
    if (!mounted) return;

    try {
      final savedSettings = await filterSettingsManager.loadFilterSettings(
        settingKey: settingKey,
      );

      final currentSettings = TodayPageListOptionSettings(
        selectedTagIds: widget.selectedTagIds,
        showNoTagsFilter: widget.showNoTagsFilter,
      ).toJson();

      bool hasChanges;
      if (savedSettings == null) {
        // If there are no saved settings, check if we have any active filters
        hasChanges = widget.selectedTagIds?.isNotEmpty == true || widget.showNoTagsFilter;
      } else {
        // Compare current settings with saved settings
        hasChanges = savedSettings['selectedTagIds']?.toString() != currentSettings['selectedTagIds']?.toString() ||
            savedSettings['showNoTagsFilter'] != currentSettings['showNoTagsFilter'];
      }

      if (mounted && hasChanges != hasUnsavedChanges) {
        setState(() {
          hasUnsavedChanges = hasChanges;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  bool _hasFilterChanges(TodayPageListOptions oldWidget) {
    return widget.selectedTagIds != oldWidget.selectedTagIds || widget.showNoTagsFilter != oldWidget.showNoTagsFilter;
  }

  @override
  void didUpdateWidget(TodayPageListOptions oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_hasFilterChanges(oldWidget)) {
      Future.microtask(handleFilterChange);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isSettingLoaded) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Tag Filter
                TagSelectDropdown(
                  isMultiSelect: true,
                  showNoneOption: true,
                  initialNoneSelected: widget.showNoTagsFilter,
                  icon: TagUiConstants.tagIcon,
                  iconSize: AppTheme.iconSizeMedium,
                  color: widget.showNoTagsFilter || (widget.selectedTagIds?.isNotEmpty ?? false)
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  tooltip: _translationService.translate(TagTranslationKeys.selectTooltip),
                  onTagsSelected: (selectedTags, isNoneSelected) {
                    final newTags = selectedTags.map((t) => t.value).toList();
                    widget.onFilterChange?.call(newTags, isNoneSelected);
                    setState(() {
                      hasUnsavedChanges = true;
                    });
                    handleFilterChange();
                  },
                  initialSelectedTags: widget.selectedTagIds != null
                      ? widget.selectedTagIds!.map((id) => DropdownOption(value: id, label: '')).toList()
                      : [],
                  showLength: true,
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
        ),
      ],
    );
  }
}
