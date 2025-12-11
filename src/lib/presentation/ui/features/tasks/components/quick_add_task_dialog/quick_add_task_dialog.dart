import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:acore/acore.dart' as acore;
import 'package:acore/utils/dialog_size.dart';
import 'package:acore/utils/platform_utils.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/shared/utils/overlay_notification_helper.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'builders/estimated_time_dialog_content.dart';
import 'builders/description_dialog_content.dart';

// New extracted dialog components
import 'dialogs/priority_selection_dialog_content.dart';
import 'dialogs/lock_settings_dialog_content.dart';
import 'dialogs/clear_fields_confirmation_dialog.dart';
import 'models/lock_settings_state.dart';

// Import the new TaskDatePickerDialog
import '../task_date_picker_dialog.dart';

class QuickAddTaskDialog extends StatefulWidget {
  final List<String>? initialTagIds;
  final DateTime? initialPlannedDate;
  final DateTime? initialDeadlineDate;
  final EisenhowerPriority? initialPriority;
  final int? initialEstimatedTime;
  final String? initialTitle;
  final String? initialDescription;
  final bool? initialCompleted;
  final Function(String taskId, TaskData taskData)? onTaskCreated;
  final String? initialParentTaskId;

  const QuickAddTaskDialog({
    super.key,
    this.initialTagIds,
    this.initialPlannedDate,
    this.initialDeadlineDate,
    this.initialPriority,
    this.initialEstimatedTime,
    this.initialTitle,
    this.initialDescription,
    this.initialCompleted,
    this.onTaskCreated,
    this.initialParentTaskId,
  });

  /// Shows the task dialog as bottom sheet on mobile platforms, dialog on desktop
  static Future<T?> show<T>({
    required BuildContext context,
    List<String>? initialTagIds,
    DateTime? initialPlannedDate,
    DateTime? initialDeadlineDate,
    EisenhowerPriority? initialPriority,
    int? initialEstimatedTime,
    String? initialTitle,
    String? initialDescription,
    bool? initialCompleted,
    Function(String taskId, TaskData taskData)? onTaskCreated,
    String? initialParentTaskId,
  }) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

    final dialog = QuickAddTaskDialog(
      initialTagIds: initialTagIds,
      initialPlannedDate: initialPlannedDate,
      initialDeadlineDate: initialDeadlineDate,
      initialPriority: initialPriority,
      initialEstimatedTime: initialEstimatedTime,
      initialTitle: initialTitle,
      initialDescription: initialDescription,
      initialCompleted: initialCompleted,
      onTaskCreated: onTaskCreated,
      initialParentTaskId: initialParentTaskId,
    );

    if (isMobile) {
      // Show as bottom sheet on mobile with proper keyboard handling
      return showMaterialModalBottomSheet<T>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        useRootNavigator: false,
        expand: false, // Enable proper sizing for better keyboard handling
        builder: (BuildContext context) {
          return AnimatedPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            child: dialog,
          );
        },
      );
    } else {
      // Show as dialog on desktop - force dialog instead of responsive
      return showDialog<T>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) => Dialog(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
                maxHeight: 600,
              ),
              child: dialog,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<QuickAddTaskDialog> createState() => _QuickAddTaskDialogState();
}

