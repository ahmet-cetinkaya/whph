import 'package:whph/corePackages/acore/repository/models/sort_direction.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/src/core/application/features/notes/queries/get_list_notes_query.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_option_with_translation_key.dart';

/// Model for storing note filter and sort settings
class NoteListOptionSettings {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Search query
  final String? search;

  /// Current sort configuration
  final SortConfig<NoteSortFields>? sortConfig;

  /// Default constructor
  NoteListOptionSettings({
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.search,
    this.sortConfig,
  });

  /// Create settings from a JSON map
  factory NoteListOptionSettings.fromJson(Map<String, dynamic> json) {
    // Handle sort config
    SortConfig<NoteSortFields>? sortConfig;
    if (json['sortConfig'] != null) {
      final Map<String, dynamic> sortConfigJson = json['sortConfig'] as Map<String, dynamic>;

      final List<dynamic> orderOptionsJson = sortConfigJson['orderOptions'] as List<dynamic>;
      final List<SortOptionWithTranslationKey<NoteSortFields>> orderOptions = orderOptionsJson.map((option) {
        final Map<String, dynamic> optionMap = option as Map<String, dynamic>;
        return SortOptionWithTranslationKey<NoteSortFields>(
          field: _stringToNoteSortField(optionMap['field'] as String),
          direction: optionMap['direction'] == 'asc' ? SortDirection.asc : SortDirection.desc,
          translationKey: optionMap['translationKey'] as String,
        );
      }).toList();

      sortConfig = SortConfig<NoteSortFields>(
        orderOptions: orderOptions,
        useCustomOrder: sortConfigJson['useCustomOrder'] as bool? ?? false,
      );
    }

    return NoteListOptionSettings(
      selectedTagIds:
          json['selectedTagIds'] != null ? List<String>.from(json['selectedTagIds'] as List<dynamic>) : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
      search: json['search'] as String?,
      sortConfig: sortConfig,
    );
  }

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'showNoTagsFilter': showNoTagsFilter,
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
      };
    }

    return json;
  }

  /// Helper method to convert string to NoteSortFields enum
  static NoteSortFields _stringToNoteSortField(String fieldString) {
    switch (fieldString) {
      case 'title':
        return NoteSortFields.title;
      case 'createdDate':
        return NoteSortFields.createdDate;
      case 'modifiedDate':
        return NoteSortFields.modifiedDate;
      default:
        return NoteSortFields.createdDate;
    }
  }
}
