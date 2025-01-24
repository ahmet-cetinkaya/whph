import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_theme.dart' as domain;

class AppTheme {
  // Colors
  static const Color primaryColor = domain.AppTheme.primaryColor;

  static const Color surface0 = Color(0x00000000);
  static const Color surface1 = Color(0xFF121212);
  static const Color surface2 = Color(0xFF181818);
  static const Color surface3 = Color(0xFF202020);

  static const Color textColor = Color(0xFFFFFFFF);
  static const Color secondaryTextColor = Color(0xFFB0B0B0);
  static const Color darkTextColor = Color(0xFF000000);
  static const Color lightTextColor = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFF282828);

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

  static const double fontSizeXXSmall = 10.0;
  static const double fontSizeXSmall = 11.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 20.0;
  static const double fontSizeXXLarge = 24.0;

  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  static const double screenSmall = 320.0;
  static const double screenMedium = 768.0;
  static const double screenLarge = 1024.0;
  static const double screenXLarge = 1440.0;

  static const TextStyle bodySmall = TextStyle(
    color: secondaryTextColor,
    fontSize: fontSizeSmall,
    height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    color: textColor,
    fontSize: fontSizeMedium,
    height: 1.5,
  );
  static const TextStyle bodyLarge = TextStyle(
    color: textColor,
    fontSize: fontSizeLarge,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle headlineSmall = TextStyle(
    color: textColor,
    fontSize: fontSizeLarge,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );
  static const TextStyle headlineMedium = TextStyle(
    color: textColor,
    fontSize: fontSizeXLarge,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );
  static const TextStyle headlineLarge = TextStyle(
    color: textColor,
    fontSize: fontSizeXLarge + 8,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );
  static const TextStyle displaySmall =
      TextStyle(color: textColor, fontSize: fontSizeLarge, fontWeight: FontWeight.bold);
  static const TextStyle displayLarge = TextStyle(
    color: textColor,
    fontSize: 48.0,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );

  // ThemeData definition
  static final ThemeData themeData = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      onPrimary: textColor,
      surface: surface1,
      onSurface: textColor,
      secondary: surface3,
      onSecondary: textColor,
    ),
    primaryColor: domain.AppTheme.primaryColor,
    scaffoldBackgroundColor: AppTheme.surface0,
    highlightColor: surface3,
    cardTheme: CardTheme(
      color: surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(containerBorderRadius)),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
    ),
    textTheme: TextTheme(
      bodySmall: bodySmall,
      bodyMedium: bodyMedium,
      bodyLarge: bodyLarge,
      headlineSmall: headlineSmall,
      headlineMedium: headlineMedium,
      headlineLarge: headlineLarge,
      displaySmall: displaySmall,
      displayLarge: displayLarge,
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
      filled: true,
      fillColor: surface1,
      labelStyle: bodyMedium.copyWith(color: secondaryTextColor),
    ),
    checkboxTheme: CheckboxThemeData(
      checkColor: WidgetStateProperty.all(surface1),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: bodySmall,
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
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withAlpha((255 * 0.5).toInt());
        }
        return surface3;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return textColor;
      }),
    ),
  );
}