class _QuickAddTaskDialogState extends State<QuickAddTaskDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _themeService = container.resolve<IThemeService>();
  final _plannedDateController = TextEditingController();
  final _deadlineDateController = TextEditingController();
  final _mediator = container.resolve<Mediator>();
  final _tagRepository = container.resolve<ITagRepository>();
  final _tasksService = container.resolve<TasksService>();
  final _translationService = container.resolve<ITranslationService>();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  // Quick action state variables
  EisenhowerPriority? _selectedPriority;
  int? _estimatedTime;
  DateTime? _plannedDate;
  DateTime? _deadlineDate;
  ReminderTime _plannedDateReminderTime = ReminderTime.none;
  ReminderTime _deadlineDateReminderTime = ReminderTime.none;
  List<DropdownOption<String>> _selectedTags = [];

  // Track if estimated time was explicitly set by user (not from default)
  bool _isEstimatedTimeExplicitlySet = false;

  // Lock state variables
  bool _lockTags = false;
  bool _lockPriority = false;
  bool _lockEstimatedTime = false;
  bool _lockPlannedDate = false;
  bool _lockDeadlineDate = false;

  // UI state variables
  bool _showEstimatedTimeSection = false;
  bool _showDescriptionSection = false;

  @override
  void initState() {
    super.initState();
    _plannedDate = widget.initialPlannedDate;
    _deadlineDate = widget.initialDeadlineDate;
    _selectedPriority = widget.initialPriority;
    _estimatedTime = widget.initialEstimatedTime;

    // Track if estimated time was explicitly provided
    _isEstimatedTimeExplicitlySet = widget.initialEstimatedTime != null;

    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }

    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
      _showDescriptionSection = true; // Show section if there's initial content
      // Close estimated time section if description has initial content and no estimated time
      _showEstimatedTimeSection = false;
    }

    // Load initial tags with names
    _loadInitialTags();

    // Load default estimated time if not provided (but don't mark as explicitly set)
    if (_estimatedTime == null) {
      _loadDefaultEstimatedTime();
    }
  }

  /// Loads default estimated time from settings if no initial value is provided
  Future<void> _loadDefaultEstimatedTime() async {
    try {
      final setting = await _mediator.send<GetSettingQuery, Setting?>(
        GetSettingQuery(key: SettingKeys.taskDefaultEstimatedTime),
      );

      if (setting != null) {
        final value = setting.getValue<int?>();
        if (value != null && value > 0) {
          if (mounted) {
            setState(() {
              _estimatedTime = value;
              // Don't mark as explicitly set since this is just a default
            });
          }
        }
      }
    } catch (e) {
      // Log error and use default of TaskConstants.defaultEstimatedTime minutes if setting can't be loaded
      Logger.error('Error loading default estimated time in QuickAddTaskDialog: $e');
      if (mounted) {
        setState(() {
          _estimatedTime = TaskConstants.defaultEstimatedTime;
          // Don't mark as explicitly set since this is just a default
        });
      }
    }
  }

  /// Loads initial tags and gets their names for display
  Future<void> _loadInitialTags() async {
    if (widget.initialTagIds == null || widget.initialTagIds!.isEmpty) {
      return;
    }

    try {
      List<DropdownOption<String>> tagOptions = [];

      for (String tagId in widget.initialTagIds!) {
        final tag = await _tagRepository.getById(tagId);
        if (tag != null) {
          tagOptions.add(DropdownOption(
              label: tag.name.isNotEmpty ? tag.name : _translationService.translate(SharedTranslationKeys.untitled),
              value: tagId));
        }
      }

      if (mounted) {
        setState(() {
          _selectedTags = tagOptions;
        });
      }
    } catch (e) {
      // If we can't load tag names, fallback to tag IDs with empty labels
      setState(() {
        _selectedTags = widget.initialTagIds!.map((id) => DropdownOption(label: '', value: id)).toList();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize date controllers with format matching DateTimePickerField
    // This is done here instead of initState to ensure Localizations is available
    if (_plannedDate != null && _plannedDateController.text.isEmpty) {
      _plannedDateController.text = acore.DateFormatService.formatForInput(
        _plannedDate!,
        context,
        type: acore.DateFormatType.dateTime,
      );
    }
    if (_deadlineDate != null && _deadlineDateController.text.isEmpty) {
      _deadlineDateController.text = acore.DateFormatService.formatForInput(
        _deadlineDate!,
        context,
        type: acore.DateFormatType.dateTime,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _plannedDateController.dispose();
    _deadlineDateController.dispose();
    super.dispose();
  }

  Future<void> _clearAllFields() async {
    setState(() {
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      } else {
        _titleController.clear();
      }

      // Clear description field
      _descriptionController.clear();

      // Only reset values that are not locked
      if (!_lockPriority) {
        _selectedPriority = widget.initialPriority;
      }
      if (!_lockEstimatedTime) {
        _estimatedTime = widget.initialEstimatedTime;
        if (_estimatedTime == null) {
          _loadDefaultEstimatedTime();
        }
        _isEstimatedTimeExplicitlySet = widget.initialEstimatedTime != null && widget.initialEstimatedTime! > 0;
        _showEstimatedTimeSection = widget.initialEstimatedTime != null && widget.initialEstimatedTime! > 0;
        // Close description section if estimated time has initial content and no description content
        if (_showEstimatedTimeSection && _descriptionController.text.isEmpty) {
          _showDescriptionSection = false;
        }
      }
      if (!_lockPlannedDate) {
        _plannedDate = widget.initialPlannedDate;
        if (_plannedDate != null) {
          _plannedDateController.text = acore.DateFormatService.formatForInput(
            _plannedDate!,
            context,
            type: acore.DateFormatType.dateTime,
          );
        } else {
          _plannedDateController.clear();
        }
      }
      if (!_lockDeadlineDate) {
        _deadlineDate = widget.initialDeadlineDate;
        if (_deadlineDate != null) {
          _deadlineDateController.text = acore.DateFormatService.formatForInput(
            _deadlineDate!,
            context,
            type: acore.DateFormatType.dateTime,
          );
        } else {
          _deadlineDateController.clear();
        }
      }
      if (!_lockTags) {
        // Reset tags and reload them with proper names
        _selectedTags = [];
        _loadInitialTags();
      }
    });
  }

  Future<void> _createTask() async {
    if (_isLoading || _titleController.text.isEmpty) return;

    setState(() => _isLoading = true);

    await AsyncErrorHandler.execute<SaveTaskCommandResponse>(
      context: context,
      errorMessage: _translationService.translate(TaskTranslationKeys.saveTaskError),
      errorPosition: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
          ? NotificationPosition.top
          : NotificationPosition.bottom,
      operation: () async {
        final command = SaveTaskCommand(
          title: _titleController.text,
          description: _descriptionController.text.trim(),
          tagIdsToAdd: _selectedTags.map((t) => t.value).toList(),
          priority: _selectedPriority,
          estimatedTime: _estimatedTime,
          plannedDate: _plannedDate,
          deadlineDate: _deadlineDate,
          // Include reminder settings
          plannedDateReminderTime: _plannedDateReminderTime,
          deadlineDateReminderTime: _deadlineDateReminderTime,
          completedAt: (widget.initialCompleted ?? false) ? DateTime.now().toUtc() : null,
          parentTaskId: widget.initialParentTaskId,
        );
        return await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);
      },
      onSuccess: (response) {
        // Notify that a task was created with the task ID (using non-nullable parameter)
        _tasksService.notifyTaskCreated(response.id);

        final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
        OverlayNotificationHelper.showSuccess(
          context: context,
          message: _translationService.translate(
            TaskTranslationKeys.taskAddedSuccessfully,
            namedArgs: {'title': _titleController.text},
          ),
          position: isMobile ? NotificationPosition.top : NotificationPosition.bottom,
        );

        if (widget.onTaskCreated != null) {
          // Create a TaskData object with all the task information
          final taskData = TaskData(
            title: _titleController.text,
            priority: _selectedPriority,
            estimatedTime: _estimatedTime,
            plannedDate: _plannedDate?.toUtc(),
            deadlineDate: _deadlineDate?.toUtc(),
            tags: _selectedTags
                .map((t) => TaskDataTag(
                      id: t.value,
                      name: t.label,
                    ))
                .toList(),
            isCompleted: false,
            parentTaskId: widget.initialParentTaskId,
            order: 0.0, // Default order
            createdDate: DateTime.now().toUtc(),
          );

          widget.onTaskCreated!(response.id, taskData);
        }

        if (mounted) {
          setState(() {
            _clearAllFields();
          });
          // Delay focus request to prevent dialog instability
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _focusNode.requestFocus();
            }
          });
        }
      },
      finallyAction: () {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _selectPlannedDate() async {
    final result = await TaskDatePickerDialog.showWithReminder(
      context: context,
      config: TaskDatePickerConfig(
        initialDate: _plannedDate,
        initialReminderTime: _plannedDateReminderTime,
        titleText: _translationService.translate(TaskTranslationKeys.selectPlannedDateTitle),
        showTime: true,
        showQuickRanges: true,
        useResponsiveDesign: true,
        enableFooterActions: true,
        translationService: _translationService,
        minDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day), // Start of today
      ),
    );

    if (result != null && !result.wasCancelled) {
      setState(() {
        _plannedDate = result.selectedDate;
        _plannedDateReminderTime = result.reminderTime ?? ReminderTime.none;
        if (result.selectedDate != null) {
          _plannedDateController.text = acore.DateFormatService.formatForInput(
            result.selectedDate!,
            context,
            type: acore.DateFormatType.dateTime,
          );
        } else {
          _plannedDateController.clear();
        }
      });
    }
  }

  Future<void> _selectDeadlineDate() async {
    final result = await TaskDatePickerDialog.showWithReminder(
      context: context,
      config: TaskDatePickerConfig(
        initialDate: _deadlineDate,
        initialReminderTime: _deadlineDateReminderTime,
        titleText: _translationService.translate(TaskTranslationKeys.selectDeadlineDateTitle),
        showTime: true,
        showQuickRanges: true,
        useResponsiveDesign: true,
        enableFooterActions: true,
        translationService: _translationService,
        minDate: _plannedDate ??
            DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day), // Start of today or after planned date
      ),
    );

    if (result != null && !result.wasCancelled) {
      setState(() {
        _deadlineDate = result.selectedDate;
        _deadlineDateReminderTime = result.reminderTime ?? ReminderTime.none;
        if (result.selectedDate != null) {
          _deadlineDateController.text = acore.DateFormatService.formatForInput(
            result.selectedDate!,
            context,
            type: acore.DateFormatType.dateTime,
          );
        } else {
          _deadlineDateController.clear();
        }
      });
    }
  }

  String? _getFormattedDate(DateTime? date) {
    if (date == null) return null;
    return acore.DateTimeHelper.formatDate(date);
  }

  void _togglePriority() {
    _showPrioritySelectionDialog();
  }

  Future<void> _showPrioritySelectionDialog() async {
    EisenhowerPriority? tempPriority = _selectedPriority;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: PlatformUtils.isDesktop ? DialogSize.medium : DialogSize.large,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return PrioritySelectionDialogContent(
            selectedPriority: tempPriority,
            onPrioritySelected: (EisenhowerPriority? priority) {
              setDialogState(() => tempPriority = priority);
            },
            translationService: _translationService,
            theme: Theme.of(context),
          );
        },
      ),
    );

    if (mounted) {
      setState(() => _selectedPriority = tempPriority);
    }
  }

  void _toggleEstimatedTime() {
    setState(() {
      _showEstimatedTimeSection = !_showEstimatedTimeSection;
      _showDescriptionSection = false;
    });

    if (_showEstimatedTimeSection) {
      _showEstimatedTimeDialog();
    }
  }

  void _toggleDescription() {
    setState(() {
      _showDescriptionSection = !_showDescriptionSection;
      _showEstimatedTimeSection = false;
    });

    if (_showDescriptionSection) {
      _showDescriptionDialog();
    }
  }

  Future<void> _showEstimatedTimeDialog() async {
    // Initialize temporary state outside StatefulBuilder to prevent reset on rebuild
    int tempEstimatedTime = _estimatedTime ?? 0;
    bool tempIsExplicitlySet = _isEstimatedTimeExplicitlySet;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.medium,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final theme = Theme.of(context);

          // Function to update temporary state
          void updateTempTime(int value) {
            setDialogState(() {
              tempEstimatedTime = value;
              tempIsExplicitlySet = true;
            });
          }

          // Function to confirm and apply changes
          void confirmEstimatedTime() {
            setState(() {
              _estimatedTime = tempEstimatedTime;
              _isEstimatedTimeExplicitlySet = tempIsExplicitlySet;
            });
          }

          return EstimatedTimeDialogContent(
            selectedTime: tempEstimatedTime,
            onTimeSelected: updateTempTime,
            onConfirm: confirmEstimatedTime,
            translationService: _translationService,
            theme: theme,
          );
        },
      ),
    );

    // Reset state when dialog is closed
    if (mounted) {
      setState(() {
        _showEstimatedTimeSection = false;
      });
    }
  }

  Future<void> _showDescriptionDialog() async {
    // Initialize temporary state outside StatefulBuilder to prevent reset on rebuild
    String tempDescription = _descriptionController.text;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final theme = Theme.of(context);
          return DescriptionDialogContent(
            description: tempDescription,
            onChanged: (value) {
              setDialogState(() {
                tempDescription = value;
              });
            },
            translationService: _translationService,
            theme: theme,
          );
        },
      ),
    );

    // Apply final state when dialog is closed
    if (mounted) {
      setState(() {
        _descriptionController.text = tempDescription;
        _showDescriptionSection = false;
      });
    }
  }

  // Helper methods to convert between individual lock variables and LockSettingsState
  LockSettingsState _getLockState() {
    return LockSettingsState(
      lockTags: _lockTags,
      lockPriority: _lockPriority,
      lockEstimatedTime: _lockEstimatedTime,
      lockPlannedDate: _lockPlannedDate,
      lockDeadlineDate: _lockDeadlineDate,
    );
  }

  void _setLockState(LockSettingsState lockState) {
    setState(() {
      _lockTags = lockState.lockTags;
      _lockPriority = lockState.lockPriority;
      _lockEstimatedTime = lockState.lockEstimatedTime;
      _lockPlannedDate = lockState.lockPlannedDate;
      _lockDeadlineDate = lockState.lockDeadlineDate;
    });
  }

  Future<void> _showLockSettingsDialog() async {
    LockSettingsState tempLockState = _getLockState();

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: PlatformUtils.isDesktop ? DialogSize.medium : DialogSize.large,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return LockSettingsDialogContent(
            lockState: tempLockState,
            onLockStateChanged: (LockSettingsState newLockState) {
              setDialogState(() => tempLockState = newLockState);
            },
            translationService: _translationService,
            themeService: _themeService,
            theme: Theme.of(context),
            currentPriority: _selectedPriority,
          );
        },
      ),
    );

    if (mounted) {
      _setLockState(tempLockState);
    }
  }

  String _getEstimatedTimeTooltip() {
    if (_estimatedTime == null || _estimatedTime == 0) {
      return _translationService.translate(TaskTranslationKeys.quickTaskEstimatedTimeNotSet);
    }

    if (_isEstimatedTimeExplicitlySet) {
      return _translationService.translate(
        TaskTranslationKeys.quickTaskEstimatedTime,
        namedArgs: {'time': SharedUiConstants.formatMinutes(_estimatedTime)},
      );
    } else {
      // For default values, indicate it's a default
      final formattedTime = SharedUiConstants.formatMinutes(_estimatedTime);
      final defaultText = _translationService.translate(TaskTranslationKeys.quickTaskEstimatedTimeDefault);
      return _translationService.translate(
        TaskTranslationKeys.quickTaskEstimatedTime,
        namedArgs: {'time': '$formattedTime $defaultText'},
      );
    }
  }

  String _getDateTooltip(bool isDeadline) {
    final date = isDeadline ? _deadlineDate : _plannedDate;
    final formattedDate = _getFormattedDate(date);

    if (date == null) {
      return _translationService.translate(
        isDeadline ? TaskTranslationKeys.quickTaskDeadlineDateNotSet : TaskTranslationKeys.quickTaskPlannedDateNotSet,
      );
    }

    return _translationService.translate(
      isDeadline ? TaskTranslationKeys.quickTaskDeadlineDate : TaskTranslationKeys.quickTaskPlannedDate,
      namedArgs: {'date': formattedDate.toString()},
    );
  }

  String _getTagsTooltip() {
    if (_selectedTags.isEmpty) {
      return _translationService.translate(TaskTranslationKeys.tagsLabel);
    }

    final tagNames = _selectedTags.map((tag) => tag.label).where((name) => name.isNotEmpty).toList();
    if (tagNames.isEmpty) {
      return _translationService.translate(TaskTranslationKeys.tagsLabel);
    }

    return tagNames.join(', ');
  }

  Widget _buildEstimatedTimeIcon() {
    final theme = Theme.of(context);

    if (_estimatedTime != null && _estimatedTime! > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: _isEstimatedTimeExplicitlySet
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _estimatedTime.toString(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: _isEstimatedTimeExplicitlySet
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    } else {
      return Icon(
        TaskUiConstants.estimatedTimeIcon,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      );
    }
  }

  Future<void> _onClearAllFields() async {
    // Show confirmation dialog using extracted component
    final confirmed = await ClearFieldsConfirmationDialog.showForQuickTaskClear(
      context: context,
      translationService: _translationService,
    );

    if (!confirmed) return;

    _clearAllFields();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    final theme = Theme.of(context);

    Widget dialogContent = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        // Use different border radius based on platform
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(AppTheme.sizeLarge))
            : BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      // Use mainAxisSize.min to make the container fit its content
      child: Padding(
        // Use same padding for both platforms with slightly reduced bottom padding
        padding: EdgeInsets.fromLTRB(AppTheme.sizeLarge, AppTheme.sizeSmall, AppTheme.sizeLarge, AppTheme.sizeSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle for mobile, title for desktop
            if (isMobile) ...[
              // Mobile drag handle
              Container(
                width: 32,
                height: 4,
                margin: EdgeInsets.only(bottom: AppTheme.sizeSmall),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ] else
              Padding(
                padding: EdgeInsets.only(bottom: AppTheme.sizeLarge),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

            // Title input
            TextField(
              controller: _titleController,
              focusNode: _focusNode,
              autofocus: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: _translationService.translate(TaskTranslationKeys.quickTaskTitlePlaceholder),
                // Use same content padding for both platforms
                contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
                // Send button in the text field
                suffixIcon: isMobile
                    ? SizedBox(
                        width: AppTheme.iconSizeLarge - 4.0,
                        height: AppTheme.iconSizeLarge - 4.0,
                        child: IconButton(
                          icon: Icon(
                            _isLoading ? Icons.hourglass_empty : Icons.send,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: _createTask,
                          iconSize: AppTheme.iconSizeMedium,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: AppTheme.iconSizeLarge - 4.0,
                            minHeight: AppTheme.iconSizeLarge - 4.0,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          _isLoading ? Icons.hourglass_empty : Icons.send,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: _createTask,
                        tooltip: _translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
                      ),
              ),
              onSubmitted: (_) => _createTask(),
            ),

            // Quick action buttons for all screen sizes
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(top: AppTheme.sizeSmall),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildQuickActionButtons(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return dialogContent;
  }

  Widget _buildQuickActionButtons() {
    final iconSize = AppTheme.iconSizeMedium;
    final theme = Theme.of(context);
    final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    // Use larger gap for desktop, smaller for mobile
    final buttonGap = isMobile ? 2.0 : AppTheme.sizeXSmall; // 6px for desktop, 2px for mobile

    // Check if any locks are enabled
    final hasAnyLocks = _lockTags || _lockPriority || _lockEstimatedTime || _lockPlannedDate || _lockDeadlineDate;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Lock settings button
        IconButton(
          icon: Icon(
            Icons.lock_outline,
            color: hasAnyLocks ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          onPressed: _showLockSettingsDialog,
          tooltip: _translationService.translate(TaskTranslationKeys.quickTaskLockSettings),
          iconSize: iconSize,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
          ),
        ),
        SizedBox(width: buttonGap), // Dynamic gap between buttons
        // Tag select dropdown with lock indicator
        _buildActionButtonWithLock(
          child: TagSelectDropdown(
            initialSelectedTags: _selectedTags,
            isMultiSelect: true,
            tooltip: _getTagsTooltip(),
            onTagsSelected: (tags, _) => setState(() => _selectedTags = tags),
            iconSize: iconSize,
            color: _selectedTags.isEmpty
                ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                : TaskUiConstants.getTagColor(_themeService),
            buttonStyle: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          isLocked: _lockTags,
        ),
        SizedBox(width: buttonGap), // Dynamic gap between buttons
        // Priority button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: Icon(
              _selectedPriority == null ? TaskUiConstants.priorityOutlinedIcon : TaskUiConstants.priorityIcon,
              color: _selectedPriority == null
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                  : TaskUiConstants.getPriorityColor(_selectedPriority),
            ),
            onPressed: _togglePriority,
            tooltip: TaskUiConstants.getPriorityTooltip(_selectedPriority, _translationService),
            iconSize: iconSize,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          isLocked: _lockPriority,
        ),
        SizedBox(width: buttonGap), // Dynamic gap between buttons
        // Estimated time button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: _buildEstimatedTimeIcon(),
            onPressed: _toggleEstimatedTime,
            tooltip: _estimatedTime != null
                ? _getEstimatedTimeTooltip()
                : _translationService.translate(TaskTranslationKeys.quickTaskEstimatedTimeNotSet),
            iconSize: iconSize,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          isLocked: _lockEstimatedTime,
        ),
        SizedBox(width: buttonGap), // Dynamic gap between buttons
        // Description button
        _buildActionButtonWithLock(
          child: IconButton(
            icon: Icon(
              _descriptionController.text.isNotEmpty ? Icons.description : Icons.description_outlined,
              color: _descriptionController.text.isNotEmpty
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: _toggleDescription,
            tooltip: _descriptionController.text.isNotEmpty
                ? _translationService.translate(TaskTranslationKeys.descriptionLabel)
                : _translationService.translate(TaskTranslationKeys.addDescriptionHint),
            iconSize: iconSize,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          isLocked: false, // Description doesn't support locking for now
        ),
        SizedBox(width: buttonGap), // Dynamic gap between buttons
        // Planned date button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: Icon(
              _plannedDate == null ? TaskUiConstants.plannedDateOutlinedIcon : TaskUiConstants.plannedDateIcon,
              color: _plannedDate == null
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                  : TaskUiConstants.plannedDateColor,
            ),
            onPressed: _selectPlannedDate,
            tooltip: _getDateTooltip(false),
            iconSize: iconSize,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          isLocked: _lockPlannedDate,
        ),
        SizedBox(width: buttonGap), // Dynamic gap between buttons
        // Deadline date button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: Icon(
              _deadlineDate == null ? TaskUiConstants.deadlineDateOutlinedIcon : TaskUiConstants.deadlineDateIcon,
              color: _deadlineDate == null
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                  : TaskUiConstants.deadlineDateColor,
            ),
            onPressed: _selectDeadlineDate,
            tooltip: _getDateTooltip(true),
            iconSize: iconSize,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
            ),
          ),
          isLocked: _lockDeadlineDate,
        ),
        SizedBox(width: buttonGap), // Dynamic gap between buttons
        // Clear all button
        IconButton(
          icon: Icon(
            Icons.close,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          onPressed: _onClearAllFields,
          tooltip: _translationService.translate(TaskTranslationKeys.quickTaskResetAll),
          iconSize: iconSize,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonWithLock({
    required Widget child,
    required bool isLocked,
  }) {
    final theme = Theme.of(context);

    // Handle any widget with just the lock overlay
    // Each widget should handle its own styling (e.g., TagSelectDropdown with buttonStyle)
    return Stack(
      children: [
        child,
        if (isLocked)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.lock,
                size: AppTheme.iconSize2XSmall,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}
