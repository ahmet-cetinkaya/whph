import 'package:flutter/material.dart';
import 'package:acore/acore.dart' hide Container;

/// Builds ThemeData based on current theme settings.
/// Extracted from ThemeService to separate theme configuration from settings management.
class ThemeDataBuilder {
  final bool isDark;
  final Color primaryColor;
  final double densityMultiplier;
  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color textColor;
  final Color secondaryTextColor;
  final Color lightTextColor;
  final Color dividerColor;
  final Color barrierColor;

  const ThemeDataBuilder({
    required this.isDark,
    required this.primaryColor,
    required this.densityMultiplier,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.textColor,
    required this.secondaryTextColor,
    required this.lightTextColor,
    required this.dividerColor,
    required this.barrierColor,
  });

  ThemeData build(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: surface0,
      canvasColor: surface0,
      cardColor: surface2,
      highlightColor: surface3,
      cardTheme: _buildCardTheme(),
      textTheme: _buildTextTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      checkboxTheme: _buildCheckboxTheme(),
      dropdownMenuTheme: _buildDropdownMenuTheme(),
      dividerTheme: _buildDividerTheme(),
      chipTheme: _buildChipTheme(),
      expansionTileTheme: _buildExpansionTileTheme(),
      switchTheme: _buildSwitchTheme(),
      dialogTheme: _buildDialogTheme(),
      bottomSheetTheme: _buildBottomSheetTheme(),
      filledButtonTheme: _buildFilledButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      appBarTheme: _buildAppBarTheme(),
      listTileTheme: _buildListTileTheme(),
      bottomNavigationBarTheme: _buildBottomNavigationBarTheme(),
    );
  }

  CardThemeData _buildCardTheme() {
    return CardThemeData(
      color: surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 0 : 1,
      shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.1),
      margin: EdgeInsets.zero,
    );
  }

  TextTheme _buildTextTheme() {
    return TextTheme(
      bodySmall: TextStyle(color: textColor, fontSize: 12.0 * densityMultiplier, height: 1.5),
      bodyMedium: TextStyle(color: textColor, fontSize: 14.0 * densityMultiplier, height: 1.5),
      bodyLarge:
          TextStyle(color: textColor, fontSize: 16.0 * densityMultiplier, height: 1.5, fontWeight: FontWeight.w500),
      headlineSmall:
          TextStyle(color: textColor, fontSize: 16.0 * densityMultiplier, fontWeight: FontWeight.bold, height: 1.3),
      headlineMedium:
          TextStyle(color: textColor, fontSize: 20.0 * densityMultiplier, fontWeight: FontWeight.bold, height: 1.3),
      headlineLarge:
          TextStyle(color: textColor, fontSize: 28.0 * densityMultiplier, fontWeight: FontWeight.bold, height: 1.2),
      displaySmall: TextStyle(color: textColor, fontSize: 16.0 * densityMultiplier, fontWeight: FontWeight.bold),
      displayLarge:
          TextStyle(color: textColor, fontSize: 48.0 * densityMultiplier, fontWeight: FontWeight.bold, height: 1.1),
      labelSmall: TextStyle(color: secondaryTextColor, fontSize: 11.0 * densityMultiplier, fontWeight: FontWeight.w500),
      labelMedium:
          TextStyle(color: secondaryTextColor, fontSize: 12.0 * densityMultiplier, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(color: secondaryTextColor, fontSize: 14.0 * densityMultiplier, fontWeight: FontWeight.w500),
    );
  }

  InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      border: _buildInputBorder(Colors.transparent, 0.0),
      focusedBorder: _buildInputBorder(primaryColor, 2.0),
      enabledBorder: _buildInputBorder(Colors.transparent, 0.0),
      disabledBorder: _buildInputBorder(
        isDark ? dividerColor.withValues(alpha: 0.3) : Colors.transparent,
        isDark ? 1.0 : 0.0,
      ),
      errorBorder: _buildInputBorder(const Color(0xFFE53E3E), 1.0),
      focusedErrorBorder: _buildInputBorder(const Color(0xFFE53E3E), 2.0),
      filled: false,
      fillColor: Colors.transparent,
      labelStyle: TextStyle(color: secondaryTextColor, fontSize: 14.0 * densityMultiplier, height: 1.5),
      hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.7), fontSize: 14.0 * densityMultiplier),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0 * densityMultiplier, vertical: 12.0 * densityMultiplier),
    );
  }

  OutlineInputBorder _buildInputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  CheckboxThemeData _buildCheckboxTheme() {
    return CheckboxThemeData(
      checkColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColorContrastHelper.getContrastingTextColor(primaryColor);
        }
        return lightTextColor;
      }),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor;
        return Colors.transparent;
      }),
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return BorderSide.none;
        return BorderSide(color: dividerColor, width: 2.0);
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
    );
  }

  DropdownMenuThemeData _buildDropdownMenuTheme() {
    return DropdownMenuThemeData(
      textStyle: TextStyle(color: textColor, fontSize: 14.0 * densityMultiplier, height: 1.5),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(surface1),
        elevation: WidgetStateProperty.all(isDark ? 0 : 4),
        shadowColor: WidgetStateProperty.all(isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.1)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.0 * densityMultiplier, vertical: 8.0 * densityMultiplier),
        border: _buildInputBorder(Colors.transparent, 0.0),
        focusedBorder: _buildInputBorder(primaryColor, 2.0),
        enabledBorder: _buildInputBorder(Colors.transparent, 0.0),
        disabledBorder: _buildInputBorder(
          isDark ? dividerColor.withValues(alpha: 0.3) : Colors.transparent,
          isDark ? 1.0 : 0.0,
        ),
        filled: false,
        fillColor: Colors.transparent,
      ),
    );
  }

  DividerThemeData _buildDividerTheme() {
    return DividerThemeData(color: dividerColor, thickness: 1, space: 1);
  }

  ChipThemeData _buildChipTheme() {
    return ChipThemeData(
      labelPadding: EdgeInsets.symmetric(horizontal: 8.0 * densityMultiplier, vertical: 4.0 * densityMultiplier),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      side: BorderSide.none,
      backgroundColor: surface2,
      selectedColor: primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: textColor, fontSize: 14.0 * densityMultiplier),
      secondaryLabelStyle: TextStyle(color: secondaryTextColor, fontSize: 12.0 * densityMultiplier),
      padding: EdgeInsets.symmetric(horizontal: 12.0 * densityMultiplier, vertical: 8.0 * densityMultiplier),
    );
  }

  ExpansionTileThemeData _buildExpansionTileTheme() {
    return ExpansionTileThemeData(
      iconColor: textColor,
      textColor: textColor,
      backgroundColor: surface2,
      collapsedIconColor: secondaryTextColor,
      collapsedTextColor: textColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    );
  }

  SwitchThemeData _buildSwitchTheme() {
    return SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor.withValues(alpha: 0.5);
        return surface3;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor;
        return isDark ? textColor : const Color(0xFFFFFFFF);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return dividerColor;
      }),
    );
  }

  DialogThemeData _buildDialogTheme() {
    return DialogThemeData(
      barrierColor: barrierColor,
      backgroundColor: surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: isDark ? 0 : 8,
      shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.2),
      titleTextStyle: TextStyle(color: textColor, fontSize: 20.0, fontWeight: FontWeight.w600),
      contentTextStyle: TextStyle(color: textColor, fontSize: 14.0, height: 1.5),
    );
  }

  BottomSheetThemeData _buildBottomSheetTheme() {
    return BottomSheetThemeData(
      backgroundColor: surface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      dragHandleColor: dividerColor,
      modalBarrierColor: barrierColor,
      elevation: isDark ? 0 : 8,
      shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.2),
      constraints: const BoxConstraints(maxWidth: 0.9 * 768.0),
    );
  }

  FilledButtonThemeData _buildFilledButtonTheme() {
    return FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return surface3;
          return primaryColor;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return secondaryTextColor;
          return ColorContrastHelper.getContrastingTextColor(primaryColor);
        }),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: 16.0 * densityMultiplier, vertical: 12.0 * densityMultiplier),
        ),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 16.0 * densityMultiplier, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (isDark) return 0;
          if (states.contains(WidgetState.pressed)) return 2;
          if (states.contains(WidgetState.hovered)) return 4;
          return 2;
        }),
        shadowColor: WidgetStateProperty.all(isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.2)),
      ),
    );
  }

  OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return secondaryTextColor;
          return primaryColor;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: dividerColor.withValues(alpha: 0.5), width: 1.0);
          }
          return BorderSide(color: primaryColor, width: 1.5);
        }),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: 16.0 * densityMultiplier, vertical: 12.0 * densityMultiplier),
        ),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 16.0 * densityMultiplier, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
    );
  }

  TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return secondaryTextColor;
          return primaryColor;
        }),
        padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: 16.0 * densityMultiplier, vertical: 12.0 * densityMultiplier),
        ),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
        textStyle: WidgetStateProperty.all(
          TextStyle(fontSize: 16.0 * densityMultiplier, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
    );
  }

  AppBarTheme _buildAppBarTheme() {
    return AppBarTheme(
      backgroundColor: surface2,
      foregroundColor: textColor,
      elevation: isDark ? 0 : 1,
      shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.1),
      titleTextStyle: TextStyle(color: textColor, fontSize: 20.0 * densityMultiplier, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: textColor),
      actionsIconTheme: IconThemeData(color: textColor),
      actionsPadding: EdgeInsets.only(right: 16.0 * densityMultiplier),
    );
  }

  ListTileThemeData _buildListTileTheme() {
    return ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: primaryColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.0 * densityMultiplier, vertical: 8.0 * densityMultiplier),
      titleTextStyle: TextStyle(color: textColor, fontSize: 16.0 * densityMultiplier, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(color: secondaryTextColor, fontSize: 14.0 * densityMultiplier),
      leadingAndTrailingTextStyle: TextStyle(color: secondaryTextColor, fontSize: 14.0 * densityMultiplier),
    );
  }

  BottomNavigationBarThemeData _buildBottomNavigationBarTheme() {
    return BottomNavigationBarThemeData(
      backgroundColor: surface2,
      selectedItemColor: primaryColor,
      unselectedItemColor: secondaryTextColor,
      elevation: isDark ? 0 : 8,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    );
  }
}
