import 'package:flutter/material.dart';
import 'package:domain/features/tasks/task.dart';
import 'package:whph/main.dart';

import 'package:whph/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:acore/acore.dart' as acore;
import 'package:acore/utils/dialog_size.dart';
import 'package:whph/presentation/ui/features/tasks/components/dialogs/priority_selection_dialog.dart';

class PrioritySelectField extends StatelessWidget {
  final EisenhowerPriority? value;
  final ValueChanged<EisenhowerPriority?> onChanged;

  const PrioritySelectField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _showPrioritySelection(BuildContext context) async {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);

    // Use a temporary variable to track selection
    EisenhowerPriority? tempSelectedPriority = value;

    await acore.ResponsiveDialogHelper.showResponsiveDialog<void>(
      context: context,
      size: DialogSize.xLarge,
      child: StatefulBuilder(
        builder: (context, setState) {
          return PrioritySelectionDialog(
            selectedPriority: tempSelectedPriority,
            onPrioritySelected: (priority) {
              setState(() {
                tempSelectedPriority = priority;
              });
              // Call the callback immediately as per original behavior
              onChanged(priority);
              // Close the dialog
              Navigator.of(context).pop();
            },
            translationService: translationService,
            theme: theme,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translationService = container.resolve<ITranslationService>();

    final label = TaskUiConstants.getPriorityTooltip(value, translationService);

    return InkWell(
      onTap: () => _showPrioritySelection(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: AppTheme.sizeMedium),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: value != null
                      ? TaskUiConstants.getPriorityColor(value)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
