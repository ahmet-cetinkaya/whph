import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as flutter_colorpicker;
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import '../constants/shared_translation_keys.dart';

class ColorPicker extends StatelessWidget {
  final Color pickerColor;
  final ValueChanged<Color> onChangeColor;

  const ColorPicker({super.key, required this.pickerColor, required this.onChangeColor});

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab Bar Section
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(
                key: const Key('color_picker_palette_tab'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.palette),
                    const SizedBox(width: 8),
                    Text(translationService.translate(SharedTranslationKeys.colorPickerPaletteTab)),
                  ],
                ),
              ),
              Tab(
                key: const Key('color_picker_custom_tab'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gradient),
                    const SizedBox(width: 8),
                    Text(translationService.translate(SharedTranslationKeys.colorPickerCustomTab)),
                  ],
                ),
              ),
            ],
          ),

          // Tab View Section
          Expanded(
            child: TabBarView(
              children: [
                // Material Picker Tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: flutter_colorpicker.MaterialPicker(
                      pickerColor: pickerColor,
                      onColorChanged: onChangeColor,
                    ),
                  ),
                ),

                // Custom Color Picker Tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return flutter_colorpicker.ColorPicker(
                          pickerColor: pickerColor,
                          onColorChanged: onChangeColor,
                          // Ensure picker fits within available width
                          pickerAreaHeightPercent: 0.7,
                          displayThumbColor: true,
                          enableAlpha: false,
                          // Constrain the color picker to available width
                          portraitOnly: true,
                          hexInputBar: true,
                          colorPickerWidth: constraints.maxWidth > 200 ? 200 : constraints.maxWidth - 32,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
