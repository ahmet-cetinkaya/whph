import 'package:flutter/material.dart';
import 'package:whph/domain/features/tasks/task.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/models/dropdown_option.dart';

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
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Select Priority',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
            Text(
              option.label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.lightTextColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(Icons.check, size: 16),
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
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
