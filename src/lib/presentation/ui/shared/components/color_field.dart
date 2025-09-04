import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/components/color_picker.dart';
import 'package:whph/presentation/ui/shared/components/color_preview.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

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
    final theme = Theme.of(context);

    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          _translationService.translate(SharedTranslationKeys.selectColorTitle),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ColorPicker(
            pickerColor: _selectedColor,
            onChangeColor: (color) {
              tempColor = color;
            },
          ),
        ),
        contentPadding:
            const EdgeInsets.fromLTRB(AppTheme.sizeLarge, AppTheme.sizeSmall, AppTheme.sizeLarge, AppTheme.sizeLarge),
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
      child: InkWell(
        onTap: _onColorSelectionOpen,
        borderRadius: BorderRadius.circular(AppTheme.sizeSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.size2XSmall),
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
