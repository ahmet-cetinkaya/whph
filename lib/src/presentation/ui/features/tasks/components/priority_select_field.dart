import 'package:flutter/material.dart';
import 'package:whph/src/core/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/models/dropdown_option.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/src/presentation/ui/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';

class PrioritySelectField extends StatefulWidget {
  final EisenhowerPriority? value;
  final ValueChanged<EisenhowerPriority?> onChanged;
  final List<DropdownOption<EisenhowerPriority?>> options;

  const PrioritySelectField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.options,
  });

  @override
  State<PrioritySelectField> createState() => _PrioritySelectFieldState();
}

class _PrioritySelectFieldState extends State<PrioritySelectField> {
  final ITranslationService _translationService = container.resolve<ITranslationService>();
  bool isHovered = false;

  void _showPrioritySelection(BuildContext context) {
    final theme = Theme.of(context);

    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sizeLarge),
              child: Text(
                _translationService.translate(TaskTranslationKeys.prioritySelectionTitle),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.options.map((option) => _buildPriorityOption(context, option)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      size: DialogSize.medium,
    );
  }

  Widget _buildPriorityOption(BuildContext context, DropdownOption<EisenhowerPriority?> option) {
    final theme = Theme.of(context);
    final isSelected = widget.value == option.value;
    final textColor = option.value != null
        ? TaskUiConstants.getPriorityColor(option.value)
        : theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return InkWell(
      onTap: () {
        widget.onChanged(option.value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sizeMedium, horizontal: AppTheme.sizeLarge),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
        ),
        child: Row(
          children: [
            Icon(
              TaskUiConstants.priorityIcon,
              color: textColor,
              size: AppTheme.fontSizeLarge,
            ),
            const SizedBox(width: AppTheme.sizeSmall),
            Text(
              option.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(
                Icons.check,
                size: AppTheme.fontSizeLarge,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedOption = widget.options.firstWhere(
      (option) => option.value == widget.value,
      orElse: () => widget.options.first,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: InkWell(
        onTap: () => _showPrioritySelection(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isHovered ? theme.colorScheme.onSurface.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedOption.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.value != null
                        ? TaskUiConstants.getPriorityColor(widget.value)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: AppTheme.fontSizeLarge,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
