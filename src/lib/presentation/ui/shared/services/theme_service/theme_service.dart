import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediatr/mediatr.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/core/application/features/settings/commands/save_setting_command.dart';
import 'package:whph/core/domain/features/settings/setting.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:acore/acore.dart' hide Container;
import 'package:whph/presentation/ui/shared/services/theme_service/theme_data_builder.dart';

class ThemeService with WidgetsBindingObserver implements IThemeService {
  final Mediator _mediator;
  @protected
  final ILogger logger;
  final StreamController<void> _themeChangesController = StreamController<void>.broadcast();

  AppThemeMode _currentThemeMode = AppThemeMode.auto;
  AppThemeMode _storedThemeMode = AppThemeMode.auto;
  bool _isDynamicAccentColorEnabled = false;
  @protected
  AppThemeMode get storedThemeMode => _storedThemeMode;

  @protected
  set currentThemeMode(AppThemeMode value) => _currentThemeMode = value;

  @protected
  bool get isPollingLinuxTheme => _isPollingLinuxTheme;

  @protected
  @protected
  set isPollingLinuxTheme(bool value) => _isPollingLinuxTheme = value;

  bool _isPollingLinuxTheme = false;
  bool _isCustomAccentColorEnabled = false;
  Color? _customAccentColor;
  domain.UiDensity _currentUiDensity = domain.AppTheme.defaultUiDensity;
  Color _primaryColor = domain.AppTheme.primaryColor;
  ColorScheme? _dynamicLightColorScheme;
  ColorScheme? _dynamicDarkColorScheme;

  ThemeService({required Mediator mediator, required ILogger logger})
      : _mediator = mediator,
        this.logger = logger;

  @override
  AppThemeMode get currentThemeMode => _storedThemeMode;

  @override
  bool get isDynamicAccentColorEnabled => _isDynamicAccentColorEnabled;

  @override
  bool get isCustomAccentColorEnabled => _isCustomAccentColorEnabled;

  @override
  Color? get customAccentColor => _customAccentColor;

  @override
  domain.UiDensity get currentUiDensity => _currentUiDensity;

  @override
  Color get primaryColor => _primaryColor;

