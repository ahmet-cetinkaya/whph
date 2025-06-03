import 'package:whph/src/core/application/features/tags/models/tag_time_category.dart';

class TagTimeChartOptionSettings {
  /// Selected start date for filtering
  final DateTime? selectedStartDate;

  /// Selected end date for filtering
  final DateTime? selectedEndDate;

  /// Selected categories for filtering
  final List<TagTimeCategory> selectedCategories;

  const TagTimeChartOptionSettings({
    this.selectedStartDate,
    this.selectedEndDate,
    this.selectedCategories = const [TagTimeCategory.all],
  });

  Map<String, dynamic> toJson() {
    return {
      'selectedStartDate': selectedStartDate?.toIso8601String(),
      'selectedEndDate': selectedEndDate?.toIso8601String(),
      'selectedCategories': selectedCategories.map((e) => e.index).toList(),
    };
  }

  factory TagTimeChartOptionSettings.fromJson(Map<String, dynamic> json) {
    final selectedCategoriesIndices = List<int>.from(json['selectedCategories'] ?? []);
    final selectedCategories = selectedCategoriesIndices.isEmpty
        ? [TagTimeCategory.all]
        : selectedCategoriesIndices.map((index) {
            if (index >= 0 && index < TagTimeCategory.values.length) {
              return TagTimeCategory.values[index];
            } else {
              return TagTimeCategory.all;
            }
          }).toList();

    return TagTimeChartOptionSettings(
      selectedStartDate: json['selectedStartDate'] != null ? DateTime.parse(json['selectedStartDate']) : null,
      selectedEndDate: json['selectedEndDate'] != null ? DateTime.parse(json['selectedEndDate']) : null,
      selectedCategories: selectedCategories,
    );
  }
}
