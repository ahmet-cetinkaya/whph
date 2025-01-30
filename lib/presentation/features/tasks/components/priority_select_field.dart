import 'package:flutter/material.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';
import 'package:whph/presentation/features/tasks/constants/task_ui_constants.dart';
import 'package:whph/presentation/features/tasks/constants/task_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

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
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _translationService.translate(TaskTranslationKeys.prioritySelectionTitle),
                    style: AppTheme.headlineSmall,
                  ),
                ),
                ...widget.options.map((option) => _buildPriorityOption(context, option)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityOption(BuildContext context, DropdownOption<EisenhowerPriority?> option) {
    final isSelected = widget.value == option.value;
    final textColor = option.value != null ? TaskUiConstants.getPriorityColor(option.value) : AppTheme.lightTextColor;

    return InkWell(
      onTap: () {
        widget.onChanged(option.value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surface3 : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(TaskUiConstants.priorityIcon, color: textColor, size: AppTheme.fontSizeLarge),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: AppTheme.bodySmall.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(Icons.check, size: AppTheme.fontSizeLarge),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isHovered ? AppTheme.surface2.withAlpha((255 * 0.5).toInt()) : AppTheme.surface1,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedOption.label,
                  style: AppTheme.bodySmall,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: AppTheme.fontSizeLarge),
            ],
          ),
        ),
      ),
    );
  }
}
