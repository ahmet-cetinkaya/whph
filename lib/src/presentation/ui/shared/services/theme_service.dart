import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/src/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/src/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/src/core/domain/features/settings/setting.dart';
import 'package:whph/src/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/src/core/domain/shared/constants/app_theme.dart' as domain;

class ThemeService implements IThemeService {
  final Mediator _mediator;
  final StreamController<void> _themeChangesController = StreamController<void>.broadcast();

  AppThemeMode _currentThemeMode = AppThemeMode.dark;
  bool _isDynamicAccentColorEnabled = false;
  Color _primaryColor = domain.AppTheme.primaryColor;

  ThemeService({required Mediator mediator}) : _mediator = mediator;

  @override
  AppThemeMode get currentThemeMode => _currentThemeMode;

  @override
  bool get isDynamicAccentColorEnabled => _isDynamicAccentColorEnabled;

  @override
  Color get primaryColor => _primaryColor;

  @override
  Color get surface0 {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFFFFFBFF); // Pure white with slight warm tint
    } else {
      return const Color(0xFF000000); // Pure black background
    }
  }

  @override
  Color get surface1 {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFFF8F9FA); // Very light gray with subtle blue tint
    } else {
      return const Color(0xFF121212); // Dark surface
    }
  }

  @override
  Color get surface2 {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFFF1F3F4); // Light gray for cards and containers
    } else {
      return const Color(0xFF181818); // Dark surface variant 2
    }
  }

  @override
  Color get surface3 {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFFE8EAED); // Medium light gray for elevated surfaces
    } else {
      return const Color(0xFF202020); // Dark surface variant 3
    }
  }

  @override
  Color get textColor {
    return _currentThemeMode == AppThemeMode.light
        ? const Color(0xFF202124) // Rich dark gray for better readability
        : const Color(0xFFFFFFFF); // Pure white text for dark theme
  }

  @override
  Color get secondaryTextColor {
    return _currentThemeMode == AppThemeMode.light
        ? const Color(0xFF5F6368) // Medium gray for secondary text
        : const Color(0xFFB0B0B0); // Secondary gray text for dark theme
  }

  @override
  Color get lightTextColor => const Color(0xFFFFFFFF);

  @override
  Color get darkTextColor => const Color(0xFF000000);

  @override
  Color get dividerColor {
    return _currentThemeMode == AppThemeMode.light
        ? const Color(0xFFDADCE0) // Subtle divider color
        : const Color(0xFF282828); // Dark divider
  }

  @override
  Color get barrierColor {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFF000000).withValues(alpha: 0.4); // Semi-transparent black
    } else {
      return surface3.withValues(alpha: 0.8);
    }
  }

  @override
  Stream<void> get themeChanges => _themeChangesController.stream;

  @override
  ThemeData get themeData {
    final isDark = _currentThemeMode == AppThemeMode.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: _primaryColor,
              onPrimary: darkTextColor,
              surface: surface1,
              onSurface: textColor,
              secondary: surface3,
              onSecondary: textColor,
              outline: dividerColor,
              outlineVariant: dividerColor.withValues(alpha: 0.5),
            )
          : ColorScheme.light(
              primary: _primaryColor,
              onPrimary: lightTextColor,
              surface: surface1,
              onSurface: textColor,
              secondary: surface3,
              onSecondary: textColor,
              outline: dividerColor,
              outlineVariant: dividerColor.withValues(alpha: 0.5),
              surfaceContainerLowest: surface0,
              surfaceContainerLow: surface1,
              surfaceContainer: surface2,
              surfaceContainerHigh: surface3,
              surfaceContainerHighest: surface3,
            ),
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: surface0,
      highlightColor: surface3,
      cardTheme: CardThemeData(
        color: surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        clipBehavior: Clip.antiAlias,
        elevation: isDark ? 0 : 1,
        shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.1),
        margin: EdgeInsets.zero,
      ),
      textTheme: TextTheme(
        bodySmall: TextStyle(color: textColor, fontSize: 12.0, height: 1.5),
        bodyMedium: TextStyle(color: textColor, fontSize: 14.0, height: 1.5),
        bodyLarge: TextStyle(color: textColor, fontSize: 16.0, height: 1.5, fontWeight: FontWeight.w500),
        headlineSmall: TextStyle(color: textColor, fontSize: 16.0, fontWeight: FontWeight.bold, height: 1.3),
        headlineMedium: TextStyle(color: textColor, fontSize: 20.0, fontWeight: FontWeight.bold, height: 1.3),
        headlineLarge: TextStyle(color: textColor, fontSize: 28.0, fontWeight: FontWeight.bold, height: 1.2),
        displaySmall: TextStyle(color: textColor, fontSize: 16.0, fontWeight: FontWeight.bold),
        displayLarge: TextStyle(color: textColor, fontSize: 48.0, fontWeight: FontWeight.bold, height: 1.1),
        labelSmall: TextStyle(color: secondaryTextColor, fontSize: 11.0, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: secondaryTextColor, fontSize: 12.0, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: secondaryTextColor, fontSize: 14.0, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(
            color: Colors.transparent,
            width: 0.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: _primaryColor,
            width: 2.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(
            color: Colors.transparent,
            width: 0.0,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: isDark ? dividerColor.withValues(alpha: 0.3) : Colors.transparent,
            width: isDark ? 1.0 : 0.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(
            color: Color(0xFFE53E3E),
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(
            color: Color(0xFFE53E3E),
            width: 2.0,
          ),
        ),
        filled: false,
        fillColor: Colors.transparent,
        labelStyle: TextStyle(color: secondaryTextColor, fontSize: 14.0, height: 1.5),
        hintStyle: TextStyle(color: secondaryTextColor.withValues(alpha: 0.7), fontSize: 14.0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(lightTextColor),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return Colors.transparent;
        }),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide.none;
          }
          return BorderSide(color: dividerColor, width: 2.0);
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: textColor, fontSize: 14.0, height: 1.5),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surface1),
          elevation: WidgetStateProperty.all(isDark ? 0 : 4),
          shadowColor: WidgetStateProperty.all(isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.1)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          )),
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(
              color: Colors.transparent,
              width: 0.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(
              color: _primaryColor,
              width: 2.0,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(
              color: Colors.transparent,
              width: 0.0,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(
              color: isDark ? dividerColor.withValues(alpha: 0.3) : Colors.transparent,
              width: isDark ? 1.0 : 0.0,
            ),
          ),
          filled: false,
          fillColor: Colors.transparent,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        labelPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        side: BorderSide.none,
        backgroundColor: surface2,
        selectedColor: _primaryColor.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: textColor, fontSize: 14.0),
        secondaryLabelStyle: TextStyle(color: secondaryTextColor, fontSize: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: textColor,
        textColor: textColor,
        backgroundColor: surface2,
        collapsedIconColor: secondaryTextColor,
        collapsedTextColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor.withValues(alpha: 0.5);
          }
          return surface3;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return isDark ? textColor : const Color(0xFFFFFFFF);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return dividerColor;
        }),
      ),
      dialogTheme: DialogThemeData(
        barrierColor: barrierColor,
        backgroundColor: surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: isDark ? 0 : 8,
        shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.2),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: textColor,
          fontSize: 14.0,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16.0),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: dividerColor,
        modalBarrierColor: barrierColor,
        elevation: isDark ? 0 : 8,
        shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.2),
        constraints: const BoxConstraints(
          maxWidth: 0.9 * 768.0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return surface3;
            }
            return _primaryColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return secondaryTextColor;
            }
            return lightTextColor;
          }),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          )),
          textStyle: WidgetStateProperty.all(const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (isDark) return 0;
            if (states.contains(WidgetState.pressed)) return 2;
            if (states.contains(WidgetState.hovered)) return 4;
            return 2;
          }),
          shadowColor: WidgetStateProperty.all(
            isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return secondaryTextColor;
            }
            return _primaryColor;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: dividerColor.withValues(alpha: 0.5), width: 1.0);
            }
            return BorderSide(color: _primaryColor, width: 1.5);
          }),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          )),
          textStyle: WidgetStateProperty.all(const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return secondaryTextColor;
            }
            return _primaryColor;
          }),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          )),
          textStyle: WidgetStateProperty.all(const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface0,
        foregroundColor: textColor,
        elevation: isDark ? 0 : 1,
        shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.1),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textColor),
        actionsIconTheme: IconThemeData(color: textColor),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: _primaryColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 16.0,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: secondaryTextColor,
          fontSize: 14.0,
        ),
        leadingAndTrailingTextStyle: TextStyle(
          color: secondaryTextColor,
          fontSize: 14.0,
        ),
      ),
    );
  }

  @override
  Future<void> initialize() async {
    await _loadThemeSettings();
    if (_isDynamicAccentColorEnabled) {
      await _loadDynamicAccentColor();
    }
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    _currentThemeMode = mode;
    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.themeMode,
      value: mode == AppThemeMode.light ? 'light' : 'dark',
      valueType: SettingValueType.string,
    ));
    _notifyThemeChanged();
  }

  
  @override
  Future<void> setDynamicAccentColor(bool enabled) async {
    _isDynamicAccentColorEnabled = enabled;
    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.dynamicAccentColor,
      value: enabled.toString(),
      valueType: SettingValueType.bool,
    ));

    if (enabled) {
      await _loadDynamicAccentColor();
    } else {
      _primaryColor = domain.AppTheme.primaryColor;
    }

    _notifyThemeChanged();
  }

  @override
  Future<void> refreshTheme() async {
    await _loadThemeSettings();
    if (_isDynamicAccentColorEnabled) {
      await _loadDynamicAccentColor();
    }
    _notifyThemeChanged();
  }

  Future<void> _loadThemeSettings() async {
    // Load theme mode
    try {
      final themeResponse = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: SettingKeys.themeMode),
      );
      _currentThemeMode = themeResponse.value == 'light' ? AppThemeMode.light : AppThemeMode.dark;
    } catch (e) {
      _currentThemeMode = AppThemeMode.dark; // Default
    }

    // Load dynamic accent color
    try {
      final dynamicResponse = await _mediator.send<GetSettingQuery, GetSettingQueryResponse>(
        GetSettingQuery(key: SettingKeys.dynamicAccentColor),
      );
      _isDynamicAccentColorEnabled = dynamicResponse.getValue<bool>();
    } catch (e) {
      _isDynamicAccentColorEnabled = false; // Default
    }
  }

  Future<void> _loadDynamicAccentColor() async {
    try {
      // Try to get system accent color on supported platforms
      if (Theme.of(WidgetsBinding.instance.rootElement!).platform == TargetPlatform.android ||
          Theme.of(WidgetsBinding.instance.rootElement!).platform == TargetPlatform.iOS) {
        // For now, we'll use the default color
        // In a real implementation, you might use platform channels to get the system accent color
        _primaryColor = domain.AppTheme.primaryColor;
      } else {
        _primaryColor = domain.AppTheme.primaryColor;
      }
    } catch (e) {
      _primaryColor = domain.AppTheme.primaryColor;
    }
  }

  void _notifyThemeChanged() {
    _themeChangesController.add(null);
  }

  void dispose() {
    _themeChangesController.close();
  }
}