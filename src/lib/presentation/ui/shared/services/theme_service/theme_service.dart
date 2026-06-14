import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

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
  bool _isDisposed = false;

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
  set isPollingLinuxTheme(bool value) => _isPollingLinuxTheme = value;

  bool _isPollingLinuxTheme = false;

  @protected
  domain.UiDensity get storedUiDensity => _storedUiDensity;

  @protected
  double get effectiveDensityMultiplier => _effectiveDensityMultiplier;

  bool _isCustomAccentColorEnabled = false;
  Color? _customAccentColor;
  domain.UiDensity _storedUiDensity = domain.AppTheme.defaultUiDensity;
  double _effectiveDensityMultiplier = 1.0;
  Color _primaryColor = domain.AppTheme.primaryColor;
  ColorScheme? _dynamicLightColorScheme;
  ColorScheme? _dynamicDarkColorScheme;

  ThemeService({required Mediator mediator, required this.logger}) : _mediator = mediator;

  @override
  AppThemeMode get currentThemeMode => _storedThemeMode;

  @override
  bool get isDynamicAccentColorEnabled => _isDynamicAccentColorEnabled;

  @override
  bool get isCustomAccentColorEnabled => _isCustomAccentColorEnabled;

  @override
  Color? get customAccentColor => _customAccentColor;

  @override
  domain.UiDensity get currentUiDensity => _storedUiDensity;

  @override
  double get densityMultiplier => _effectiveDensityMultiplier;

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

    final builder = ThemeDataBuilder(
      isDark: isDark,
      primaryColor: _primaryColor,
      densityMultiplier: _effectiveDensityMultiplier,
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
  void didChangeMetrics() {
    if (_storedUiDensity == domain.UiDensity.system) {
      resolveEffectiveDensityMultiplier();
      if (!_isDisposed) notifyThemeChanged();
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_storedThemeMode == AppThemeMode.auto) {
      updateActualThemeMode().then((_) {
        if (!_isDisposed) {
          notifyThemeChanged();
        }
      });
    }
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    _storedThemeMode = mode;

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

    await updateActualThemeMode();

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

    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.customAccentColor,
      value: color != null ? color.toARGB32().toString() : '',
      valueType: SettingValueType.string,
    ));

    if (color != null) {
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
    _storedUiDensity = density;
    resolveEffectiveDensityMultiplier();

    await _mediator.send(SaveSettingCommand(
      key: SettingKeys.uiDensity,
      value: density.name,
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

    await updateActualThemeMode();

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

    try {
      final densityResponse = await _mediator.send<GetSettingQuery, GetSettingQueryResponse?>(
        GetSettingQuery(key: SettingKeys.uiDensity),
      );

      if (densityResponse != null) {
        _storedUiDensity = domain.UiDensity.values.firstWhere(
          (density) => density.name == densityResponse.value,
          orElse: () => domain.AppTheme.defaultUiDensity,
        );
      } else {
        _storedUiDensity = domain.AppTheme.defaultUiDensity;
      }
    } catch (e) {
      _storedUiDensity = domain.AppTheme.defaultUiDensity;
    }

    resolveEffectiveDensityMultiplier();

    await _updatePrimaryColor();
  }

  Future<void> _loadDynamicAccentColor() async {
    try {
      final ColorScheme defaultLightScheme = ColorScheme.fromSeed(
        seedColor: domain.AppTheme.primaryColor,
        brightness: Brightness.light,
      );

      final ColorScheme defaultDarkScheme = ColorScheme.fromSeed(
        seedColor: domain.AppTheme.primaryColor,
        brightness: Brightness.dark,
      );

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
        final ColorScheme lightColorScheme = colorSchemes[Brightness.light]!;
        final ColorScheme darkColorScheme = colorSchemes[Brightness.dark]!;

        _dynamicLightColorScheme = lightColorScheme;
        _dynamicDarkColorScheme = darkColorScheme;

        _primaryColor = _currentThemeMode == AppThemeMode.light ? lightColorScheme.primary : darkColorScheme.primary;
      } else {
        _dynamicLightColorScheme = defaultLightScheme;
        _dynamicDarkColorScheme = defaultDarkScheme;

        _primaryColor =
            _currentThemeMode == AppThemeMode.light ? defaultLightScheme.primary : defaultDarkScheme.primary;
      }
    } catch (e) {
      _resetToDefaultColors();
    }
  }

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
  @visibleForTesting
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

  @visibleForTesting
  @protected
  void resolveEffectiveDensityMultiplier() {
    if (_storedUiDensity == domain.UiDensity.system) {
      final textScale = WidgetsBinding.instance.platformDispatcher.textScaleFactor;
      _effectiveDensityMultiplier = textScale.clamp(0.8, 1.4);
    } else {
      _effectiveDensityMultiplier = _storedUiDensity.multiplier;
    }
  }

  /// Gets the system brightness/theme mode
  @visibleForTesting
  @protected
  Future<Brightness> getSystemBrightness() async {
    try {
      if (Platform.isLinux) {
        return await _getLinuxSystemBrightness();
      }

      // Fallback: try to get from window
      final window = WidgetsBinding.instance.platformDispatcher;
      return window.platformBrightness;
    } catch (e) {
      // Default to dark if we can't determine system theme
      return Brightness.dark;
    }
  }

  /// Gets the system brightness on Linux by querying various desktop environments
  @protected
  Future<Brightness> _getLinuxSystemBrightness() async {
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
      ).timeout(const Duration(seconds: 1));
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
      ).timeout(const Duration(seconds: 1));
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
        ).timeout(const Duration(seconds: 1));
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

    // Default fallback for Linux
    final window = WidgetsBinding.instance.platformDispatcher;
    return window.platformBrightness;
  }

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
    if (!_isDisposed && !_themeChangesController.isClosed) {
      _themeChangesController.add(null);
    }
  }

  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _themeChangesController.close();
  }
}
