import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:acore/acore.dart' show DateFormatService, DateFormatType;

/// Manages the state and operations for quick add task dialog
class QuickActionManager {
  // Controllers
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final plannedDateController = TextEditingController();
  final deadlineDateController = TextEditingController();
  final focusNode = FocusNode();

  // State variables
  bool isLoading = false;
  List<DropdownOption<String>> selectedTags = [];
  EisenhowerPriority? selectedPriority;
  int? estimatedTime;
  bool isEstimatedTimeExplicitlySet = false;
  DateTime? plannedDate;
  DateTime? deadlineDate;

  // Dialog visibility states
  bool showEstimatedTimeSection = false;
  bool showDescriptionSection = false;

  // Lock states
  bool lockTags = false;
  bool lockPriority = false;
  bool lockEstimatedTime = false;
  bool lockPlannedDate = false;
  bool lockDeadlineDate = false;

  QuickActionManager({
    String? initialTitle,
    String? initialDescription,
    List<String>? initialTagIds,
    EisenhowerPriority? initialPriority,
    int? initialEstimatedTime,
    DateTime? initialPlannedDate,
    DateTime? initialDeadlineDate,
    List<DropdownOption<String>>? tagOptions,
  }) {
    // Initialize title
    titleController.text = initialTitle ?? '';

    // Initialize description
    descriptionController.text = initialDescription ?? '';
    if (initialDescription != null && initialDescription.isNotEmpty) {
      showDescriptionSection = true; // Show section if there's initial content
    }

    // Initialize priority
    selectedPriority = initialPriority;

    // Initialize estimated time
    estimatedTime = initialEstimatedTime;
    isEstimatedTimeExplicitlySet = initialEstimatedTime != null && initialEstimatedTime > 0;
    if (initialEstimatedTime != null && initialEstimatedTime > 0) {
      showEstimatedTimeSection = true;
    }

    // Initialize dates (controller formatting will be done later with context)
    plannedDate = initialPlannedDate;
    deadlineDate = initialDeadlineDate;

    // Initialize tags
    if (initialTagIds != null) {
      selectedTags = initialTagIds.map((id) => DropdownOption(label: '', value: id)).toList();
    } else if (tagOptions != null) {
      selectedTags = tagOptions;
    } else {
      selectedTags = [];
    }
  }

  /// Initialize date controllers with context
  void initializeDateControllers(BuildContext context) {
    if (plannedDate != null) {
      plannedDateController.text = DateFormatService.formatForInput(
        plannedDate!,
        context,
        type: DateFormatType.dateTime,
      );
    }

    if (deadlineDate != null) {
      deadlineDateController.text = DateFormatService.formatForInput(
        deadlineDate!,
        context,
        type: DateFormatType.dateTime,
      );
    }
  }

  /// Initialize tag options from loaded tags
  void initializeTags(List<DropdownOption<String>> tagOptions, List<String>? initialTagIds) {
    if (initialTagIds != null) {
      selectedTags = tagOptions.where((tag) => initialTagIds.contains(tag.value)).toList();
    } else {
      selectedTags = tagOptions;
    }
  }

  /// Reset estimated time to default
  void resetEstimatedTimeToDefault() {
    estimatedTime = TaskConstants.defaultEstimatedTime;
    isEstimatedTimeExplicitlySet = false;
  }

  /// Reset state for new task creation
  void resetForNewTask() {
    titleController.text = '';
    descriptionController.text = '';
    plannedDateController.text = '';
    deadlineDateController.text = '';
    selectedTags = [];
    selectedPriority = null;
    estimatedTime = null;
    isEstimatedTimeExplicitlySet = false;
    plannedDate = null;
    deadlineDate = null;
    showEstimatedTimeSection = false;
    showDescriptionSection = false;
    showEstimatedTimeSection = false;
    showDescriptionSection = false;
  }

  /// Update state from existing task data
  void updateFromTaskData({
    required BuildContext context,
    String? title,
    String? description,
    EisenhowerPriority? priority,
    int? estimatedTimeValue,
    DateTime? planned,
    DateTime? deadline,
    List<DropdownOption<String>>? tags,
  }) {
    titleController.text = title ?? '';
    descriptionController.text = description ?? '';
    selectedPriority = priority;
    estimatedTime = estimatedTimeValue;
    isEstimatedTimeExplicitlySet = estimatedTimeValue != null && estimatedTimeValue > 0;
    plannedDate = planned;
    deadlineDate = deadline;
    selectedTags = tags ?? [];

    if (estimatedTime != null && estimatedTime! > 0) {
      showEstimatedTimeSection = true;
    }

    if (description != null && description.isNotEmpty) {
      showDescriptionSection = true;
    }

    // Update date controllers
    if (plannedDate != null) {
      plannedDateController.text = DateFormatService.formatForInput(
        plannedDate!,
        context,
        type: DateFormatType.dateTime,
      );
    }

    if (deadlineDate != null) {
      deadlineDateController.text = DateFormatService.formatForInput(
        deadlineDate!,
        context,
        type: DateFormatType.dateTime,
      );
    }
  }

  /// Cycle through priority options
  EisenhowerPriority? cyclePriority(EisenhowerPriority? currentPriority) {
    switch (currentPriority) {
      case EisenhowerPriority.urgentImportant:
        return EisenhowerPriority.notUrgentImportant;
      case EisenhowerPriority.notUrgentImportant:
        return EisenhowerPriority.urgentNotImportant;
      case EisenhowerPriority.urgentNotImportant:
        return EisenhowerPriority.notUrgentNotImportant;
      case EisenhowerPriority.notUrgentNotImportant:
        return null;
      case null:
        return EisenhowerPriority.urgentImportant;
    }
  }

  /// Toggle estimated time section visibility
  void toggleEstimatedTimeSection() {
    showEstimatedTimeSection = !showEstimatedTimeSection;
    showDescriptionSection = false;
  }

  /// Toggle description section visibility
  void toggleDescriptionSection() {
    showDescriptionSection = !showDescriptionSection;
    showEstimatedTimeSection = false;
  }

  /// Set estimated time and mark as explicitly set
  void setEstimatedTime(int value) {
    estimatedTime = value;
    isEstimatedTimeExplicitlySet = true;
  }

  /// Clear estimated time
  void clearEstimatedTime() {
    estimatedTime = 0;
    isEstimatedTimeExplicitlySet = false;
  }

  /// Update selected tags
  void updateSelectedTags(List<DropdownOption<String>> tags) {
    selectedTags = tags;
  }

  /// Get selected tag IDs
  List<String> get selectedTagIds {
    return selectedTags.map((tag) => tag.value).toList();
  }

  /// Get formatted tag names
  List<String> get tagNames {
    return selectedTags.map((tag) => tag.label).where((name) => name.isNotEmpty).toList();
  }

  /// Check if estimated time is valid
  bool get hasValidEstimatedTime {
    return estimatedTime != null && estimatedTime! > 0;
  }

  /// Dispose controllers
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    plannedDateController.dispose();
    deadlineDateController.dispose();
    focusNode.dispose();
  }
}
