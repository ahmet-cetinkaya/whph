import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/services/theme_service/theme_data_builder.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';

void main() {
  test('ThemeDataBuilder includes fontFamilyFallback', () {
    const builder = ThemeDataBuilder(
      isDark: false,
      primaryColor: Colors.blue,
      densityMultiplier: 1.0,
      surface0: Colors.white,
      surface1: Colors.white,
      surface2: Colors.white,
      surface3: Colors.white,
      textColor: Colors.black,
      secondaryTextColor: Colors.grey,
      lightTextColor: Colors.white,
      dividerColor: Colors.grey,
      barrierColor: Colors.black54,
    );

    final themeData = builder.build(const ColorScheme.light());

    expect(themeData.textTheme.bodyLarge?.fontFamilyFallback, AppTheme.fontFamilyFallback);
    expect(themeData.textTheme.bodyLarge?.fontFamilyFallback, contains('Microsoft YaHei'));
    expect(themeData.textTheme.bodyLarge?.fontFamilyFallback, contains('Noto Sans CJK SC'));
  });
}
