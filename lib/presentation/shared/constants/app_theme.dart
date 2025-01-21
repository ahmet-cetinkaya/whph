import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_theme.dart' as domain;

class AppTheme {
  // Colors
  static const Color primaryColor = domain.AppTheme.primaryColor;

  static const Color surface0 = Color(0xFF000000);
  static const Color surface1 = Color(0xFF171717);
  static const Color surface2 = Color(0xFF2B2B2B);
  static const Color surface3 = Color(0xFF464646);
  static const Color textColor = Color(0xFFEBEBEB);
  static const Color secondaryTextColor = Color(0xFFBDBDBD);
  static const Color darkTextColor = Color(0xFF121212);
  static const Color lightTextColor = Color(0xFFE0E0E0);
  static const Color dividerColor = Color(0xFF3A3A3A);

  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);
  static const Color disabledColor = Color(0xFF9E9E9E);

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

  // Dimensions
  static const double containerBorderRadius = 15.0;
  static const EdgeInsets containerPadding = EdgeInsets.all(16);

  static const double fontSizeXSmall = 8.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 20.0;
  static const double fontSizeXLarge = 24.0;

  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  static const double screenSmall = 320.0;
  static const double screenMedium = 768.0;
  static const double screenLarge = 1024.0;
  static const double screenXLarge = 1440.0;

  // Text Styles
  static const TextStyle bodySmall = TextStyle(color: textColor, fontSize: fontSizeSmall);
  static const TextStyle bodyMedium = TextStyle(color: textColor, fontSize: fontSizeMedium);
  static const TextStyle bodyLarge = TextStyle(color: textColor, fontSize: fontSizeLarge);
  static const TextStyle headlineSmall =
      TextStyle(color: textColor, fontSize: fontSizeLarge, fontWeight: FontWeight.bold);
  static const TextStyle headlineMedium =
      TextStyle(color: textColor, fontSize: fontSizeXLarge, fontWeight: FontWeight.bold);
  static const TextStyle headlineLarge =
      TextStyle(color: textColor, fontSize: fontSizeXLarge + 4, fontWeight: FontWeight.bold);
  static const TextStyle displaySmall =
      TextStyle(color: textColor, fontSize: fontSizeLarge, fontWeight: FontWeight.bold);

  // ThemeData definition
  static final ThemeData themeData = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: domain.AppTheme.primaryColor,
      onPrimary: textColor,
      surface: surface1,
    ),
    primaryColor: domain.AppTheme.primaryColor,
    scaffoldBackgroundColor: AppTheme.surface0,
    highlightColor: surface3,
    cardTheme: CardTheme(
      color: surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(containerBorderRadius)),
      clipBehavior: Clip.antiAlias,
    ),
    textTheme: TextTheme(
      bodySmall: bodySmall,
      bodyMedium: bodyMedium,
      bodyLarge: bodyLarge,
      headlineSmall: headlineSmall,
      headlineMedium: headlineMedium,
      headlineLarge: headlineLarge,
      displaySmall: displaySmall,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(containerBorderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(containerBorderRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(containerBorderRadius),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(containerBorderRadius),
        borderSide: BorderSide.none,
      ),
      labelStyle: TextStyle(color: textColor),
      filled: true,
      fillColor: surface1,
    ),
    checkboxTheme: CheckboxThemeData(
      checkColor: WidgetStateProperty.all(surface1),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(fontSize: 12),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(surface1),
        elevation: WidgetStateProperty.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(containerBorderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(containerBorderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(containerBorderRadius),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(containerBorderRadius),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: surface1,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: dividerColor,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      labelPadding: EdgeInsets.all(4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(containerBorderRadius)),
      side: BorderSide.none,
    ),
    expansionTileTheme: ExpansionTileThemeData(iconColor: textColor, textColor: textColor, backgroundColor: surface2),
  );
}
