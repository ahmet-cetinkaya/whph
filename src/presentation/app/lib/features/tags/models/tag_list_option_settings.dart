import 'package:acore/acore.dart';
import 'package:whph/shared/models/sort_config.dart';
import 'package:application/features/tags/models/tag_sort_fields.dart';
import 'package:whph/shared/models/sort_option_with_translation_key.dart';

/// Model for storing tag filter and sort settings
class TagListOptionSettings {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Flag to indicate if archived tags should be shown
  final bool showArchived;

  /// Search query
  final String? search;

  /// Current sort configuration
  final SortConfig<TagSortFields>? sortConfig;

  /// Default constructor
  TagListOptionSettings({
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.showArchived = false,
    this.search,
    this.sortConfig,
  });

  /// Create settings from a JSON map
  factory TagListOptionSettings.fromJson(Map<String, dynamic> json) {
    // Handle sort config
    SortConfig<TagSortFields>? sortConfig;
    if (json['sortConfig'] != null) {
      final Map<String, dynamic> sortConfigJson = json['sortConfig'] as Map<String, dynamic>;

      final List<dynamic> orderOptionsJson = sortConfigJson['orderOptions'] as List<dynamic>;
      final List<SortOptionWithTranslationKey<TagSortFields>> orderOptions = orderOptionsJson.map((option) {
        final Map<String, dynamic> optionMap = option as Map<String, dynamic>;
        return SortOptionWithTranslationKey<TagSortFields>(
          field: _stringToTagSortField(optionMap['field'] as String),
          direction: optionMap['direction'] == 'asc' ? SortDirection.asc : SortDirection.desc,
          translationKey: optionMap['translationKey'] as String,
        );
      }).toList();

      SortOptionWithTranslationKey<TagSortFields>? groupOption;
      if (sortConfigJson['groupOption'] != null) {
        final Map<String, dynamic> groupOptionMap = sortConfigJson['groupOption'] as Map<String, dynamic>;
        groupOption = SortOptionWithTranslationKey<TagSortFields>(
          field: _stringToTagSortField(groupOptionMap['field'] as String),
          direction: groupOptionMap['direction'] == 'asc' ? SortDirection.asc : SortDirection.desc,
          translationKey: groupOptionMap['translationKey'] as String,
        );
      }

      sortConfig = SortConfig<TagSortFields>(
        orderOptions: orderOptions,
        useCustomOrder: sortConfigJson['useCustomOrder'] as bool? ?? false,
        enableGrouping: sortConfigJson['enableGrouping'] as bool? ?? false,
        groupOption: groupOption,
      );
    }

    return TagListOptionSettings(
      selectedTagIds:
          json['selectedTagIds'] != null ? List<String>.from(json['selectedTagIds'] as List<dynamic>) : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
      showArchived: json['showArchived'] as bool? ?? false,
      search: json['search'] as String?,
      sortConfig: sortConfig,
    );
  }

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'showNoTagsFilter': showNoTagsFilter,
      'showArchived': showArchived,
      'search': search, // Always include search, even if null
    };

    if (selectedTagIds != null) {
      json['selectedTagIds'] = selectedTagIds;
    }

    if (sortConfig != null) {
      json['sortConfig'] = {
        'orderOptions': sortConfig!.orderOptions
            .map((option) => {
                  'field': option.field.toString().split('.').last,
                  'direction': option.direction == SortDirection.asc ? 'asc' : 'desc',
                  'translationKey': option.translationKey,
                })
            .toList(),
        'useCustomOrder': sortConfig!.useCustomOrder,
        'enableGrouping': sortConfig!.enableGrouping,
        'groupOption': sortConfig!.groupOption != null
            ? {
                'field': sortConfig!.groupOption!.field.toString().split('.').last,
                'direction': sortConfig!.groupOption!.direction == SortDirection.asc ? 'asc' : 'desc',
                'translationKey': sortConfig!.groupOption!.translationKey,
              }
            : null,
      };
    }

    return json;
  }

  /// Helper method to convert string to TagSortFields enum
  static TagSortFields _stringToTagSortField(String fieldString) {
    switch (fieldString) {
      case 'name':
        return TagSortFields.name;
      case 'createdDate':
        return TagSortFields.createdDate;
      case 'modifiedDate':
        return TagSortFields.modifiedDate;
      default:
        return TagSortFields.name;
    }
  }
}
