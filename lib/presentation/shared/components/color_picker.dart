import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as flutter_colorpicker;
import 'package:whph/main.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';
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
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.palette),
                text: translationService.translate(SharedTranslationKeys.colorPickerPaletteTab),
                key: const Key('color_picker_palette_tab'),
              ),
              Tab(
                icon: Icon(Icons.gradient),
                text: translationService.translate(SharedTranslationKeys.colorPickerCustomTab),
                key: const Key('color_picker_custom_tab'),
              ),
            ],
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  child: flutter_colorpicker.MaterialPicker(
                    pickerColor: pickerColor,
                    onColorChanged: onChangeColor,
                  ),
                ),
                SingleChildScrollView(
                  child: flutter_colorpicker.ColorPicker(
                    pickerColor: pickerColor,
                    onColorChanged: onChangeColor,
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
