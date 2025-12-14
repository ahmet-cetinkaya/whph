import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/features/tags/constants/tag_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:acore/acore.dart' as acore;
import '../models/lock_settings_state.dart';

/// Dialog content component for configuring lock settings in quick task dialog
/// Follows the established architectural pattern of other dialog content components
class LockSettingsDialogContent extends StatelessWidget {
  final LockSettingsState lockState;
  final ValueChanged<LockSettingsState> onLockStateChanged;
  final ITranslationService translationService;
  final IThemeService themeService;
  final ThemeData theme;
  final EisenhowerPriority? currentPriority;

  const LockSettingsDialogContent({
    super.key,
    required this.lockState,
    required this.onLockStateChanged,
    required this.translationService,
    required this.themeService,
    required this.theme,
    this.currentPriority,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(translationService.translate(TaskTranslationKeys.quickTaskLockSettings)),
        automaticallyImplyLeading: true,
        actions: [
          if (lockState.hasAnyLocks)
            IconButton(
              onPressed: () => onLockStateChanged(lockState.copyWithAllCleared()),
              icon: const Icon(Icons.clear),
              tooltip: translationService.translate(TaskTranslationKeys.quickTaskResetAll),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translationService.translate(SharedTranslationKeys.doneButton)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // Description section
              Padding(
                padding: const EdgeInsets.all(AppTheme.sizeMedium),
                child: InformationCard.themed(
                  context: context,
                  icon: Icons.lock_outline,
                  text: translationService.translate(TaskTranslationKeys.quickTaskLockDescription),
                ),
              ),

              // Lock options section
              Expanded(
                child: acore.BorderFadeOverlay(
                  fadeBorders: {acore.FadeBorder.bottom},
                  backgroundColor: theme.colorScheme.surface,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tag lock options
                        _buildLockOptionCheckboxTile(
                          title: translationService.translate(TaskTranslationKeys.tagsLabel),
                          icon: TagUiConstants.tagIcon,
                          iconColor: TaskUiConstants.getTagColor(themeService),
                          value: lockState.lockTags,
                          onChanged: (bool? value) => onLockStateChanged(
                            lockState.updateLockType('tags', value ?? false),
                          ),
                        ),
                        // Priority lock options
                        _buildLockOptionCheckboxTile(
                          title: translationService.translate(TaskTranslationKeys.priorityLabel),
                          icon: TaskUiConstants.priorityOutlinedIcon,
                          iconColor: currentPriority == null
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                              : TaskUiConstants.getPriorityColor(currentPriority),
                          value: lockState.lockPriority,
                          onChanged: (bool? value) => onLockStateChanged(
                            lockState.updateLockType('priority', value ?? false),
                          ),
                        ),
                        // Estimated time lock options
                        _buildLockOptionCheckboxTile(
                          title: translationService.translate(SharedTranslationKeys.timeDisplayEstimated),
                          icon: TaskUiConstants.estimatedTimeOutlinedIcon,
                          iconColor: TaskUiConstants.estimatedTimeColor,
                          value: lockState.lockEstimatedTime,
                          onChanged: (bool? value) => onLockStateChanged(
                            lockState.updateLockType('estimatedTime', value ?? false),
                          ),
                        ),
                        // Planned date lock options
                        _buildLockOptionCheckboxTile(
                          title: translationService.translate(TaskTranslationKeys.plannedDateLabel),
                          icon: TaskUiConstants.plannedDateOutlinedIcon,
                          iconColor: TaskUiConstants.plannedDateColor,
                          value: lockState.lockPlannedDate,
                          onChanged: (bool? value) => onLockStateChanged(
                            lockState.updateLockType('plannedDate', value ?? false),
                          ),
                        ),
                        // Deadline date lock options
                        _buildLockOptionCheckboxTile(
                          title: translationService.translate(TaskTranslationKeys.deadlineDateLabel),
                          icon: TaskUiConstants.deadlineDateOutlinedIcon,
                          iconColor: TaskUiConstants.deadlineDateColor,
                          value: lockState.lockDeadlineDate,
                          onChanged: (bool? value) => onLockStateChanged(
                            lockState.updateLockType('deadlineDate', value ?? false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
}
