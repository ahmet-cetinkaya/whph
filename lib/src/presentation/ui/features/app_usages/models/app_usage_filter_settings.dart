class AppUsageFilterSettings {
  /// Selected tag IDs for filtering
  final List<String>? tags;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Start date for filtering
  final DateTime startDate;

  /// End date for filtering
  final DateTime endDate;

  /// Selected device names for filtering
  final List<String>? devices;

  /// Default constructor
  AppUsageFilterSettings({
    this.tags,
    this.showNoTagsFilter = false,
    required this.startDate,
    required this.endDate,
    this.devices,
  });

  /// Create settings from a JSON map
  factory AppUsageFilterSettings.fromJson(Map<String, dynamic> json) {
    // Handle dates
    DateTime? startDate;
    if (json['startDate'] != null) {
      startDate = DateTime.tryParse(json['startDate'] as String);
    }

    DateTime? endDate;
    if (json['endDate'] != null) {
      endDate = DateTime.tryParse(json['endDate'] as String);
    }

    // Default to current date if dates are invalid
    final now = DateTime.now();
    final defaultEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final defaultStart = defaultEnd.subtract(const Duration(days: 7));

    return AppUsageFilterSettings(
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List<dynamic>) : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
      startDate: startDate ?? defaultStart,
      endDate: endDate ?? defaultEnd,
      devices: json['devices'] != null ? List<String>.from(json['devices'] as List<dynamic>) : null,
    );
  }

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'showNoTagsFilter': showNoTagsFilter,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    if (tags != null) {
      json['tags'] = tags;
    }

    if (devices != null) {
      json['devices'] = devices;
    }

    return json;
  }

  /// Create a copy with some fields replaced
  AppUsageFilterSettings copyWith({
    List<String>? tags,
    bool? showNoTagsFilter,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? devices,
  }) {
    return AppUsageFilterSettings(
      tags: tags ?? this.tags,
      showNoTagsFilter: showNoTagsFilter ?? this.showNoTagsFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      devices: devices ?? this.devices,
    );
  }
}
