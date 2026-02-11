import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as flutter_colorpicker;

import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';

class _ColorPickerConstants {
  static const double pickerWidth = 300.0;
  static const double pickerAreaHeightPercent = 0.7;
  static const double blockPickerSpacing = 14.0;
  static const double blockPickerItemSize = 50.0;

  static const List<Color> paletteColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];
}

class ColorPicker extends StatefulWidget {
  final Color pickerColor;
  final ValueChanged<Color> onChangeColor;
  final ITranslationService translationService;

  const ColorPicker({
    super.key,
    required this.pickerColor,
    required this.onChangeColor,
    required this.translationService,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    // Always rebuild when the tab changes so content depending on
    // _tabController.index stays in sync, including programmatic changes.
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Standard safe area padding is enough since we are now scrolling naturally.
    final scrollPadding = EdgeInsets.only(bottom: bottomPadding + 20.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab Bar Section
        Container(
          margin: const EdgeInsets.only(bottom: AppTheme.sizeMedium),
          decoration: BoxDecoration(
            color: AppTheme.surface1,
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          ),
          padding: const EdgeInsets.all(AppTheme.size2XSmall),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius - AppTheme.size2XSmall),
            ),
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            tabs: [
              Tab(
                height: AppTheme.buttonSizeLarge,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.palette, size: AppTheme.iconSizeMedium),
                    const SizedBox(width: AppTheme.sizeSmall),
                    Text(widget.translationService.translate(SharedTranslationKeys.colorPickerPaletteTab)),
                  ],
                ),
              ),
              Tab(
                height: AppTheme.buttonSizeLarge,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gradient, size: AppTheme.iconSizeMedium),
                    const SizedBox(width: AppTheme.sizeSmall),
                    Text(widget.translationService.translate(SharedTranslationKeys.colorPickerCustomTab)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab View Section (Content)
        Card(
          elevation: 0,
          color: AppTheme.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          ),
          child: _buildTabContent(scrollPadding),
        ),
      ],
    );
  }

  Widget _buildTabContent(EdgeInsets scrollPadding) {
    if (_tabController.index == 0) {
      // Material Picker Tab
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: Column(
          children: [
            SizedBox(
              width: _ColorPickerConstants.pickerWidth,
              child: flutter_colorpicker.BlockPicker(
                pickerColor: widget.pickerColor,
                onColorChanged: (color) => widget.onChangeColor(color.withAlpha(255)),
                availableColors: _ColorPickerConstants.paletteColors,
                layoutBuilder: (context, colors, child) {
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: _ColorPickerConstants.blockPickerSpacing,
                    runSpacing: _ColorPickerConstants.blockPickerSpacing,
                    children: colors.map((Color color) => child(color)).toList(),
                  );
                },
                itemBuilder: (color, isCurrentColor, changeColor) {
                  return GestureDetector(
                    onTap: changeColor,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _ColorPickerConstants.blockPickerItemSize,
                      height: _ColorPickerConstants.blockPickerItemSize,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isCurrentColor
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              )
                            : Border.all(
                                color: flutter_colorpicker.useWhiteForeground(color)
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.1),
                                width: 1,
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: scrollPadding.bottom),
          ],
        ),
      );
    } else {
      // Custom Color Picker Tab
      return Padding(
        padding: const EdgeInsets.all(AppTheme.sizeLarge),
        child: SizedBox(
          width: _ColorPickerConstants.pickerWidth,
          child: flutter_colorpicker.ColorPicker(
            pickerColor: widget.pickerColor,
            onColorChanged: (color) => widget.onChangeColor(color.withAlpha(255)),
            displayThumbColor: true,
            enableAlpha: false,
            hexInputBar: false,
            pickerAreaBorderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
            pickerAreaHeightPercent: _ColorPickerConstants.pickerAreaHeightPercent,
            portraitOnly: true,
          ),
        ),
      );
    }
  }
}
