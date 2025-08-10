import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/src/presentation/ui/shared/components/color_picker.dart';
import 'package:whph/src/presentation/ui/shared/components/color_preview.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';

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
  final _translationService = container.resolve<ITranslationService>();

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
    Color tempColor = _selectedColor;

    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(_translationService.translate(SharedTranslationKeys.selectColorTitle)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400, // Fixed height for consistent sizing
          child: ColorPicker(
            pickerColor: _selectedColor,
            onChangeColor: (color) {
              tempColor = color;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_translationService.translate(SharedTranslationKeys.cancelButton)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(tempColor),
            child: Text(_translationService.translate(SharedTranslationKeys.confirmSelection)),
          ),
        ],
      ),
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
      child: GestureDetector(
        onTap: _onColorSelectionOpen,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Icon (if provided)
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: AppTheme.iconSizeSmall,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ],

              // Label (if provided)
              if (widget.label != null) ...[
                Expanded(
                  child: Text(
                    widget.label!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Color Preview
                    ColorPreview(color: _selectedColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
