import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/tasks/commands/save_task_command.dart';
import 'package:whph/core/application/features/tags/services/abstraction/i_tag_repository.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/tasks/task_constants.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/services/tasks_service.dart';
import 'package:whph/presentation/ui/shared/components/border_fade_overlay.dart';
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
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'package:acore/acore.dart' show DateTimeHelper, DateFormatService, DateFormatType;
import 'package:whph/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/presentation/ui/shared/enums/dialog_size.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:acore/acore.dart' show NumericInput;

class QuickAddTaskDialog extends StatefulWidget {
  final List<String>? initialTagIds;
  final DateTime? initialPlannedDate;
  final DateTime? initialDeadlineDate;
  final EisenhowerPriority? initialPriority;
  final int? initialEstimatedTime;
  final String? initialTitle;
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
  final _themeService = container.resolve<IThemeService>();
  final _plannedDateController = TextEditingController();
  final _deadlineDateController = TextEditingController();
  final _mediator = container.resolve<Mediator>();
  final _tagRepository = container.resolve<ITagRepository>();
  final _tasksService = container.resolve<TasksService>();
  final _translationService = container.resolve<ITranslationService>();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  void _closeDialog() {
    Navigator.pop(context);
  }

  // Quick action state variables
  EisenhowerPriority? _selectedPriority;
  int? _estimatedTime;
  DateTime? _plannedDate;
  DateTime? _deadlineDate;
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
      _plannedDateController.text = DateFormatService.formatForInput(
        _plannedDate!,
        context,
        type: DateFormatType.dateTime,
      );
    }
    if (_deadlineDate != null && _deadlineDateController.text.isEmpty) {
      _deadlineDateController.text = DateFormatService.formatForInput(
        _deadlineDate!,
        context,
        type: DateFormatType.dateTime,
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _titleController.dispose();
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
      }
      if (!_lockPlannedDate) {
        _plannedDate = widget.initialPlannedDate;
        if (_plannedDate != null) {
          _plannedDateController.text = DateFormatService.formatForInput(
            _plannedDate!,
            context,
            type: DateFormatType.dateTime,
          );
        } else {
          _plannedDateController.clear();
        }
      }
      if (!_lockDeadlineDate) {
        _deadlineDate = widget.initialDeadlineDate;
        if (_deadlineDate != null) {
          _deadlineDateController.text = DateFormatService.formatForInput(
            _deadlineDate!,
            context,
            type: DateFormatType.dateTime,
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
      operation: () async {
        final command = SaveTaskCommand(
          title: _titleController.text,
          description: "",
          tagIdsToAdd: _selectedTags.map((t) => t.value).toList(),
          priority: _selectedPriority,
          estimatedTime: _estimatedTime,
          plannedDate: _plannedDate,
          deadlineDate: _deadlineDate,
          completedAt: (widget.initialCompleted ?? false) ? DateTime.now().toUtc() : null,
          parentTaskId: widget.initialParentTaskId,
        );
        return await _mediator.send<SaveTaskCommand, SaveTaskCommandResponse>(command);
      },
      onSuccess: (response) {
        // Notify that a task was created with the task ID (using non-nullable parameter)
        _tasksService.notifyTaskCreated(response.id);

        if (widget.onTaskCreated != null) {
          // Create a TaskData object with all the task information
          final taskData = TaskData(
            title: _titleController.text,
            priority: _selectedPriority,
            estimatedTime: _estimatedTime,
            plannedDate: _plannedDate,
            deadlineDate: _deadlineDate,
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
    final selectedDateTime = await _selectDateTime(
      title: _translationService.translate(TaskTranslationKeys.selectPlannedDateTitle),
      initialDateTime: _plannedDate,
    );

    if (selectedDateTime != null) {
      setState(() {
        _plannedDate = selectedDateTime;
        _plannedDateController.text = DateFormatService.formatForInput(
          selectedDateTime,
          context,
          type: DateFormatType.dateTime,
        );
      });
    }
  }

  Future<void> _selectDeadlineDate() async {
    final selectedDateTime = await _selectDateTime(
      title: _translationService.translate(TaskTranslationKeys.selectDeadlineDateTitle),
      initialDateTime: _deadlineDate,
    );

    if (selectedDateTime != null) {
      setState(() {
        _deadlineDate = selectedDateTime;
        _deadlineDateController.text = DateFormatService.formatForInput(
          selectedDateTime,
          context,
          type: DateFormatType.dateTime,
        );
      });
    }
  }

  Future<DateTime?> _selectDateTime({
    required String title,
    DateTime? initialDateTime,
  }) async {
    if (!mounted) return null;

    final now = DateTime.now();
    final initialDate = initialDateTime ?? now;

    // First, show date picker
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: title,
    );

    if (selectedDate == null || !mounted) return null;

    // Then, show time picker
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: title,
    );

    if (selectedTime == null) return selectedDate;

    // Combine date and time
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  String? _getFormattedDate(DateTime? date) {
    if (date == null) return null;
    return DateTimeHelper.formatDate(date);
  }

  void _togglePriority() {
    setState(() {
      switch (_selectedPriority) {
        case null:
          _selectedPriority = EisenhowerPriority.urgentImportant;
          break;
        case EisenhowerPriority.urgentImportant:
          _selectedPriority = EisenhowerPriority.notUrgentImportant;
          break;
        case EisenhowerPriority.notUrgentImportant:
          _selectedPriority = EisenhowerPriority.urgentNotImportant;
          break;
        case EisenhowerPriority.urgentNotImportant:
          _selectedPriority = EisenhowerPriority.notUrgentNotImportant;
          break;
        case EisenhowerPriority.notUrgentNotImportant:
          _selectedPriority = null;
          break;
      }
    });
  }

  void _toggleEstimatedTime() {
    setState(() {
      _showEstimatedTimeSection = !_showEstimatedTimeSection;
    });
  }

  Future<void> _showLockSettingsDialog() async {
    await ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.medium,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);

          return Padding(
            padding: const EdgeInsets.all(AppTheme.sizeLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_translationService.translate(TaskTranslationKeys.quickTaskLockSettings)),

                // Description
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _translationService.translate(TaskTranslationKeys.quickTaskLockDescription),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),

                // Scrollable lock options
                Flexible(
                  child: BorderFadeOverlay(
                    fadeBorders: {FadeBorder.bottom},
                    backgroundColor: theme.colorScheme.surface,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tag lock options
                          _buildLockOptionCheckboxTile(
                            title: _translationService.translate(TaskTranslationKeys.tagsLabel),
                            icon: TagUiConstants.tagIcon,
                            iconColor: TaskUiConstants.getTagColor(_themeService),
                            value: _lockTags,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                _lockTags = value ?? false;
                              });
                              setState(() {
                                _lockTags = value ?? false;
                              });
                            },
                          ),
                          // Priority lock options
                          _buildLockOptionCheckboxTile(
                            title: _translationService.translate(TaskTranslationKeys.priorityLabel),
                            icon: TaskUiConstants.priorityOutlinedIcon,
                            iconColor: _selectedPriority == null
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                                : TaskUiConstants.getPriorityColor(_selectedPriority),
                            value: _lockPriority,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                _lockPriority = value ?? false;
                              });
                              setState(() {
                                _lockPriority = value ?? false;
                              });
                            },
                          ),
                          // Estimated time lock options
                          _buildLockOptionCheckboxTile(
                            title: _translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
                            icon: TaskUiConstants.estimatedTimeOutlinedIcon,
                            iconColor: TaskUiConstants.estimatedTimeColor,
                            value: _lockEstimatedTime,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                _lockEstimatedTime = value ?? false;
                              });
                              setState(() {
                                _lockEstimatedTime = value ?? false;
                              });
                            },
                          ),
                          // Planned date lock options
                          _buildLockOptionCheckboxTile(
                            title: _translationService.translate(TaskTranslationKeys.plannedDateLabel),
                            icon: TaskUiConstants.plannedDateOutlinedIcon,
                            iconColor: TaskUiConstants.plannedDateColor,
                            value: _lockPlannedDate,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                _lockPlannedDate = value ?? false;
                              });
                              setState(() {
                                _lockPlannedDate = value ?? false;
                              });
                            },
                          ),
                          // Deadline date lock options
                          _buildLockOptionCheckboxTile(
                            title: _translationService.translate(TaskTranslationKeys.deadlineDateLabel),
                            icon: TaskUiConstants.deadlineDateOutlinedIcon,
                            iconColor: TaskUiConstants.deadlineDateColor,
                            value: _lockDeadlineDate,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                _lockDeadlineDate = value ?? false;
                              });
                              setState(() {
                                _lockDeadlineDate = value ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Done button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLockOptionCheckboxTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(title),
      secondary: Icon(
        icon,
        color: iconColor,
      ),
      value: value,
      onChanged: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
    );
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

  Future<void> _onClearAllFields() async {
    // Show confirmation dialog
    final confirmed = await ResponsiveDialogHelper.showResponsiveDialog<bool>(
      context: context,
      size: DialogSize.min,
      child: AlertDialog(
        title: Text(_translationService.translate(TaskTranslationKeys.quickTaskResetConfirmTitle)),
        content: Text(_translationService.translate(TaskTranslationKeys.quickTaskResetConfirmMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_translationService.translate(SharedTranslationKeys.confirmButton)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
                      onPressed: _closeDialog,
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

            // Collapsible estimated time section
            if (_showEstimatedTimeSection) ...[
              SizedBox(height: AppTheme.sizeSmall),
              Container(
                padding: EdgeInsets.all(AppTheme.sizeMedium),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          TaskUiConstants.estimatedTimeIcon,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: AppTheme.sizeSmall),
                        Text(
                          _translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),

                        // Estimated Numeric Input with clear button
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NumericInput(
                              initialValue: _estimatedTime ?? 0,
                              minValue: 0,
                              maxValue: 480, // Increased from 60 to 480 minutes (8 hours) for better usability
                              incrementValue: 5,
                              decrementValue: 5,
                              onValueChanged: (value) {
                                setState(() {
                                  _estimatedTime = value;
                                  _isEstimatedTimeExplicitlySet = true;
                                });
                              },
                              valueSuffix: _translationService.translate(SharedTranslationKeys.minutesShort),
                              iconSize: 20,
                            ),
                            SizedBox(width: AppTheme.sizeSmall),
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              onPressed: () {
                                setState(() {
                                  _estimatedTime = 0;
                                  _isEstimatedTimeExplicitlySet = false;
                                });
                              },
                              tooltip: _translationService.translate(TaskTranslationKeys.quickTaskEstimatedTimeNotSet),
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return dialogContent;
  }

  Widget _buildQuickActionButtons() {
    final iconSize = AppTheme.iconSizeMedium;
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Lock settings button
        IconButton(
          icon: Icon(
            Icons.lock_outline,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          onPressed: _showLockSettingsDialog,
          tooltip: _translationService.translate(TaskTranslationKeys.quickTaskLockSettings),
          iconSize: iconSize,
        ),

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
          ),
          isLocked: _lockTags,
        ),

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
          ),
          isLocked: _lockPriority,
        ),

        // Estimated time button with lock indicator
        _buildActionButtonWithLock(
          child: IconButton(
            icon: (_estimatedTime != null && _estimatedTime! > 0)
                ? Container(
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
                  )
                : Icon(
                    TaskUiConstants.estimatedTimeIcon,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            onPressed: _toggleEstimatedTime,
            tooltip: _estimatedTime != null
                ? _getEstimatedTimeTooltip()
                : _translationService.translate(TaskTranslationKeys.quickTaskEstimatedTimeNotSet),
            iconSize: iconSize,
          ),
          isLocked: _lockEstimatedTime,
        ),

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
          ),
          isLocked: _lockPlannedDate,
        ),

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
          ),
          isLocked: _lockDeadlineDate,
        ),

        // Clear all button
        IconButton(
          icon: Icon(
            Icons.close,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          onPressed: _onClearAllFields,
          tooltip: _translationService.translate(TaskTranslationKeys.quickTaskResetAll),
          iconSize: iconSize,
        ),
      ],
    );
  }

  Widget _buildActionButtonWithLock({
    required Widget child,
    required bool isLocked,
  }) {
    final theme = Theme.of(context);

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
                size: 12,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}
