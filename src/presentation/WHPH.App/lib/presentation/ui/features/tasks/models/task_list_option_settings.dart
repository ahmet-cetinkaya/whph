import 'package:acore/acore.dart';
import 'package:whph/core/application/features/tasks/models/task_sort_fields.dart';
import 'package:whph/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/presentation/ui/shared/models/sort_option_with_translation_key.dart';
import 'package:whph/presentation/ui/shared/models/date_filter_setting.dart';

/// Model for storing task filter and sort settings
class TaskListOptionSettings {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Date filter setting with support for quick selections
  final DateFilterSetting? dateFilterSetting;

  /// Selected start date for filtering (deprecated - use dateFilterSetting)
  final DateTime? selectedStartDate;

  /// Selected end date for filtering (deprecated - use dateFilterSetting)
  final DateTime? selectedEndDate;

  /// Search query
  final String? search;

  /// Show completed tasks toggle
  final bool showCompletedTasks;

  /// Current sort configuration
  final SortConfig<TaskSortFields>? sortConfig;

  /// Whether to force the original layout even with custom sort
  final bool forceOriginalLayout;

  /// Show subtasks toggle
  final bool showSubTasks;

  /// Default constructor
  TaskListOptionSettings({
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.dateFilterSetting,
    this.selectedStartDate,
    this.selectedEndDate,
    this.search,
    this.showCompletedTasks = false,
    this.sortConfig,
    this.forceOriginalLayout = false,
    this.showSubTasks = false,
  });

  /// Create settings from a JSON map
  factory TaskListOptionSettings.fromJson(Map<String, dynamic> json) {
    // Handle new date filter setting
    DateFilterSetting? dateFilterSetting;
    if (json['dateFilterSetting'] != null) {
      dateFilterSetting = DateFilterSetting.fromJson(
        json['dateFilterSetting'] as Map<String, dynamic>,
      );
    }

    // Handle legacy dates for backward compatibility
    DateTime? startDate;
    if (json['selectedStartDate'] != null) {
      startDate = DateTime.tryParse(json['selectedStartDate'] as String);
    }

    DateTime? endDate;
    if (json['selectedEndDate'] != null) {
      endDate = DateTime.tryParse(json['selectedEndDate'] as String);
    }

    // If we have legacy dates but no new format, create DateFilterSetting from legacy data
    if (dateFilterSetting == null && (startDate != null || endDate != null)) {
      dateFilterSetting = DateFilterSetting.manual(
        startDate: startDate,
        endDate: endDate,
      );
    }

    // Handle sort config
    SortConfig<TaskSortFields>? sortConfig;
    if (json['sortConfig'] != null) {
      final Map<String, dynamic> sortConfigJson = json['sortConfig'] as Map<String, dynamic>;

      final List<dynamic> orderOptionsJson = sortConfigJson['orderOptions'] as List<dynamic>;
      final List<SortOptionWithTranslationKey<TaskSortFields>> orderOptions = orderOptionsJson.map((option) {
        final Map<String, dynamic> optionMap = option as Map<String, dynamic>;
        return SortOptionWithTranslationKey<TaskSortFields>(
          field: _stringToTaskSortField(optionMap['field'] as String),
          direction: optionMap['direction'] == 'asc' ? SortDirection.asc : SortDirection.desc,
          translationKey: optionMap['translationKey'] as String,
        );
      }).toList();

      SortOptionWithTranslationKey<TaskSortFields>? groupOption;
      if (sortConfigJson['groupOption'] != null) {
        final Map<String, dynamic> groupOptionMap = sortConfigJson['groupOption'] as Map<String, dynamic>;
        groupOption = SortOptionWithTranslationKey<TaskSortFields>(
          field: _stringToTaskSortField(groupOptionMap['field'] as String),
          direction: groupOptionMap['direction'] == 'asc' ? SortDirection.asc : SortDirection.desc,
          translationKey: groupOptionMap['translationKey'] as String,
        );
      }

      sortConfig = SortConfig<TaskSortFields>(
        orderOptions: orderOptions,
        useCustomOrder: sortConfigJson['useCustomOrder'] as bool? ?? false,
        customTagSortOrder: sortConfigJson['customTagSortOrder'] != null
            ? List<String>.from(sortConfigJson['customTagSortOrder'] as List<dynamic>)
            : null,
        enableGrouping: sortConfigJson['enableGrouping'] as bool? ?? false,
        groupOption: groupOption,
      );
    }

    return TaskListOptionSettings(
      selectedTagIds:
          json['selectedTagIds'] != null ? List<String>.from(json['selectedTagIds'] as List<dynamic>) : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
      dateFilterSetting: dateFilterSetting,
      selectedStartDate: startDate,
      selectedEndDate: endDate,
      search: json['search'] as String?,
      showCompletedTasks: json['showCompletedTasks'] as bool? ?? false,
      sortConfig: sortConfig,
      forceOriginalLayout: json['forceOriginalLayout'] as bool? ?? false,
      showSubTasks: json['showSubTasks'] as bool? ?? false,
    );
  }

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'showNoTagsFilter': showNoTagsFilter,
      'showCompletedTasks': showCompletedTasks,
      'search': search, // Always include search, even if null
      'forceOriginalLayout': forceOriginalLayout,
      'showSubTasks': showSubTasks,
    };

    if (selectedTagIds != null) {
      json['selectedTagIds'] = selectedTagIds;
    }

    // Use new date filter setting format
    if (dateFilterSetting != null) {
      json['dateFilterSetting'] = dateFilterSetting!.toJson();
    }

    // Keep legacy format for backward compatibility
    if (selectedStartDate != null) {
      json['selectedStartDate'] = selectedStartDate!.toIso8601String();
    }

    if (selectedEndDate != null) {
      json['selectedEndDate'] = selectedEndDate!.toIso8601String();
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
        'customTagSortOrder': sortConfig!.customTagSortOrder,
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

  /// Helper method to convert string to TaskSortFields enum
  static TaskSortFields _stringToTaskSortField(String fieldString) {
    switch (fieldString) {
      case 'title':
        return TaskSortFields.title;
      case 'priority':
        return TaskSortFields.priority;
      case 'plannedDate':
        return TaskSortFields.plannedDate;
      case 'deadlineDate':
        return TaskSortFields.deadlineDate;
      case 'estimatedTime':
        return TaskSortFields.estimatedTime;
      case 'totalDuration':
        return TaskSortFields.totalDuration;
      case 'createdDate':
        return TaskSortFields.createdDate;
      case 'modifiedDate':
        return TaskSortFields.modifiedDate;
      case 'tag':
        return TaskSortFields.tag;
      default:
        return TaskSortFields.createdDate;
    }
  }
}
