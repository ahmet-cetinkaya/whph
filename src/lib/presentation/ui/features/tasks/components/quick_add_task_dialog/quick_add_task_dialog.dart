import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:acore/acore.dart' as acore;
import 'package:acore/utils/dialog_size.dart';

import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'builders/estimated_time_dialog_content.dart';
import 'builders/description_dialog_content.dart';

import '../dialogs/priority_selection_dialog.dart';
import 'dialogs/lock_settings_dialog_content.dart';
import 'dialogs/clear_fields_confirmation_dialog.dart';
import 'models/lock_settings_state.dart';
import 'controllers/quick_add_task_controller.dart';

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
      return showMaterialModalBottomSheet<T>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        useRootNavigator: false,
        expand: false,
        builder: (BuildContext context) {
          return AnimatedPadding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            child: dialog,
          );
        },
      );
    } else {
      return showDialog<T>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) => Dialog(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
  late final QuickAddTaskController _controller;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _plannedDateController = TextEditingController();
  final _deadlineDateController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = QuickAddTaskController(
      initialTagIds: widget.initialTagIds,
      initialPlannedDate: widget.initialPlannedDate,
      initialDeadlineDate: widget.initialDeadlineDate,
      initialPriority: widget.initialPriority,
      initialEstimatedTime: widget.initialEstimatedTime,
      initialTitle: widget.initialTitle,
      initialDescription: widget.initialDescription,
      initialCompleted: widget.initialCompleted,
      initialParentTaskId: widget.initialParentTaskId,
      onTaskCreated: widget.onTaskCreated,
    );

    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }

    _controller.initialize();
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateDateControllers();
  }

  void _updateDateControllers() {
    if (_controller.plannedDate != null && _plannedDateController.text.isEmpty) {
      _plannedDateController.text = acore.DateFormatService.formatForInput(
        _controller.plannedDate!,
        context,
        type: acore.DateFormatType.dateTime,
      );
    }
    if (_controller.deadlineDate != null && _deadlineDateController.text.isEmpty) {
      _deadlineDateController.text = acore.DateFormatService.formatForInput(
        _controller.deadlineDate!,
        context,
        type: acore.DateFormatType.dateTime,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _plannedDateController.dispose();
    _deadlineDateController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _selectPlannedDate() async {
    final result = await TaskDatePickerDialog.showWithReminder(
      context: context,
      config: TaskDatePickerConfig(
        initialDate: _controller.plannedDate,
        initialReminderTime: _controller.plannedDateReminderTime,
        titleText: _controller.translationService.translate(TaskTranslationKeys.plannedDateLabel),
        showTime: true,
        showQuickRanges: true,
        useResponsiveDesign: true,
        enableFooterActions: true,
        translationService: _controller.translationService,
        minDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      ),
    );

    if (result != null && !result.wasCancelled && mounted) {
      _controller.setPlannedDate(result.selectedDate, result.reminderTime ?? ReminderTime.none);
      if (result.selectedDate != null) {
        _plannedDateController.text = acore.DateFormatService.formatForInput(
          result.selectedDate!,
          context,
          type: acore.DateFormatType.dateTime,
        );
      } else {
        _plannedDateController.clear();
      }
    }
  }

  Future<void> _selectDeadlineDate() async {
    final result = await TaskDatePickerDialog.showWithReminder(
      context: context,
      config: TaskDatePickerConfig(
        initialDate: _controller.deadlineDate,
        initialReminderTime: _controller.deadlineDateReminderTime,
        titleText: _controller.translationService.translate(TaskTranslationKeys.deadlineDateLabel),
        showTime: true,
        showQuickRanges: true,
        useResponsiveDesign: true,
        enableFooterActions: true,
        translationService: _controller.translationService,
        minDate: _controller.plannedDate ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      ),
    );

    if (result != null && !result.wasCancelled && mounted) {
      _controller.setDeadlineDate(result.selectedDate, result.reminderTime ?? ReminderTime.none);
      if (result.selectedDate != null) {
        _deadlineDateController.text = acore.DateFormatService.formatForInput(
          result.selectedDate!,
          context,
          type: acore.DateFormatType.dateTime,
        );
      } else {
        _deadlineDateController.clear();
      }
    }
  }

  Future<void> _showPrioritySelectionDialog() async {
    EisenhowerPriority? tempPriority = _controller.selectedPriority;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return PrioritySelectionDialog(
            selectedPriority: tempPriority,
            onPrioritySelected: (EisenhowerPriority? priority) {
              setDialogState(() => tempPriority = priority);
            },
            translationService: _controller.translationService,
            theme: Theme.of(context),
          );
        },
      ),
    );

    if (mounted) {
      _controller.setSelectedPriority(tempPriority);
    }
  }

  Future<void> _showEstimatedTimeDialog() async {
    int tempEstimatedTime = _controller.estimatedTime ?? 0;
    bool tempIsExplicitlySet = _controller.isEstimatedTimeExplicitlySet;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final theme = Theme.of(context);

          void updateTempTime(int value) {
            setDialogState(() {
              tempEstimatedTime = value;
              tempIsExplicitlySet = true;
            });
          }

          void confirmEstimatedTime() {
            _controller.setEstimatedTime(tempEstimatedTime, isExplicit: tempIsExplicitlySet);
          }

          return EstimatedTimeDialogContent(
            selectedTime: tempEstimatedTime,
            onTimeSelected: updateTempTime,
            onConfirm: confirmEstimatedTime,
            translationService: _controller.translationService,
            theme: theme,
          );
        },
      ),
    );

    if (mounted) {
      _controller.setShowEstimatedTimeSection(false);
    }
  }

  Future<void> _showDescriptionDialog() async {
    String tempDescription = _descriptionController.text;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final theme = Theme.of(context);
          return DescriptionDialogContent(
            description: tempDescription,
            onChanged: (value) => setDialogState(() => tempDescription = value),
            translationService: _controller.translationService,
            theme: theme,
          );
        },
      ),
    );

    if (mounted) {
      _descriptionController.text = tempDescription;
      _controller.setShowDescriptionSection(false);
    }
  }

  Future<void> _showLockSettingsDialog() async {
    LockSettingsState tempLockState = _controller.getLockState();

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.large,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return LockSettingsDialogContent(
            lockState: tempLockState,
            onLockStateChanged: (LockSettingsState newLockState) {
              setDialogState(() => tempLockState = newLockState);
            },
            translationService: _controller.translationService,
            themeService: _controller.themeService,
            theme: Theme.of(context),
            currentPriority: _controller.selectedPriority,
          );
        },
      ),
    );

    if (mounted) {
      _controller.setLockState(tempLockState);
    }
  }

  Future<void> _onClearAllFields() async {
    final confirmed = await ClearFieldsConfirmationDialog.showForQuickTaskClear(
      context: context,
      translationService: _controller.translationService,
    );

    if (!confirmed) return;

    if (mounted) {
      await _controller.clearAllFields(
        titleController: _titleController,
        descriptionController: _descriptionController,
        plannedDateController: _plannedDateController,
        deadlineDateController: _deadlineDateController,
        context: context,
      );
    }
  }

  void _createTask() {
    final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    _controller.createTask(
      context: context,
      title: _titleController.text,
      description: _descriptionController.text,
      focusNode: _focusNode,
      isMobile: isMobile,
      onClearFields: () async {
        await _controller.clearAllFields(
          titleController: _titleController,
          descriptionController: _descriptionController,
          plannedDateController: _plannedDateController,
          deadlineDateController: _deadlineDateController,
          context: context,
        );
      },
    );
  }

  Widget _buildEstimatedTimeIcon() {
    final theme = Theme.of(context);
    final estimatedTime = _controller.estimatedTime;

    if (estimatedTime != null && estimatedTime > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: _controller.isEstimatedTimeExplicitlySet
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          estimatedTime.toString(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: _controller.isEstimatedTimeExplicitlySet
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

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(AppTheme.sizeLarge))
            : BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppTheme.sizeLarge, AppTheme.sizeSmall, AppTheme.sizeLarge, AppTheme.sizeSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMobile) _buildMobileDragHandle(theme) else _buildDesktopHeader(theme),
            _buildTitleInput(theme, isMobile),
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(top: AppTheme.sizeSmall),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildQuickActionButtons(theme, isMobile),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDragHandle(ThemeData theme) {
    return Container(
      width: 32,
      height: 4,
      margin: EdgeInsets.only(bottom: AppTheme.sizeSmall),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildDesktopHeader(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppTheme.sizeLarge),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _controller.translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
            style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput(ThemeData theme, bool isMobile) {
    return TextField(
      controller: _titleController,
      focusNode: _focusNode,
      autofocus: true,
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: _controller.translationService.translate(TaskTranslationKeys.quickTaskTitlePlaceholder),
        contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
        suffixIcon: _buildSendButton(theme, isMobile),
      ),
      onSubmitted: (_) => _createTask(),
    );
  }

  Widget _buildSendButton(ThemeData theme, bool isMobile) {
    if (isMobile) {
      return SizedBox(
        width: AppTheme.iconSizeLarge - 4.0,
        height: AppTheme.iconSizeLarge - 4.0,
        child: IconButton(
          icon: Icon(
            _controller.isLoading ? Icons.hourglass_empty : Icons.send,
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
      );
    }
    return IconButton(
      icon: Icon(_controller.isLoading ? Icons.hourglass_empty : Icons.send, color: theme.colorScheme.primary),
      onPressed: _createTask,
      tooltip: _controller.translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
    );
  }

  Widget _buildQuickActionButtons(ThemeData theme, bool isMobile) {
    final iconSize = AppTheme.iconSizeMedium;
    final buttonGap = isMobile ? 2.0 : AppTheme.sizeXSmall;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIconButton(
          icon: Icons.lock_outline,
          color: _controller.hasAnyLocks ? theme.colorScheme.primary : null,
          onPressed: _showLockSettingsDialog,
          tooltip: _controller.translationService.translate(TaskTranslationKeys.quickTaskLockSettings),
          iconSize: iconSize,
          theme: theme,
        ),
        SizedBox(width: buttonGap),
        _buildActionButtonWithLock(
          child: TagSelectDropdown(
            initialSelectedTags: _controller.selectedTags,
            isMultiSelect: true,
            tooltip: _controller.getTagsTooltip(),
            onTagsSelected: (tags, _) => _controller.setSelectedTags(tags),
            iconSize: iconSize,
            color: _controller.selectedTags.isEmpty
                ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                : _controller.getTagColor(),
            buttonStyle: _getQuickActionButtonStyle(theme),
          ),
          isLocked: _controller.lockTags,
          theme: theme,
        ),
        SizedBox(width: buttonGap),
        _buildActionButtonWithLock(
          child: _buildIconButton(
            icon: _controller.selectedPriority == null
                ? TaskUiConstants.priorityOutlinedIcon
                : TaskUiConstants.priorityIcon,
            color: _controller.getPriorityColor(),
            onPressed: _showPrioritySelectionDialog,
            tooltip: _controller.getPriorityTooltip(),
            iconSize: iconSize,
            theme: theme,
          ),
          isLocked: _controller.lockPriority,
          theme: theme,
        ),
        SizedBox(width: buttonGap),
        _buildActionButtonWithLock(
          child: _buildIconButton(
            iconWidget: _buildEstimatedTimeIcon(),
            onPressed: () {
              _controller.toggleEstimatedTimeSection();
              if (_controller.showEstimatedTimeSection) _showEstimatedTimeDialog();
            },
            tooltip: _controller.getEstimatedTimeTooltip(),
            iconSize: iconSize,
            theme: theme,
          ),
          isLocked: _controller.lockEstimatedTime,
          theme: theme,
        ),
        SizedBox(width: buttonGap),
        _buildActionButtonWithLock(
          child: _buildIconButton(
            icon: _descriptionController.text.isNotEmpty ? Icons.description : Icons.description_outlined,
            color: _descriptionController.text.isNotEmpty ? theme.colorScheme.primary : null,
            onPressed: () {
              _controller.toggleDescriptionSection();
              if (_controller.showDescriptionSection) _showDescriptionDialog();
            },
            tooltip: _descriptionController.text.isNotEmpty
                ? _controller.translationService.translate(TaskTranslationKeys.descriptionLabel)
                : _controller.translationService.translate(TaskTranslationKeys.addDescriptionHint),
            iconSize: iconSize,
            theme: theme,
          ),
          isLocked: false,
          theme: theme,
        ),
        SizedBox(width: buttonGap),
        _buildActionButtonWithLock(
          child: _buildIconButton(
            icon: _controller.plannedDate == null
                ? TaskUiConstants.plannedDateOutlinedIcon
                : TaskUiConstants.plannedDateIcon,
            color: _controller.plannedDate == null ? null : TaskUiConstants.plannedDateColor,
            onPressed: _selectPlannedDate,
            tooltip: _controller.getDateTooltip(false),
            iconSize: iconSize,
            theme: theme,
          ),
          isLocked: _controller.lockPlannedDate,
          theme: theme,
        ),
        SizedBox(width: buttonGap),
        _buildActionButtonWithLock(
          child: _buildIconButton(
            icon: _controller.deadlineDate == null
                ? TaskUiConstants.deadlineDateOutlinedIcon
                : TaskUiConstants.deadlineDateIcon,
            color: _controller.deadlineDate == null ? null : TaskUiConstants.deadlineDateColor,
            onPressed: _selectDeadlineDate,
            tooltip: _controller.getDateTooltip(true),
            iconSize: iconSize,
            theme: theme,
          ),
          isLocked: _controller.lockDeadlineDate,
          theme: theme,
        ),
        SizedBox(width: buttonGap),
        _buildIconButton(
          icon: Icons.close,
          onPressed: _onClearAllFields,
          tooltip: _controller.translationService.translate(TaskTranslationKeys.quickTaskResetAll),
          iconSize: iconSize,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildIconButton({
    IconData? icon,
    Widget? iconWidget,
    Color? color,
    required VoidCallback onPressed,
    required String tooltip,
    required double iconSize,
    required ThemeData theme,
  }) {
    return IconButton(
      icon: iconWidget ?? Icon(icon, color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: iconSize,
      style: _getQuickActionButtonStyle(theme),
    );
  }

  ButtonStyle _getQuickActionButtonStyle(ThemeData theme) {
    return IconButton.styleFrom(
      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2), width: 0.5),
      ),
      padding: EdgeInsets.zero,
      minimumSize: const Size(32, 32),
    );
  }

  Widget _buildActionButtonWithLock({
    required Widget child,
    required bool isLocked,
    required ThemeData theme,
  }) {
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
              child: Icon(Icons.lock, size: AppTheme.iconSize2XSmall, color: theme.colorScheme.primary),
            ),
          ),
      ],
    );
  }
}
