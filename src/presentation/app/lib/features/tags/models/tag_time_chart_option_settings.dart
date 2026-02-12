import 'package:application/features/tags/models/tag_time_category.dart';
import 'package:whph/shared/models/date_filter_setting.dart';

class TagTimeChartOptionSettings {
  /// Date filter setting with support for quick selections
  final DateFilterSetting? dateFilterSetting;

  /// Selected start date for filtering (deprecated - use dateFilterSetting)
  final DateTime? selectedStartDate;

  /// Selected end date for filtering (deprecated - use dateFilterSetting)
  final DateTime? selectedEndDate;

  /// Selected categories for filtering
  final List<TagTimeCategory> selectedCategories;

  const TagTimeChartOptionSettings({
    this.dateFilterSetting,
    this.selectedStartDate,
    this.selectedEndDate,
    this.selectedCategories = const [TagTimeCategory.all],
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {
      'selectedCategories': selectedCategories.map((e) => e.index).toList(),
    };

    // Use new date filter setting format
    if (dateFilterSetting != null) {
      result['dateFilterSetting'] = dateFilterSetting!.toJson();
    }

    // Keep legacy format for backward compatibility
    if (selectedStartDate != null) {
      result['selectedStartDate'] = selectedStartDate!.toIso8601String();
    }
    if (selectedEndDate != null) {
      result['selectedEndDate'] = selectedEndDate!.toIso8601String();
    }

    return result;
  }

  factory TagTimeChartOptionSettings.fromJson(Map<String, dynamic> json) {
    // Safely parse selected categories
    List<int> selectedCategoriesIndices = [];
    if (json['selectedCategories'] is List) {
      selectedCategoriesIndices = List<int>.from(json['selectedCategories'] as List);
    }

    final selectedCategories = selectedCategoriesIndices.isEmpty
        ? [TagTimeCategory.all]
        : selectedCategoriesIndices.map((index) {
            if (index >= 0 && index < TagTimeCategory.values.length) {
              return TagTimeCategory.values[index];
            } else {
              return TagTimeCategory.all;
            }
          }).toList();

    // Handle new date filter setting
    DateFilterSetting? dateFilterSetting;
    if (json['dateFilterSetting'] != null) {
      dateFilterSetting = DateFilterSetting.fromJson(
        json['dateFilterSetting'] as Map<String, dynamic>,
      );
    }

    // Handle legacy dates for backward compatibility
    DateTime? selectedStartDate;
    if (json['selectedStartDate'] is String) {
      selectedStartDate = DateTime.tryParse(json['selectedStartDate'] as String);
    }

    DateTime? selectedEndDate;
    if (json['selectedEndDate'] is String) {
      selectedEndDate = DateTime.tryParse(json['selectedEndDate'] as String);
    }

    // If we have legacy dates but no new format, create DateFilterSetting from legacy data
    if (dateFilterSetting == null && (selectedStartDate != null || selectedEndDate != null)) {
      dateFilterSetting = DateFilterSetting.manual(
        startDate: selectedStartDate,
        endDate: selectedEndDate,
      );
    }

    return TagTimeChartOptionSettings(
      dateFilterSetting: dateFilterSetting,
      selectedStartDate: selectedStartDate,
      selectedEndDate: selectedEndDate,
      selectedCategories: selectedCategories,
    );
  }
}
