import 'package:whph/src/presentation/ui/shared/models/date_filter_setting.dart';

class AppUsageFilterSettings {
  /// Selected tag IDs for filtering
  final List<String>? tags;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Date filter setting with support for quick selections
  final DateFilterSetting? dateFilterSetting;

  /// Start date for filtering (deprecated - use dateFilterSetting)
  final DateTime startDate;

  /// End date for filtering (deprecated - use dateFilterSetting)
  final DateTime endDate;

  /// Selected device names for filtering
  final List<String>? devices;

  /// Default constructor
  AppUsageFilterSettings({
    this.tags,
    this.showNoTagsFilter = false,
    this.dateFilterSetting,
    required this.startDate,
    required this.endDate,
    this.devices,
  });

  /// Create settings from a JSON map
  factory AppUsageFilterSettings.fromJson(Map<String, dynamic> json) {
    // Handle new date filter setting
    DateFilterSetting? dateFilterSetting;
    if (json['dateFilterSetting'] != null) {
      dateFilterSetting = DateFilterSetting.fromJson(
        json['dateFilterSetting'] as Map<String, dynamic>,
      );
    }

    // Handle legacy dates for backward compatibility
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

    final finalStartDate = startDate ?? defaultStart;
    final finalEndDate = endDate ?? defaultEnd;

    // If we have legacy dates but no new format, create DateFilterSetting from legacy data
    if (dateFilterSetting == null && (startDate != null || endDate != null)) {
      dateFilterSetting = DateFilterSetting.manual(
        startDate: finalStartDate,
        endDate: finalEndDate,
      );
    }

    return AppUsageFilterSettings(
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List<dynamic>) : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
      dateFilterSetting: dateFilterSetting,
      startDate: finalStartDate,
      endDate: finalEndDate,
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

    // Use new date filter setting format
    if (dateFilterSetting != null) {
      json['dateFilterSetting'] = dateFilterSetting!.toJson();
    }

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
    DateFilterSetting? dateFilterSetting,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? devices,
  }) {
    return AppUsageFilterSettings(
      tags: tags ?? this.tags,
      showNoTagsFilter: showNoTagsFilter ?? this.showNoTagsFilter,
      dateFilterSetting: dateFilterSetting ?? this.dateFilterSetting,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      devices: devices ?? this.devices,
    );
  }
}
