import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tags/components/tag_select_dropdown.dart';
import '../controllers/quick_add_task_controller.dart';
import 'quick_action_icon_button.dart';
import 'lockable_action_button.dart';
import 'estimated_time_indicator.dart';

/// Quick action buttons row for the QuickAddTaskDialog.
class QuickActionButtonsBar extends StatelessWidget {
  final QuickAddTaskController controller;
  final TextEditingController descriptionController;
  final VoidCallback onShowPriorityDialog;
  final VoidCallback onShowEstimatedTimeDialog;
  final VoidCallback onShowDescriptionDialog;
  final VoidCallback onSelectPlannedDate;
  final VoidCallback onSelectDeadlineDate;
  final VoidCallback onClearAllFields;
  final Widget? tagLockAction;
  final bool isMobile;

  const QuickActionButtonsBar({
    super.key,
    required this.controller,
    required this.descriptionController,
    required this.onShowPriorityDialog,
    required this.onShowEstimatedTimeDialog,
    required this.onShowDescriptionDialog,
    required this.onSelectPlannedDate,
    required this.onSelectDeadlineDate,
    required this.onClearAllFields,
    this.tagLockAction,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = AppTheme.iconSizeMedium;
    final buttonGap = isMobile ? 2.0 : AppTheme.sizeXSmall;
    final buttonStyle = QuickActionIconButton.getQuickActionButtonStyle(theme);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTagsButton(theme, iconSize, buttonStyle),
        SizedBox(width: buttonGap),
        _buildPriorityButton(theme, iconSize),
        SizedBox(width: buttonGap),
        _buildEstimatedTimeButton(theme, iconSize),
        SizedBox(width: buttonGap),
        _buildDescriptionButton(theme, iconSize),
        SizedBox(width: buttonGap),
        _buildPlannedDateButton(theme, iconSize),
        SizedBox(width: buttonGap),
        _buildDeadlineDateButton(theme, iconSize),
        SizedBox(width: buttonGap),
        _buildClearButton(theme, iconSize),
      ],
    );
  }

  Widget _buildTagsButton(ThemeData theme, double iconSize, ButtonStyle buttonStyle) {
    return LockableActionButton(
      isLocked: controller.lockTags,
      child: TagSelectDropdown(
        initialSelectedTags: controller.selectedTags,
        isMultiSelect: true,
        tooltip: controller.getTagsTooltip(),
        onTagsSelected: (tags, _) => controller.setSelectedTags(tags),
        iconSize: iconSize,
        color: controller.selectedTags.isEmpty
            ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
            : controller.getTagColor(),
        headerAction: tagLockAction,
        buttonStyle: buttonStyle,
      ),
    );
  }

  Widget _buildPriorityButton(ThemeData theme, double iconSize) {
    return LockableActionButton(
      isLocked: controller.lockPriority,
      child: QuickActionIconButton(
        icon: controller.selectedPriority == null ? TaskUiConstants.priorityOutlinedIcon : TaskUiConstants.priorityIcon,
        color: controller.getPriorityColor(),
        onPressed: onShowPriorityDialog,
        tooltip: controller.getPriorityTooltip(),
        iconSize: iconSize,
      ),
    );
  }

  Widget _buildEstimatedTimeButton(ThemeData theme, double iconSize) {
    return LockableActionButton(
      isLocked: controller.lockEstimatedTime,
      child: QuickActionIconButton(
        iconWidget: EstimatedTimeIndicator(
          estimatedTime: controller.estimatedTime,
          isExplicitlySet: controller.isEstimatedTimeExplicitlySet,
        ),
        onPressed: () {
          controller.toggleEstimatedTimeSection();
          if (controller.showEstimatedTimeSection) onShowEstimatedTimeDialog();
        },
        tooltip: controller.getEstimatedTimeTooltip(),
        iconSize: iconSize,
      ),
    );
  }

  Widget _buildDescriptionButton(ThemeData theme, double iconSize) {
    final hasDescription = descriptionController.text.isNotEmpty;
    return LockableActionButton(
      isLocked: false,
      child: QuickActionIconButton(
        icon: hasDescription ? Icons.description : Icons.description_outlined,
        color: hasDescription ? theme.colorScheme.primary : null,
        onPressed: () {
          controller.toggleDescriptionSection();
          if (controller.showDescriptionSection) onShowDescriptionDialog();
        },
        tooltip: hasDescription
            ? controller.translationService.translate(TaskTranslationKeys.descriptionLabel)
            : controller.translationService.translate(TaskTranslationKeys.addDescriptionHint),
        iconSize: iconSize,
      ),
    );
  }

  Widget _buildPlannedDateButton(ThemeData theme, double iconSize) {
    return LockableActionButton(
      isLocked: controller.lockPlannedDate,
      child: QuickActionIconButton(
        icon:
            controller.plannedDate == null ? TaskUiConstants.plannedDateOutlinedIcon : TaskUiConstants.plannedDateIcon,
        color: controller.plannedDate == null ? null : TaskUiConstants.plannedDateColor,
        onPressed: onSelectPlannedDate,
        tooltip: controller.getDateTooltip(false),
        iconSize: iconSize,
      ),
    );
  }

  Widget _buildDeadlineDateButton(ThemeData theme, double iconSize) {
    return LockableActionButton(
      isLocked: controller.lockDeadlineDate,
      child: QuickActionIconButton(
        icon: controller.deadlineDate == null
            ? TaskUiConstants.deadlineDateOutlinedIcon
            : TaskUiConstants.deadlineDateIcon,
        color: controller.deadlineDate == null ? null : TaskUiConstants.deadlineDateColor,
        onPressed: onSelectDeadlineDate,
        tooltip: controller.getDateTooltip(true),
        iconSize: iconSize,
      ),
    );
  }

  Widget _buildClearButton(ThemeData theme, double iconSize) {
    return QuickActionIconButton(
      icon: Icons.close,
      onPressed: onClearAllFields,
      tooltip: controller.translationService.translate(TaskTranslationKeys.quickTaskResetAll),
      iconSize: iconSize,
    );
  }
}
