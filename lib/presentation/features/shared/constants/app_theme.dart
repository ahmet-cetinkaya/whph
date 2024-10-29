import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFFF4D03E);
  static const Color surface1 = Color(0xFF171717);
  static const Color surface2 = Color(0xFF2B2B2B);
  static const Color surface3 = Color(0xFF464646);
  static const Color textColor = Color(0xFFEBEBEB);
  static const Color darkTextColor = Color(0xFF121212);
  static const Color dividerColor = Color(0xFF3A3A3A);

  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);
  static const Color disabledColor = Color(0xFF9E9E9E);

  static const Color chartColor1 = Color(0xFF2E7D32);
  static const Color chartColor2 = Color(0xFF1565C0);
  static const Color chartColor3 = Color(0xFFFF8F00);
  static const Color chartColor4 = Color(0xFFC62828);
  static const Color chartColor5 = Color(0xFF6A1B9A);
  static const Color chartColor6 = Color(0xFF00838F);
  static const Color chartColor7 = Color(0xFF4E342E);
  static const Color chartColor8 = Color(0xFF37474F);
  static const Color chartColor9 = Color(0xFF558B2F);
  static const Color chartColor10 = Color(0xFF9E9D24);

  // Dimensions
  static const double containerBorderRadius = 15.0;
  static const EdgeInsets containerPadding = EdgeInsets.all(16);

  static const double fontSizeXSmall = 8.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 20.0;
  static const double fontSizeXLarge = 24.0;

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
      primary: primaryColor,
      onPrimary: textColor,
      surface: surface1,
    ),
    primaryColor: primaryColor,
    scaffoldBackgroundColor: surface2,
    highlightColor: surface3,
    cardTheme: CardTheme(
      color: surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(containerBorderRadius)),
      clipBehavior: Clip.antiAlias, // Added clipBehavior
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
      fillColor: surface2,
    ),
    checkboxTheme: CheckboxThemeData(
      checkColor: WidgetStateProperty.all(surface1),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
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
