import 'package:acore/acore.dart';
import 'package:flutter/material.dart';

import 'package:whph/shared/components/color_picker/color_picker_dialog.dart';
import 'package:whph/shared/components/color_picker/color_preview.dart';
import 'package:whph/shared/constants/app_theme.dart';

class ColorField extends StatefulWidget {
  final Color? initialColor;
  final ValueChanged<Color> onColorChanged;
  final String? label;
  final IconData? icon;
  final String? hintText;
  final EdgeInsetsGeometry? padding;

  const ColorField({
    super.key,
    this.initialColor,
    required this.onColorChanged,
    this.label,
    this.icon,
    this.hintText,
    this.padding,
  });

  @override
  State<ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<ColorField> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor ?? Colors.blue;
  }

  @override
  void didUpdateWidget(ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialColor != oldWidget.initialColor && widget.initialColor != null) {
      _selectedColor = widget.initialColor!;
    }
  }

  Future<void> _onColorSelectionOpen() async {
    final selectedColor = await ResponsiveDialogHelper.showResponsiveDialog<Color>(
      context: context,
      isScrollable: false,
      child: ColorPickerDialog(initialColor: _selectedColor),
    );

    if (selectedColor != null && mounted) {
      setState(() {
        _selectedColor = selectedColor;
      });
      widget.onColorChanged(selectedColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: InkWell(
        onTap: _onColorSelectionOpen,
        borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.sizeSmall,
            top: AppTheme.size2XSmall,
            bottom: AppTheme.size2XSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ColorPreview(color: _selectedColor),
              if (widget.label != null) ...[
                const SizedBox(width: AppTheme.sizeSmall),
                Expanded(
                  child: Text(
                    widget.label!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
              if (widget.icon != null) ...[
                const SizedBox(width: AppTheme.sizeSmall),
                Icon(
                  widget.icon,
                  size: AppTheme.iconSizeSmall,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
