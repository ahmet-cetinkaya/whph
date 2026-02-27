import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:acore/acore.dart' as acore;
import 'package:acore/utils/dialog_size.dart';

import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';

import 'package:whph/presentation/ui/features/tasks/models/task_data.dart';
import 'package:whph/presentation/ui/features/tasks/utils/task_date_display_helper.dart';
import 'builders/estimated_time_dialog_content.dart';
import 'builders/description_dialog_content.dart';

import '../dialogs/priority_selection_dialog.dart';
import 'dialogs/clear_fields_confirmation_dialog.dart';
import 'controllers/quick_add_task_controller.dart';
import 'components/quick_action_buttons_bar.dart';

import '../task_date_picker_dialog.dart';
import '../../pages/task_details_page.dart';

enum LockType {
  priority,
  estimatedTime,
  plannedDate,
  deadlineDate,
  tags,
}

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

    Future<T?> showDialogFuture;
    if (isMobile) {
      showDialogFuture = showMaterialModalBottomSheet<T>(
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
      showDialogFuture = showDialog<T>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) => Dialog(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppTheme.dialogMaxWidthMedium,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: dialog,
            ),
          ),
        ),
      );
    }

    return showDialogFuture.then((result) async {
      if (result is String && result.isNotEmpty) {
        if (context.mounted) {
          try {
            await acore.ResponsiveDialogHelper.showResponsiveDialog(
              context: context,
              child: TaskDetailsPage(
                taskId: result,
                hideSidebar: true,
              ),
              size: DialogSize.max,
            );
          } catch (e, stackTrace) {
            Logger.error(
              'Failed to navigate to task details after dialog result',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
      }
      return result;
    }).catchError((error, stackTrace) {
      Logger.error(
        'Error in dialog result handling',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    });
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

    if (widget.initialTitle != null) _titleController.text = widget.initialTitle!;
    if (widget.initialDescription != null) _descriptionController.text = widget.initialDescription!;

    _controller.initialize();
    _controller.addListener(_onControllerUpdate);
    _titleController.addListener(_onControllerUpdate);
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
      _plannedDateController.text = TaskDateDisplayHelper.formatForInput(_controller.plannedDate!, context);
    }
    if (_controller.deadlineDate != null && _deadlineDateController.text.isEmpty) {
      _deadlineDateController.text = TaskDateDisplayHelper.formatForInput(_controller.deadlineDate!, context);
    }
  }

  void _toggleLock(LockType lockType) {
    switch (lockType) {
      case LockType.priority:
        _controller.togglePriorityLock();
        break;
      case LockType.estimatedTime:
        _controller.toggleEstimatedTimeLock();
        break;
      case LockType.plannedDate:
        _controller.togglePlannedDateLock();
        break;
      case LockType.deadlineDate:
        _controller.toggleDeadlineDateLock();
        break;
      case LockType.tags:
        _controller.toggleTagsLock();
        break;
    }
    setState(() {});
  }

  Widget _buildLockAction(ValueGetter<bool> isLockedGetter, VoidCallback onToggle) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isLocked = isLockedGetter();
        final theme = Theme.of(context);
        return IconButton(
          icon: Icon(
            isLocked ? Icons.lock : Icons.lock_open,
            color: isLocked ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
          onPressed: onToggle,
          tooltip: _controller.translationService.translate(
            isLocked ? TaskTranslationKeys.quickTaskUnlock : TaskTranslationKeys.quickTaskLock,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _titleController.removeListener(_onControllerUpdate);
    _titleController.dispose();
    _descriptionController.dispose();
    _plannedDateController.dispose();
    _deadlineDateController.dispose();
    _focusNode.dispose();
    _controller.dispose();
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
        headerActions: [
          _buildLockAction(
            () => _controller.lockPlannedDate,
            () => _toggleLock(LockType.plannedDate),
          ),
        ],
      ),
    );

    if (result != null && !result.wasCancelled && mounted) {
      _controller.setPlannedDate(result.selectedDate, result.reminderTime ?? ReminderTime.none);
      if (result.selectedDate != null) {
        _plannedDateController.text = TaskDateDisplayHelper.formatForInput(result.selectedDate!, context);
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
        headerActions: [
          _buildLockAction(
            () => _controller.lockDeadlineDate,
            () => _toggleLock(LockType.deadlineDate),
          ),
        ],
      ),
    );

    if (result != null && !result.wasCancelled && mounted) {
      _controller.setDeadlineDate(result.selectedDate, result.reminderTime ?? ReminderTime.none);
      if (result.selectedDate != null) {
        _deadlineDateController.text = TaskDateDisplayHelper.formatForInput(result.selectedDate!, context);
      } else {
        _deadlineDateController.clear();
      }
    }
  }

  Future<void> _showPrioritySelectionDialog() async {
    EisenhowerPriority? tempPriority = _controller.selectedPriority;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.xLarge,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return PrioritySelectionDialog(
            selectedPriority: tempPriority,
            onPrioritySelected: (EisenhowerPriority? priority) {
              setDialogState(() => tempPriority = priority);
            },
            translationService: _controller.translationService,
            theme: Theme.of(context),
            headerAction: _buildLockAction(
              () => _controller.lockPriority,
              () => _toggleLock(LockType.priority),
            ),
          );
        },
      ),
    );

    if (mounted) _controller.setSelectedPriority(tempPriority);
  }

  Future<void> _showEstimatedTimeDialog() async {
    int tempEstimatedTime = _controller.estimatedTime ?? 0;
    bool tempIsExplicitlySet = _controller.isEstimatedTimeExplicitlySet;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.xLarge,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return EstimatedTimeDialogContent(
            selectedTime: tempEstimatedTime,
            onTimeSelected: (value) {
              setDialogState(() {
                tempEstimatedTime = value;
                tempIsExplicitlySet = true;
              });
            },
            onConfirm: () => _controller.setEstimatedTime(tempEstimatedTime, isExplicit: tempIsExplicitlySet),
            translationService: _controller.translationService,
            theme: Theme.of(context),
            headerAction: _buildLockAction(
              () => _controller.lockEstimatedTime,
              () => _toggleLock(LockType.estimatedTime),
            ),
          );
        },
      ),
    );

    if (mounted) _controller.setShowEstimatedTimeSection(false);
  }

  Future<void> _showDescriptionDialog() async {
    String tempDescription = _descriptionController.text;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.xLarge,
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return DescriptionDialogContent(
            description: tempDescription,
            onChanged: (value) => setDialogState(() => tempDescription = value),
            translationService: _controller.translationService,
            theme: Theme.of(context),
          );
        },
      ),
    );

    if (mounted) {
      _descriptionController.text = tempDescription;
      _controller.setShowDescriptionSection(false);
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

  void _createAndOpenTask() {
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
      onSuccess: (taskId) {
        Navigator.pop(context, taskId);
      },
    );
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
                  child: QuickActionButtonsBar(
                    controller: _controller,
                    descriptionController: _descriptionController,
                    onShowPriorityDialog: _showPrioritySelectionDialog,
                    onShowEstimatedTimeDialog: _showEstimatedTimeDialog,
                    onShowDescriptionDialog: _showDescriptionDialog,
                    onSelectPlannedDate: _selectPlannedDate,
                    onSelectDeadlineDate: _selectDeadlineDate,
                    onClearAllFields: _onClearAllFields,
                    tagLockAction: _buildLockAction(() => _controller.lockTags, () => _toggleLock(LockType.tags)),
                    isMobile: isMobile,
                  ),
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
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOpenTaskButton(theme, isMobile),
            _buildSendButton(theme, isMobile),
          ],
        ),
      ),
      onSubmitted: (_) => _createTask(),
    );
  }

  Widget _buildSendButton(ThemeData theme, bool isMobile) {
    final isEnabled = _titleController.text.trim().isNotEmpty && !_controller.isLoading;
    return SizedBox(
      width: AppTheme.buttonSizeLarge,
      height: AppTheme.buttonSizeLarge,
      child: IconButton(
        icon: Icon(
          _controller.isLoading ? Icons.hourglass_empty : Icons.send,
          color: isEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
        ),
        onPressed: isEnabled ? _createTask : null,
        iconSize: AppTheme.iconSizeMedium + 4.0,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: AppTheme.buttonSizeLarge,
          minHeight: AppTheme.buttonSizeLarge,
        ),
        tooltip: _controller.translationService.translate(TaskTranslationKeys.addTaskButtonTooltip),
      ),
    );
  }

  Widget _buildOpenTaskButton(ThemeData theme, bool isMobile) {
    final isEnabled = _titleController.text.trim().isNotEmpty && !_controller.isLoading;
    return SizedBox(
      width: AppTheme.buttonSizeLarge,
      height: AppTheme.buttonSizeLarge,
      child: IconButton(
        icon: Icon(
          Icons.open_in_new,
          color: isEnabled
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
        ),
        onPressed: isEnabled ? _createAndOpenTask : null,
        iconSize: AppTheme.iconSizeMedium + 4.0,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: AppTheme.buttonSizeLarge,
          minHeight: AppTheme.buttonSizeLarge,
        ),
        tooltip: _controller.translationService.translate(TaskTranslationKeys.createAndOpenTaskTooltip),
      ),
    );
  }
}
