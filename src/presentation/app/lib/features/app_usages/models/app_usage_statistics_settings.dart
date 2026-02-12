import 'package:whph/shared/models/date_filter_setting.dart';

class AppUsageStatisticsSettings {
  final DateFilterSetting? dateFilterSetting;
  final bool showComparison;

  const AppUsageStatisticsSettings({
    this.dateFilterSetting,
    this.showComparison = false,
  });

  factory AppUsageStatisticsSettings.fromJson(Map<String, dynamic> json) {
    return AppUsageStatisticsSettings(
      dateFilterSetting: json['dateFilterSetting'] != null
          ? DateFilterSetting.fromJson(json['dateFilterSetting'] as Map<String, dynamic>)
          : null,
      showComparison: json['showComparison'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateFilterSetting': dateFilterSetting?.toJson(),
      'showComparison': showComparison,
    };
  }
}
