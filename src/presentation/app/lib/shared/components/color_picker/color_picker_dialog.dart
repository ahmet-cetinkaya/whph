import 'package:flutter/material.dart';
import 'package:whph/main.dart';
import 'package:whph/shared/components/color_picker/color_picker.dart';
import 'package:whph/shared/constants/shared_translation_keys.dart';
import 'package:whph/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/shared/constants/app_theme.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;
  final _translationService = container.resolve<ITranslationService>();

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _translationService.translate(SharedTranslationKeys.selectColorTitle),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selectedColor),
            child: Text(_translationService.translate(SharedTranslationKeys.doneButton)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.sizeSmall,
                  AppTheme.sizeSmall,
                  AppTheme.sizeSmall,
                  0,
                ),
                child: ColorPicker(
                  pickerColor: _selectedColor,
                  onChangeColor: (color) {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  translationService: _translationService,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
