import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/core/application/features/app_usages/models/app_usage_sort_fields.dart';

class AppUsageFilterSettings {
  /// Selected tag IDs for filtering
  final List<String>? tags;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Date filter setting with support for quick selections
  final DateFilterSetting? dateFilterSetting;

  /// Start date for filtering (deprecated - use dateFilterSetting)
  final DateTime? startDate;

  /// End date for filtering (deprecated - use dateFilterSetting)
  final DateTime? endDate;

  /// Selected device names for filtering
  final List<String>? devices;

  /// Flag to indicate if comparison with previous period should be shown
  final bool showComparison;

  /// Current sort configuration
  final SortConfig<AppUsageSortFields>? sortConfig;

  /// Default constructor
  AppUsageFilterSettings({
    this.tags,
    this.showNoTagsFilter = false,
    this.dateFilterSetting,
    this.startDate,
    this.endDate,
    this.devices,
    this.showComparison = false,
    this.sortConfig,
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

    // If we have legacy dates but no new format, create DateFilterSetting from legacy data
    if (dateFilterSetting == null && (startDate != null && endDate != null)) {
      dateFilterSetting = DateFilterSetting.manual(
        startDate: startDate,
        endDate: endDate,
      );
    }

    return AppUsageFilterSettings(
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List<dynamic>) : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
      dateFilterSetting: dateFilterSetting,
      startDate: startDate,
      endDate: endDate,
      devices: json['devices'] != null ? List<String>.from(json['devices'] as List<dynamic>) : null,
      showComparison: json['showComparison'] as bool? ?? false,
      sortConfig: json['sortConfig'] != null
          ? SortConfig.fromJson(
              json['sortConfig'], (v) => AppUsageSortFields.values.firstWhere((e) => e.toString() == v))
          : null,
    );
  }

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'showNoTagsFilter': showNoTagsFilter,
    };

    if (startDate != null) {
      json['startDate'] = startDate!.toIso8601String();
    }

    if (endDate != null) {
      json['endDate'] = endDate!.toIso8601String();
    }

    // Use new date filter setting format - always include key even if null
    json['dateFilterSetting'] = dateFilterSetting?.toJson();

    if (tags != null) {
      json['tags'] = tags;
    }

    if (devices != null) {
      json['devices'] = devices;
    }

    json['showComparison'] = showComparison;

    if (sortConfig != null) {
      json['sortConfig'] = sortConfig!.toJson((v) => v.toString());
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
    bool? showComparison,
    SortConfig<AppUsageSortFields>? sortConfig,
  }) {
    return AppUsageFilterSettings(
      tags: tags ?? this.tags,
      showNoTagsFilter: showNoTagsFilter ?? this.showNoTagsFilter,
      dateFilterSetting: dateFilterSetting ?? this.dateFilterSetting,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      devices: devices ?? this.devices,
      showComparison: showComparison ?? this.showComparison,
      sortConfig: sortConfig ?? this.sortConfig,
    );
  }
}
