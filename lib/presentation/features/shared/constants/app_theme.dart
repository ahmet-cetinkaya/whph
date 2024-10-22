import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFF4D03E);
  static const Color surface1 = Color(0xFF2B2B2B);
  static const Color surface2 = Color(0xFF171717);
  static const Color surface3 = Color(0xFF464646);
  static const Color textColor = Color(0xFFEBEBEB);
  static const Color dividerColor = Color(0xFF3A3A3A); // Define divider color

  static const double containerBorderRadius = 15.0;
  static const EdgeInsets containerPadding = EdgeInsets.all(16);

  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 20.0;
  static const double fontSizeXLarge = 24.0;

  static const double screenSmall = 320.0;
  static const double screenMedium = 768.0;
  static const double screenLarge = 1024.0;
  static const double screenXLarge = 1440.0;

  static final ThemeData themeData = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
      primaryColor: primaryColor,
      scaffoldBackgroundColor: surface1,
      cardTheme: CardTheme(
        color: surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(containerBorderRadius)),
      ),
      highlightColor: surface3,
      useMaterial3: true,
      textTheme: TextTheme(
        bodySmall: TextStyle(color: textColor, fontSize: fontSizeSmall),
        bodyMedium: TextStyle(color: textColor, fontSize: fontSizeMedium),
        bodyLarge: TextStyle(color: textColor, fontSize: fontSizeLarge),
        headlineSmall: TextStyle(color: textColor, fontSize: fontSizeLarge, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textColor, fontSize: fontSizeXLarge, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: textColor, fontSize: fontSizeXLarge + 4, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(containerBorderRadius),
          borderSide: BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface2,
        titleTextStyle: TextStyle(color: textColor, fontSize: fontSizeLarge, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: textColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(containerBorderRadius)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface2,
        selectedItemColor: primaryColor,
        unselectedItemColor: textColor,
      ),
      tabBarTheme: TabBarTheme(
        labelColor: primaryColor,
        unselectedLabelColor: textColor,
      ),
      iconTheme: IconThemeData(color: textColor),
      dividerColor: dividerColor, // Use the defined divider color
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1.0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface3,
        contentTextStyle: TextStyle(color: textColor, fontSize: fontSizeMedium),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surface3,
          borderRadius: BorderRadius.circular(containerBorderRadius),
        ),
        textStyle: TextStyle(color: textColor, fontSize: fontSizeSmall),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface2,
        scrimColor: Colors.transparent, // Set scrim color to transparent
      ),
      listTileTheme: ListTileThemeData(
        textColor: textColor,
        iconColor: textColor,
        selectedTileColor: surface3,
        selectedColor: textColor,
      ));
}
