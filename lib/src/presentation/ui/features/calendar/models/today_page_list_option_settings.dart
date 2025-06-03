/// Settings model for TodayPageListOptions
class TodayPageListOptionSettings {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Default constructor
  TodayPageListOptionSettings({
    this.selectedTagIds,
    this.showNoTagsFilter = false,
  });

  /// Create settings from a JSON map
  factory TodayPageListOptionSettings.fromJson(Map<String, dynamic> json) {
    return TodayPageListOptionSettings(
      selectedTagIds:
          json['selectedTagIds'] != null ? List<String>.from(json['selectedTagIds'] as List<dynamic>) : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
    );
  }

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'showNoTagsFilter': showNoTagsFilter,
    };

    if (selectedTagIds != null) {
      json['selectedTagIds'] = selectedTagIds;
    }

    return json;
  }
}