  @override
  Color get surface0 {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFFFFFBFF);
    } else {
      return const Color(0xFF000000);
    }
  }

  @override
  Color get surface1 {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFFF8F9FA);
    } else {
      return const Color(0xFF121212);
    }
  }

  @override
  Color get surface2 {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFFF1F3F4);
    } else {
      return const Color(0xFF181818);
    }
  }

  @override
  Color get surface3 {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFFE8EAED);
    } else {
      return const Color(0xFF202020);
    }
  }

  @override
  Color get textColor {
    return _currentThemeMode == AppThemeMode.light ? const Color(0xFF202124) : const Color(0xFFFFFFFF);
  }

  @override
  Color get secondaryTextColor {
    return _currentThemeMode == AppThemeMode.light ? const Color(0xFF5F6368) : const Color(0xFFB0B0B0);
  }

  @override
  Color get lightTextColor => const Color(0xFFFFFFFF);

  @override
  Color get darkTextColor => const Color(0xFF000000);

  @override
  Color get dividerColor {
    return _currentThemeMode == AppThemeMode.light ? const Color(0xFFDADCE0) : const Color(0xFF282828);
  }

  @override
  Color get barrierColor {
    if (_currentThemeMode == AppThemeMode.light) {
      return const Color(0xFF000000).withValues(alpha: 0.4);
    } else {
      return surface3.withValues(alpha: 0.8);
    }
  }

  @override
  Stream<void> get themeChanges => _themeChangesController.stream;

  @override
  ThemeData get themeData {
    final isDark = _currentThemeMode == AppThemeMode.dark;

    // Create color scheme with consistent surface colors
    ColorScheme colorScheme;
    if (_isDynamicAccentColorEnabled) {
      final dynamicScheme = isDark ? _dynamicDarkColorScheme : _dynamicLightColorScheme;
      if (dynamicScheme != null) {
        colorScheme = _createFixedColorScheme(isDark, dynamicScheme.primary);
      } else {
        colorScheme = _createFixedColorScheme(isDark, _primaryColor);
      }
    } else {
      colorScheme = _createFixedColorScheme(isDark, _primaryColor);
    }

    // Use ThemeDataBuilder to construct the ThemeData
    final builder = ThemeDataBuilder(
      isDark: isDark,
      primaryColor: _primaryColor,
      densityMultiplier: _currentUiDensity.multiplier,
      surface0: surface0,
      surface1: surface1,
      surface2: surface2,
      surface3: surface3,
      textColor: textColor,
      secondaryTextColor: secondaryTextColor,
      lightTextColor: lightTextColor,
      dividerColor: dividerColor,
      barrierColor: barrierColor,
    );

    return builder.build(colorScheme);
  }

  @override
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await _loadThemeSettings();
    if (_isDynamicAccentColorEnabled) {
      await _loadDynamicAccentColor();
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_storedThemeMode == AppThemeMode.auto) {
      updateActualThemeMode().then((_) => notifyThemeChanged());
    }
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    _storedThemeMode = mode;

    // Save the user's preference
    String valueToSave;
    switch (mode) {
      case AppThemeMode.light:
        valueToSave = 'light';
        break;
      case AppThemeMode.dark:
        valueToSave = 'dark';
        break;
      case AppThemeMode.auto:
        valueToSave = 'auto';
        break;
    }

    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.themeMode,
      value: valueToSave,
      valueType: SettingValueType.string,
    ));

    // Update the actual theme mode based on user preference
    await updateActualThemeMode();

    // Update primary color if dynamic colors are enabled
    if (_isDynamicAccentColorEnabled) {
      await _loadDynamicAccentColor();
    }

    notifyThemeChanged();
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
      // Disable custom accent color when enabling dynamic
      _isCustomAccentColorEnabled = false;
      await _loadDynamicAccentColor();
    } else {
      await _updatePrimaryColor();
    }

    notifyThemeChanged();
  }

  @override
  Future<void> setCustomAccentColor(Color? color) async {
    _customAccentColor = color;
    _isCustomAccentColorEnabled = color != null;

    // Always save the custom accent color value (empty string when disabled)
    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.customAccentColor,
      value: color != null ? color.toARGB32().toString() : '',
      valueType: SettingValueType.string,
    ));

    if (color != null) {
      // Disable dynamic accent color when enabling custom
      _isDynamicAccentColorEnabled = false;
      await _mediator.send(SaveSettingCommand(
        key: SettingKeys.dynamicAccentColor,
        value: false.toString(),
        valueType: SettingValueType.bool,
      ));
    }

    await _updatePrimaryColor();
    notifyThemeChanged();
  }

  @override
  Future<void> setUiDensity(domain.UiDensity density) async {
    _currentUiDensity = density;

    String valueToSave = density.name;

    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.uiDensity,
      value: valueToSave,
      valueType: SettingValueType.string,
    ));

    notifyThemeChanged();
  }

  @override
  Future<void> refreshTheme() async {
    await _loadThemeSettings();
    if (_isDynamicAccentColorEnabled) {
      await _loadDynamicAccentColor();
    } else {
      await _updatePrimaryColor();
    }
    notifyThemeChanged();
  }

  Future<void> _loadThemeSettings() async {
    // Load theme mode preference
    try {
      final themeResponse = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.themeMode),
      );

      if (themeResponse != null) {
        switch (themeResponse.value) {
          case 'light':
            _storedThemeMode = AppThemeMode.light;
            break;
          case 'dark':
            _storedThemeMode = AppThemeMode.dark;
            break;
          case 'auto':
            _storedThemeMode = AppThemeMode.auto;
            break;
          default:
            _storedThemeMode = AppThemeMode.auto;
        }
      } else {
        _storedThemeMode = AppThemeMode.auto;
      }
    } catch (e) {
      _storedThemeMode = AppThemeMode.auto;
    }

    // Update the actual theme mode based on user preference
    await updateActualThemeMode();

    // Load dynamic accent color
    try {
      final dynamicResponse = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.dynamicAccentColor),
      );
      if (dynamicResponse != null) {
        _isDynamicAccentColorEnabled = dynamicResponse.getValue<bool>();
      } else {
        _isDynamicAccentColorEnabled = false;
      }
    } catch (e) {
      _isDynamicAccentColorEnabled = false;
    }

    // Load custom accent color
    try {
      final customResponse = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.customAccentColor),
      );

      if (customResponse != null && customResponse.value.isNotEmpty) {
        final colorValue = customResponse.value;
        _customAccentColor = Color(int.parse(colorValue));
        _isCustomAccentColorEnabled = true;
      } else {
        _customAccentColor = null;
        _isCustomAccentColorEnabled = false;
      }
    } catch (e) {
      _customAccentColor = null;
      _isCustomAccentColorEnabled = false;
    }

    // Load UI density
    try {
      final densityResponse = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.uiDensity),
      );

      if (densityResponse != null) {
        _currentUiDensity = domain.UiDensity.values.firstWhere(
          (density) => density.name == densityResponse.value,
          orElse: () => domain.AppTheme.defaultUiDensity,
        );
      } else {
        _currentUiDensity = domain.AppTheme.defaultUiDensity;
      }
    } catch (e) {
      _currentUiDensity = domain.AppTheme.defaultUiDensity;
    }

    // Update primary color based on loaded settings
    await _updatePrimaryColor();
  }

  /// Updates the primary color based on current settings
  Future<void> _updatePrimaryColor() async {
    if (_isCustomAccentColorEnabled && _customAccentColor != null) {
      _primaryColor = _customAccentColor!;
      _dynamicLightColorScheme = null;
      _dynamicDarkColorScheme = null;
    } else {
      _primaryColor = domain.AppTheme.primaryColor;
      _dynamicLightColorScheme = null;
      _dynamicDarkColorScheme = null;
    }
  }

  /// Updates the actual theme mode based on user preference and system settings
  @protected
  Future<void> updateActualThemeMode() async {
    switch (_storedThemeMode) {
      case AppThemeMode.light:
        _currentThemeMode = AppThemeMode.light;
        break;
      case AppThemeMode.dark:
        _currentThemeMode = AppThemeMode.dark;
        break;
      case AppThemeMode.auto:
        // Get system theme mode
        final systemBrightness = await getSystemBrightness();
        _currentThemeMode = systemBrightness == Brightness.dark ? AppThemeMode.dark : AppThemeMode.light;
        break;
    }
  }

  /// Gets the system brightness/theme mode
  @protected
  Future<Brightness> getSystemBrightness() async {
    try {
      if (Platform.isLinux) {
        // 1. Try Freedesktop Portal (DBus) - Universal & Flatpak-friendly
        try {
          // dbus-send --session --print-reply=literal --dest=org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings.Read string:'org.freedesktop.appearance' string:'color-scheme'
          // Returns: variant       uint32 1 (1 = Dark, 0 = Light, 2 = No preference)
          final result = await Process.run(
            'dbus-send',
            [
              '--session',
              '--print-reply=literal',
              '--dest=org.freedesktop.portal.Desktop',
              '/org/freedesktop/portal/desktop',
              'org.freedesktop.portal.Settings.Read',
              'string:org.freedesktop.appearance',
              'string:color-scheme'
            ],
          );
          if (result.exitCode == 0) {
            final output = result.stdout.toString().trim();
            // Output format example: variant       uint32 1
            if (output.contains('uint32 1')) {
              return Brightness.dark;
            } else if (output.contains('uint32 0')) {
              return Brightness.light;
            }
          }
        } catch (e) {
          logger.debug('Failed to detect Freedesktop Portal theme: $e');
        }

        // 2. Try GNOME (gsettings) - Fallback for non-portal environments
        try {
          final result = await Process.run(
            'gsettings',
            ['get', 'org.gnome.desktop.interface', 'color-scheme'],
          );
          if (result.exitCode == 0) {
            final output = result.stdout.toString().trim();
            if (output.contains('prefer-dark')) {
              return Brightness.dark;
            } else if (output.contains('default') || output.contains('prefer-light')) {
              return Brightness.light;
            }
          }
        } catch (e) {
          logger.debug('Failed to detect GNOME theme: $e');
        }

        // 3. Try KDE (kreadconfig) - Fallback for non-portal environments
        try {
          // Check kdeglobals for [Colors:Window] BackgroundNormal
          // Or simpler: check [General] ColorScheme
          // kreadconfig5 or kreadconfig6
          for (final cmd in ['kreadconfig6', 'kreadconfig5']) {
            final result = await Process.run(
              cmd,
              ['--group', 'General', '--key', 'ColorScheme'],
            );
            if (result.exitCode == 0) {
              final output = result.stdout.toString().trim().toLowerCase();
              if (output.isNotEmpty) {
                // Common dark themes often have "Dark" or "Black" in the name
                if (output.contains('dark') || output.contains('black')) {
                  return Brightness.dark;
                }
                // If we found a scheme but it's not obviously dark, assume light?
                // Or maybe we should check BackgroundNormal color...
                // Let's try a safer check if possible, but for now this is a reasonable heuristic
                return Brightness.light;
              }
            }
          }
        } catch (e) {
          logger.debug('Failed to detect KDE theme: $e');
        }
      }

      // Use MediaQuery to get system brightness
      // This will be called from a context where MediaQuery is available
      // For now, we'll use a platform channel to get system theme

      // Fallback: try to get from window
      final window = WidgetsBinding.instance.platformDispatcher;
      return window.platformBrightness;
    } catch (e) {
      // Default to dark if we can't determine system theme
      return Brightness.dark;
    }
  }

  Future<void> _loadDynamicAccentColor() async {
    try {
      // Create default color schemes as fallbacks
      final ColorScheme defaultLightScheme = ColorScheme.fromSeed(
        seedColor: domain.AppTheme.primaryColor,
        brightness: Brightness.light,
      );

      final ColorScheme defaultDarkScheme = ColorScheme.fromSeed(
        seedColor: domain.AppTheme.primaryColor,
        brightness: Brightness.dark,
      );

      // Get dynamic color schemes from the system using Material You
      final Map<Brightness, ColorScheme>? colorSchemes =
          await DynamicColorPlugin.getCorePalette().then((corePalette) => corePalette != null
              ? {
                  Brightness.light: corePalette.toColorScheme(brightness: Brightness.light),
                  Brightness.dark: corePalette.toColorScheme(brightness: Brightness.dark),
                }
              : null);

      if (colorSchemes != null &&
          colorSchemes.containsKey(Brightness.light) &&
          colorSchemes.containsKey(Brightness.dark)) {
        // Extract color schemes with explicit typing and null safety
        final ColorScheme lightColorScheme = colorSchemes[Brightness.light]!;
        final ColorScheme darkColorScheme = colorSchemes[Brightness.dark]!;

        // Store the dynamic color schemes directly
        // We'll override their surface colors when building the theme
        _dynamicLightColorScheme = lightColorScheme;
        _dynamicDarkColorScheme = darkColorScheme;

        // Use the appropriate primary color based on current theme mode
        _primaryColor = _currentThemeMode == AppThemeMode.light ? lightColorScheme.primary : darkColorScheme.primary;
      } else {
        // Use the default color schemes we created
        _dynamicLightColorScheme = defaultLightScheme;
        _dynamicDarkColorScheme = defaultDarkScheme;

        // Set primary color based on the default schemes
        _primaryColor =
            _currentThemeMode == AppThemeMode.light ? defaultLightScheme.primary : defaultDarkScheme.primary;
      }
    } catch (e) {
      // Fallback to default color on any error
      _resetToDefaultColors();
    }
  }

  // Helper method to create a color scheme with fixed surface colors
  ColorScheme _createFixedColorScheme(bool isDark, Color primaryColor) {
    return isDark
        ? ColorScheme.dark(
            primary: primaryColor,
            onPrimary: primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            surface: surface1,
            onSurface: textColor,
            secondary: surface3,
            onSecondary: textColor,
            outline: dividerColor,
            outlineVariant: dividerColor.withValues(alpha: 0.5),
            surfaceTint: Colors.transparent, // Disable surface tinting
            surfaceContainerLowest: surface0,
            surfaceContainerLow: surface1,
            surfaceContainer: surface2,
            surfaceContainerHigh: surface3,
            surfaceContainerHighest: surface3,
            inverseSurface: const Color(0xFFFFFBFF),
          )
        : ColorScheme.light(
            primary: primaryColor,
            onPrimary: primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            surface: surface1,
            onSurface: textColor,
            secondary: surface3,
            onSecondary: textColor,
            outline: dividerColor,
            outlineVariant: dividerColor.withValues(alpha: 0.5),
            surfaceTint: Colors.transparent, // Disable surface tinting
            surfaceContainerLowest: surface0,
            surfaceContainerLow: surface1,
            surfaceContainer: surface2,
            surfaceContainerHigh: surface3,
            surfaceContainerHighest: surface3,
            inverseSurface: const Color(0xFF121212),
          );
  }

  void _resetToDefaultColors() {
    // Create default color schemes
    final ColorScheme defaultLightScheme = ColorScheme.fromSeed(
      seedColor: domain.AppTheme.primaryColor,
      brightness: Brightness.light,
    );

    final ColorScheme defaultDarkScheme = ColorScheme.fromSeed(
      seedColor: domain.AppTheme.primaryColor,
      brightness: Brightness.dark,
    );

    // Set default color schemes but don't use their surface colors
    _dynamicLightColorScheme = defaultLightScheme;
    _dynamicDarkColorScheme = defaultDarkScheme;

    // Reset to default primary color
    _primaryColor = domain.AppTheme.primaryColor;
  }

  @protected
  void notifyThemeChanged() {
    _themeChangesController.add(null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeChangesController.close();
  }
}
