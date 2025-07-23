import 'package:flutter/material.dart';

enum AppThemeMode { light, dark }

abstract class IThemeService {
  /// Gets the current theme mode
  AppThemeMode get currentThemeMode;
  
  /// Gets whether dynamic accent color is enabled
  bool get isDynamicAccentColorEnabled;
  
  /// Gets the current primary color
  Color get primaryColor;
  
  /// Gets the current surface colors based on theme mode
  Color get surface0;
  Color get surface1;
  Color get surface2;
  Color get surface3;
  
  /// Gets the current text colors based on theme mode
  Color get textColor;
  Color get secondaryTextColor;
  Color get lightTextColor;
  Color get darkTextColor;
  
  /// Gets the current divider color
  Color get dividerColor;
  
  /// Gets the current barrier color
  Color get barrierColor;
  
  /// Gets the current ThemeData
  ThemeData get themeData;
  
  /// Stream of theme changes
  Stream<void> get themeChanges;
  
  /// Initializes the theme service by loading settings
  Future<void> initialize();
  
  /// Updates the theme mode
  Future<void> setThemeMode(AppThemeMode mode);
  
  /// Updates the dynamic accent color setting
  Future<void> setDynamicAccentColor(bool enabled);
  
  /// Refreshes theme from settings
  Future<void> refreshTheme();
}