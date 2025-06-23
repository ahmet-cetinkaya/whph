import 'package:acore/acore.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_config.dart';
import 'package:whph/src/core/application/features/tasks/queries/get_list_tasks_query.dart';
import 'package:whph/src/presentation/ui/shared/models/sort_option_with_translation_key.dart';

/// Model for storing task filter and sort settings
class TaskListOptionSettings {
  /// Selected tag IDs for filtering
  final List<String>? selectedTagIds;

  /// Flag to indicate if "None" (no tags) filter is selected
  final bool showNoTagsFilter;

  /// Selected start date for filtering
  final DateTime? selectedStartDate;

  /// Selected end date for filtering
  final DateTime? selectedEndDate;

  /// Search query
  final String? search;

  /// Show completed tasks toggle
  final bool showCompletedTasks;

  /// Current sort configuration
  final SortConfig<TaskSortFields>? sortConfig;

  /// Default constructor
  TaskListOptionSettings({
    this.selectedTagIds,
    this.showNoTagsFilter = false,
    this.selectedStartDate,
    this.selectedEndDate,
    this.search,
    this.showCompletedTasks = false,
    this.sortConfig,
  });

  /// Create settings from a JSON map
  factory TaskListOptionSettings.fromJson(Map<String, dynamic> json) {
    // Handle dates
    DateTime? startDate;
    if (json['selectedStartDate'] != null) {
      startDate = DateTime.tryParse(json['selectedStartDate'] as String);
    }

    DateTime? endDate;
    if (json['selectedEndDate'] != null) {
      endDate = DateTime.tryParse(json['selectedEndDate'] as String);
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

      sortConfig = SortConfig<TaskSortFields>(
        orderOptions: orderOptions,
        useCustomOrder: sortConfigJson['useCustomOrder'] as bool? ?? false,
      );
    }

    return TaskListOptionSettings(
      selectedTagIds:
          json['selectedTagIds'] != null ? List<String>.from(json['selectedTagIds'] as List<dynamic>) : null,
      showNoTagsFilter: json['showNoTagsFilter'] as bool? ?? false,
      selectedStartDate: startDate,
      selectedEndDate: endDate,
      search: json['search'] as String?,
      showCompletedTasks: json['showCompletedTasks'] as bool? ?? false,
      sortConfig: sortConfig,
    );
  }

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'showNoTagsFilter': showNoTagsFilter,
      'showCompletedTasks': showCompletedTasks,
      'search': search, // Always include search, even if null
    };

    if (selectedTagIds != null) {
      json['selectedTagIds'] = selectedTagIds;
    }

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
      default:
        return TaskSortFields.createdDate;
    }
  }
}
