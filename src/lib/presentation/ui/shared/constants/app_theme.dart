import 'package:flutter/material.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/main.dart';

class AppTheme {
  static IThemeService? _themeService;

  static IThemeService get _service {
    _themeService ??= container.resolve<IThemeService>();
    return _themeService!;
  }

  @visibleForTesting
  static void resetService() {
    _themeService = null;
  }

  // Dynamic Colors (get from theme service)
  static Color get primaryColor => _service.primaryColor;
  static Color get surface0 => _service.surface0;
  static Color get surface1 => _service.surface1;
  static Color get surface2 => _service.surface2;
  static Color get surface3 => _service.surface3;
  static Color get barrierColor => _service.barrierColor;
  static Color get textColor => _service.textColor;
  static Color get secondaryTextColor => _service.secondaryTextColor;
  static Color get darkTextColor => _service.darkTextColor;
  static Color get lightTextColor => _service.lightTextColor;
  static Color get dividerColor => _service.dividerColor;

  // Static Colors (don't change with theme)
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);
  static const Color disabledColor = Color(0xFF9E9E9E);

  // Chart Colors (static)
  static const Color chartColor1 = domain.AppTheme.chartColor1;
  static const Color chartColor2 = domain.AppTheme.chartColor2;
  static const Color chartColor3 = domain.AppTheme.chartColor3;
  static const Color chartColor4 = domain.AppTheme.chartColor4;
  static const Color chartColor5 = domain.AppTheme.chartColor5;
  static const Color chartColor6 = domain.AppTheme.chartColor6;
  static const Color chartColor7 = domain.AppTheme.chartColor7;
  static const Color chartColor8 = domain.AppTheme.chartColor8;
  static const Color chartColor9 = domain.AppTheme.chartColor9;
  static const Color chartColor10 = domain.AppTheme.chartColor10;

  // Common UI Colors
  static const Color borderColor = Color(0xFFBDBDBD);
  static const Color shadowColor = Color(0x1F000000);
  static const Color hoverColor = Color(0x0A000000);
  static const Color focusColor = Color(0x1F000000);
  static const Color splashColor = Color(0x1F000000);
  static const Color overlayLight = Color(0x1FFFFFFF);
  static const Color overlayDark = Color(0x1F000000);

  // Dimensions
  static const double containerBorderRadius = 15.0;
  static const EdgeInsets containerPadding = EdgeInsets.all(sizeMedium);

  // Font Sizes
  static const double fontSizeXXSmall = 10.0;
  static const double fontSizeXSmall = 11.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 20.0;
  static const double fontSizeXXLarge = 24.0;

  // Icon Sizes
  static const double iconSize2XSmall = 8.0;
  static const double iconSizeXSmall = 12.0;
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  static const double iconSize2XLarge = 64.0;
  static const double iconSize3XLarge = 96.0;

  // Screen Sizes
  static const double screenSmall = 320.0;
  static const double screenMedium = 768.0;
  static const double screenLarge = 1024.0;
  static const double screenXLarge = 1440.0;

  // Text Styles (dynamic with density scaling)
  static TextStyle get label => TextStyle(
        color: textColor,
        fontSize: fontSizeMedium * _service.currentUiDensity.multiplier,
        height: 1.5,
      );
  static TextStyle get bodyXSmall => TextStyle(
        color: textColor,
        fontSize: fontSizeXSmall * _service.currentUiDensity.multiplier,
        height: 1.5,
      );
  static TextStyle get bodySmall => TextStyle(
        color: textColor,
        fontSize: fontSizeSmall * _service.currentUiDensity.multiplier,
        height: 1.5,
      );
  static TextStyle get bodyMedium => TextStyle(
        color: textColor,
        fontSize: fontSizeMedium * _service.currentUiDensity.multiplier,
        height: 1.5,
      );
  static TextStyle get bodyLarge => TextStyle(
        color: textColor,
        fontSize: fontSizeLarge * _service.currentUiDensity.multiplier,
        height: 1.5,
        fontWeight: FontWeight.w500,
      );
  static TextStyle get headlineSmall => TextStyle(
        color: textColor,
        fontSize: fontSizeLarge * _service.currentUiDensity.multiplier,
        fontWeight: FontWeight.bold,
        height: 1.3,
      );
  static TextStyle get headlineMedium => TextStyle(
        color: textColor,
        fontSize: fontSizeXLarge * _service.currentUiDensity.multiplier,
        fontWeight: FontWeight.bold,
        height: 1.3,
      );
  static TextStyle get headlineLarge => TextStyle(
        color: textColor,
        fontSize: (fontSizeXLarge + 8) * _service.currentUiDensity.multiplier,
        fontWeight: FontWeight.bold,
        height: 1.2,
      );
  static TextStyle get displaySmall => TextStyle(
        color: textColor,
        fontSize: fontSizeLarge * _service.currentUiDensity.multiplier,
        fontWeight: FontWeight.bold,
      );
  static TextStyle get displayLarge => TextStyle(
        color: textColor,
        fontSize: 48.0 * _service.currentUiDensity.multiplier,
        fontWeight: FontWeight.bold,
        height: 1.1,
      );

  // Sizes
  static const double size4XSmall = 1.0;
  static const double size3XSmall = 2.0;
  static const double size2XSmall = 4.0;
  static const double sizeXSmall = 6.0;
  static const double sizeSmall = 8.0;
  static const double size2Small = 10.0;
  static const double sizeMedium = 12.0;
  static const double sizeLarge = 16.0;
  static const double sizeXLarge = 24.0;
  static const double size2XLarge = 32.0;
  static const double size3XLarge = 36.0;
  static const double size4XLarge = 48.0;

  // Button Sizes
  static const double buttonSize2XSmall = 20.0;
  static const double buttonSizeXSmall = 24.0;
  static const double buttonSizeSmall = 28.0;
  static const double buttonSizeMedium = 36.0;
  static const double buttonSizeLarge = 44.0;

  // Calendar Element Sizes
  static const double calendarDayWidth = 32.0;
  static const double calendarDayHeight = 32.0;
  static const double calendarIconSize = 24.0;

  // Label Text Styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: fontSizeLarge,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: fontSizeMedium,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
  static const TextStyle labelXSmall = TextStyle(
    fontSize: fontSizeXXSmall,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // ThemeData definition (dynamic)
  static ThemeData get themeData => _service.themeData;
}
