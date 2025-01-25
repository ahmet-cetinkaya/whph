import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as flutter_colorpicker;

class ColorPicker extends StatelessWidget {
  final Color pickerColor;
  final ValueChanged<Color> onChangeColor;

  const ColorPicker({super.key, required this.pickerColor, required this.onChangeColor});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TabBar(
            tabs: [
              Tab(icon: Icon(Icons.palette), text: "Colors"),
              Tab(icon: Icon(Icons.gradient), text: "Custom"),
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
