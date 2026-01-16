import 'package:acore/acore.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/core/application/features/habits/models/habit_sort_fields.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/features/habits/models/habit_list_style.dart';

/// Model for storing habit filter and sort settings
class HabitListOptionSettings {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Flag to indicate if archived habits should be shown
  final bool filterByArchived;

  /// Search query
  final String? search;

  /// Current sort configuration
  final SortConfig<HabitSortFields>? sortConfig;

  /// Whether to force the original layout even with custom sort
  final bool forceOriginalLayout;

  /// Current habit list style
  final HabitListStyle habitListStyle;

  /// Default constructor
  HabitListOptionSettings({
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.filterByArchived = false,
    this.search,
    this.sortConfig,
    this.forceOriginalLayout = false,
    this.habitListStyle = HabitListStyle.grid,
  });

  /// Create settings from a JSON map
  factory HabitListOptionSettings.fromJson(Map<String, dynamic> json) {
    // Handle sort config
    SortConfig<HabitSortFields>? sortConfig;
    if (json['sortConfig'] != null) {
      final Map<String, dynamic> sortConfigJson =
          json['sortConfig'] as Map<String, dynamic>;

      final List<dynamic> orderOptionsJson =
          sortConfigJson['orderOptions'] as List<dynamic>;
      final List<SortOptionWithTranslationKey<HabitSortFields>> orderOptions =
          orderOptionsJson.map((option) {
        final Map<String, dynamic> optionMap = option as Map<String, dynamic>;
        return SortOptionWithTranslationKey<HabitSortFields>(
          field: _stringToHabitSortField(optionMap['field'] as String),
          direction: optionMap['direction'] == 'asc'
              ? SortDirection.asc
              : SortDirection.desc,
          translationKey: optionMap['translationKey'] as String,
        );
      }).toList();

      SortOptionWithTranslationKey<HabitSortFields>? groupOption;
      if (sortConfigJson['groupOption'] != null) {
        final Map<String, dynamic> groupOptionMap =
            sortConfigJson['groupOption'] as Map<String, dynamic>;
        groupOption = SortOptionWithTranslationKey<HabitSortFields>(
          field: _stringToHabitSortField(groupOptionMap['field'] as String),
          direction: groupOptionMap['direction'] == 'asc'
              ? SortDirection.asc
              : SortDirection.desc,
          translationKey: groupOptionMap['translationKey'] as String,
        );
      }

      sortConfig = SortConfig<HabitSortFields>(
        orderOptions: orderOptions,
        useCustomOrder: sortConfigJson['useCustomOrder'] as bool? ?? false,
        customTagSortOrder: sortConfigJson['customTagSortOrder'] != null
            ? List<String>.from(
                sortConfigJson['customTagSortOrder'] as List<dynamic>)
            : null,
        enableGrouping: sortConfigJson['enableGrouping'] as bool? ?? false,
        groupOption: groupOption,
      );
    }

    // Handle habit list style
    HabitListStyle habitListStyle = HabitListStyle.grid;
    if (json['habitListStyle'] != null) {
      try {
        habitListStyle = HabitListStyle.values.firstWhere(
          (e) => e.name == json['habitListStyle'],
          orElse: () => HabitListStyle.grid,
        );
      } catch (_) {
        habitListStyle = HabitListStyle.grid;
      }
    }

    return HabitListOptionSettings(
      selectedTagIds: json['selectedTagIds'] != null
          ? List<String>.from(json['selectedTagIds'] as List<dynamic>)
          : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
      filterByArchived: json['filterByArchived'] as bool? ?? false,
      search: json['search'] as String?,
      sortConfig: sortConfig,
      forceOriginalLayout: json['forceOriginalLayout'] as bool? ?? false,
      habitListStyle: habitListStyle,
    );
  }

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'showNoTagsFilter': showNoTagsFilter,
      'filterByArchived': filterByArchived,
      'search': search, // Always include search, even if null
      'forceOriginalLayout': forceOriginalLayout,
      'habitListStyle': habitListStyle.toString().split('.').last,
    };

    if (selectedTagIds != null) {
      json['selectedTagIds'] = selectedTagIds;
    }

    if (sortConfig != null) {
      json['sortConfig'] = {
        'orderOptions': sortConfig!.orderOptions
            .map((option) => {
                  'field': option.field.toString().split('.').last,
                  'direction':
                      option.direction == SortDirection.asc ? 'asc' : 'desc',
                  'translationKey': option.translationKey,
                })
            .toList(),
        'useCustomOrder': sortConfig!.useCustomOrder,
        'customTagSortOrder': sortConfig!.customTagSortOrder,
        'enableGrouping': sortConfig!.enableGrouping,
        'groupOption': sortConfig!.groupOption != null
            ? {
                'field':
                    sortConfig!.groupOption!.field.toString().split('.').last,
                'direction':
                    sortConfig!.groupOption!.direction == SortDirection.asc
                        ? 'asc'
                        : 'desc',
                'translationKey': sortConfig!.groupOption!.translationKey,
              }
            : null,
      };
    }

    return json;
  }

  /// Helper method to convert string to HabitSortFields enum
  static HabitSortFields _stringToHabitSortField(String fieldString) {
    switch (fieldString) {
      case 'name':
        return HabitSortFields.name;
      case 'createdDate':
        return HabitSortFields.createdDate;
      case 'modifiedDate':
        return HabitSortFields.modifiedDate;
      case 'archivedDate':
        return HabitSortFields.archivedDate;
      case 'estimatedTime':
        return HabitSortFields.estimatedTime;
      case 'actualTime':
        return HabitSortFields.actualTime;
      case 'tag':
        return HabitSortFields.tag;
      default:
        return HabitSortFields.createdDate;
    }
  }
}
