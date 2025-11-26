import 'package:flutter/material.dart';
import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:acore/acore.dart' as acore;

/// Dialog content component for selecting task priority
/// Follows the established architectural pattern of other dialog content components
class PrioritySelectionDialogContent extends StatelessWidget {
  final EisenhowerPriority? selectedPriority;
  final ValueChanged<EisenhowerPriority?> onPrioritySelected;
  final ITranslationService translationService;
  final ThemeData theme;

  const PrioritySelectionDialogContent({
    super.key,
    required this.selectedPriority,
    required this.onPrioritySelected,
    required this.translationService,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        title: Text(translationService.translate(TaskTranslationKeys.priorityLabel)),
        automaticallyImplyLeading: true,
        actions: [
          if (selectedPriority != null)
            IconButton(
              onPressed: () => onPrioritySelected(null),
              icon: const Icon(Icons.clear),
              tooltip: translationService.translate(TaskTranslationKeys.priorityNoneTooltip),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translationService.translate(SharedTranslationKeys.doneButton)),
          ),
          const SizedBox(width: AppTheme.sizeSmall),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Information card
                  InformationCard.themed(
                    context: context,
                    icon: Icons.info_outline,
                    text: translationService.translate(TaskTranslationKeys.priorityDescription),
                  ),

                  const SizedBox(height: AppTheme.sizeLarge),

                  // No Priority Option
                  _buildPriorityOptionTile(
                    context: context,
                    title: translationService.translate(TaskTranslationKeys.priorityNoneTooltip),
                    icon: TaskUiConstants.priorityOutlinedIcon,
                    iconColor: AppTheme.secondaryTextColor,
                    isSelected: selectedPriority == null,
                    onTap: () => onPrioritySelected(null),
                  ),

                  const SizedBox(height: AppTheme.sizeSmall),

                  // Priority Options (High to Low)
                  ...[
                    EisenhowerPriority.urgentImportant,
                    EisenhowerPriority.notUrgentImportant,
                    EisenhowerPriority.urgentNotImportant,
                    EisenhowerPriority.notUrgentNotImportant,
                  ].map((priority) {
                    return _buildPriorityOptionTile(
                      context: context,
                      title: TaskUiConstants.getPriorityTooltip(priority, translationService),
                      icon: TaskUiConstants.priorityIcon,
                      iconColor: TaskUiConstants.getPriorityColor(priority),
                      isSelected: selectedPriority == priority,
                      onTap: () => onPrioritySelected(priority),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityOptionTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Calculate accessible text color based on background
    final Color backgroundColor = isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface;
    final Color textColor = acore.ColorContrastHelper.getContrastingTextColor(backgroundColor);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check,
              color: acore.ColorContrastHelper.getContrastingTextColor(theme.colorScheme.primaryContainer),
              size: 20,
            )
          : null,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
