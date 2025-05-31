import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/components/color_picker.dart';
import 'package:whph/presentation/shared/components/color_preview.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/shared/enums/dialog_size.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/shared/utils/responsive_dialog_helper.dart';

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

    final selectedColor = await ResponsiveDialogHelper.showResponsiveDialog<Color>(
      context: context,
      size: DialogSize.small,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_translationService.translate(SharedTranslationKeys.selectColorTitle)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.of(context).pop(tempColor);
              },
              tooltip: _translationService.translate(SharedTranslationKeys.confirmSelection),
            ),
            const SizedBox(width: AppTheme.sizeSmall),
          ],
        ),
        body: ColorPicker(
          pickerColor: _selectedColor,
          onChangeColor: (color) {
            tempColor = color;
          },
        ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onColorSelectionOpen,
          borderRadius: BorderRadius.circular(8),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Color Preview
                      ColorPreview(color: _selectedColor),

                      // Edit Icon
                      Icon(
                        SharedUiConstants.editIcon,
                        size: AppTheme.iconSizeSmall,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
