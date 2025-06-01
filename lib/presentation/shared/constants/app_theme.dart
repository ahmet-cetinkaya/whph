import 'package:flutter/material.dart';
import 'package:whph/domain/shared/constants/app_theme.dart' as domain;

class AppTheme {
  // Colors
  static const Color primaryColor = domain.AppTheme.primaryColor;

  // Surface Colors
  static const Color surface0 = Color.fromARGB(255, 0, 0, 0);
  static const Color surface1 = Color(0xFF121212);
  static const Color surface2 = Color(0xFF181818);
  static const Color surface3 = Color(0xFF202020);

  // Barrier Colors
  static Color barrierColor = surface3.withValues(alpha: 0.8);

  // Text Colors
  static const Color textColor = Color(0xFFFFFFFF);
  static const Color secondaryTextColor = Color(0xFFB0B0B0);
  static const Color darkTextColor = Color(0xFF000000);
  static const Color lightTextColor = Color(0xFFFFFFFF);

  // Other Colors
  static const Color dividerColor = Color(0xFF282828);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);
  static const Color disabledColor = Color(0xFF9E9E9E);

  // Chart Colors
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

  // Text Styles
  static const TextStyle label = TextStyle(
    color: textColor,
    fontSize: fontSizeMedium,
    height: 1.5,
  );
  static const TextStyle bodyXSmall = TextStyle(
    color: textColor,
    fontSize: fontSizeXSmall,
    height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    color: textColor,
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
  static const TextStyle displaySmall = TextStyle(
    color: textColor,
    fontSize: fontSizeLarge,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle displayLarge = TextStyle(
    color: textColor,
    fontSize: 48.0,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );

  // Sizes
  static const double size2XSmall = 2.0;
  static const double sizeXSmall = 4.0;
  static const double size3XSmall = 6.0;
  static const double sizeSmall = 8.0;
  static const double size2Small = 10.0;
  static const double sizeMedium = 12.0;
  static const double sizeLarge = 16.0;
  static const double sizeXLarge = 24.0;
  static const double size2XLarge = 32.0;
  static const double size3XLarge = 36.0;
  static const double size4XLarge = 48.0;

  // Button Sizes
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
    cardTheme: CardThemeData(
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
        contentPadding: EdgeInsets.symmetric(horizontal: sizeSmall, vertical: sizeXSmall),
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
      labelPadding: EdgeInsets.all(sizeXSmall),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(containerBorderRadius)),
      side: BorderSide.none,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: textColor,
      textColor: textColor,
      backgroundColor: surface2,
    ),
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
    dialogTheme: DialogThemeData(
      barrierColor: barrierColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(containerBorderRadius),
      ),
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(containerBorderRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      modalBarrierColor: barrierColor,
      constraints: BoxConstraints(
        maxWidth: 0.9 * AppTheme.screenMedium,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(primaryColor),
        foregroundColor: WidgetStateProperty.all(darkTextColor),
        padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: sizeMedium, vertical: sizeSmall)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(containerBorderRadius),
        )),
        textStyle: WidgetStateProperty.all(labelLarge),
      ),
    ),
  );
}
