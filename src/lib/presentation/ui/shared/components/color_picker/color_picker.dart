import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as flutter_colorpicker;

import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/constants/shared_translation_keys.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';

class ColorPicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
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
                      Text(translationService.translate(SharedTranslationKeys.colorPickerPaletteTab)),
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
                      Text(translationService.translate(SharedTranslationKeys.colorPickerCustomTab)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab View Section
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface1,
                borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                child: TabBarView(
                  children: [
                    // Material Picker Tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.sizeLarge),
                      child: flutter_colorpicker.MaterialPicker(
                        pickerColor: pickerColor,
                        onColorChanged: onChangeColor,
                        enableLabel: false,
                      ),
                    ),

                    // Custom Color Picker Tab
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.sizeLarge),
                      child: SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const fixedWidth = 260.0;
                            final pickerWidth = constraints.maxWidth < fixedWidth ? constraints.maxWidth : fixedWidth;

                            return Center(
                              child: SizedBox(
                                width: AppThemeHelper.isSmallScreen(context) ? pickerWidth : 600,
                                child: flutter_colorpicker.ColorPicker(
                                  pickerColor: pickerColor,
                                  onColorChanged: onChangeColor,
                                  displayThumbColor: true,
                                  enableAlpha: false,
                                  hexInputBar: true,
                                  colorPickerWidth: pickerWidth,
                                  pickerAreaBorderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                                  pickerAreaHeightPercent: 0.7,
                                  portraitOnly: AppThemeHelper.isSmallScreen(context),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
