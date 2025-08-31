import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whph/src/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/src/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/src/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/src/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/src/presentation/ui/shared/enums/dialog_size.dart';
import 'package:whph/src/presentation/ui/shared/utils/responsive_dialog_helper.dart';
import 'package:whph/src/presentation/ui/shared/components/color_picker.dart';
import 'package:whph/src/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart';

class ThemeSettings extends StatefulWidget {
  const ThemeSettings({super.key});

  @override
  State<ThemeSettings> createState() => _ThemeSettingsState();
}

class _ThemeSettingsState extends State<ThemeSettings> {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  AppThemeMode _themeMode = AppThemeMode.dark;
  bool _dynamicAccentColor = false;
  bool _customAccentColor = false;
  Color? _customAccentColorValue;
  domain.UiDensity _uiDensity = domain.AppTheme.defaultUiDensity;
  bool _isLoading = true;
  StreamSubscription<void>? _themeSubscription;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _setupThemeListener();
  }

  @override
  void dispose() {
    _themeSubscription?.cancel();
    super.dispose();
  }

  void _setupThemeListener() {
    _themeSubscription = _themeService.themeChanges.listen((_) async {
      await _loadThemeSettings();
    });
  }

  Future<void> _loadThemeSettings() async {
    await AsyncErrorHandler.executeWithLoading(
      context: context,
      setLoading: (isLoading) {
        if (mounted) {
          setState(() {
            _isLoading = isLoading;
          });
        }
      },
      errorMessage: _translationService.translate(SettingsTranslationKeys.themeSettingsError),
      operation: () async {
        _themeMode = _themeService.currentThemeMode;
        _dynamicAccentColor = _themeService.isDynamicAccentColorEnabled;
        _customAccentColor = _themeService.isCustomAccentColorEnabled;
        _customAccentColorValue = _themeService.customAccentColor;
        _uiDensity = _themeService.currentUiDensity;
        return true;
      },
    );
  }

  Future<void> _saveThemeMode(AppThemeMode mode) async {
    await _themeService.setThemeMode(mode);
  }

  Future<void> _saveDynamicAccentColor(bool enabled) async {
    await _themeService.setDynamicAccentColor(enabled);
  }

  Future<void> _saveCustomAccentColor(Color? color) async {
    await _themeService.setCustomAccentColor(color);
  }

  Future<void> _saveUiDensity(domain.UiDensity density) async {
    await _themeService.setUiDensity(density);
  }

  void _showThemeModal() {
    if (!mounted) return;

    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      child: _ThemeDialogWrapper(
        currentThemeMode: _themeMode,
        currentDynamicAccentColor: _dynamicAccentColor,
        currentCustomAccentColor: _customAccentColor,
        currentCustomAccentColorValue: _customAccentColorValue,
        currentUiDensity: _uiDensity,
        onThemeChanged: (mode, dynamic, custom, customColor, uiDensity) {
          if (mounted) {
            setState(() {
              _themeMode = mode;
              _dynamicAccentColor = dynamic;
              _customAccentColor = custom;
              _customAccentColorValue = customColor;
              _uiDensity = uiDensity;
            });
          }
        },
        onSaveThemeMode: _saveThemeMode,
        onSaveDynamicAccentColor: _saveDynamicAccentColor,
        onSaveCustomAccentColor: _saveCustomAccentColor,
        onSaveUiDensity: _saveUiDensity,
      ),
      size: DialogSize.medium,
    );
  }

  String _getThemeDescription() {
    String mode;
    switch (_themeMode) {
      case AppThemeMode.light:
        mode = _translationService.translate(SettingsTranslationKeys.themeModeLight);
        break;
      case AppThemeMode.dark:
        mode = _translationService.translate(SettingsTranslationKeys.themeModeDark);
        break;
      case AppThemeMode.auto:
        mode = _translationService.translate(SettingsTranslationKeys.themeModeAuto);
        break;
    }

    final features = <String>[];
    if (_dynamicAccentColor) {
      features.add(_translationService.translate(SettingsTranslationKeys.dynamicAccentColorFeature));
    }
    if (_customAccentColor) {
      features.add(_translationService.translate(SettingsTranslationKeys.customAccentColorFeature));
    }

    // Add UI density if not normal
    if (_uiDensity != domain.UiDensity.normal) {
      const densityKeys = {
        domain.UiDensity.compact: SettingsTranslationKeys.uiDensityCompact,
        domain.UiDensity.large: SettingsTranslationKeys.uiDensityLarge,
        domain.UiDensity.larger: SettingsTranslationKeys.uiDensityLarger,
      };
      final translationKey = densityKeys[_uiDensity];
      if (translationKey != null) {
        features.add(_translationService.translate(translationKey));
      }
    }

    if (features.isNotEmpty) {
      return '$mode (${features.join(', ')})';
    }
    return mode;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.palette),
        title: Text(
          _translationService.translate(SettingsTranslationKeys.themeTitle),
          style: AppTheme.bodyMedium,
        ),
        subtitle: _isLoading
            ? null
            : Text(
                _getThemeDescription(),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
        trailing: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: _isLoading ? null : _showThemeModal,
      ),
    );
  }
}

class _ThemeDialogWrapper extends StatelessWidget {
  final AppThemeMode currentThemeMode;
  final bool currentDynamicAccentColor;
  final bool currentCustomAccentColor;
  final Color? currentCustomAccentColorValue;
  final domain.UiDensity currentUiDensity;
  final Function(AppThemeMode, bool, bool, Color?, domain.UiDensity) onThemeChanged;
  final Future<void> Function(AppThemeMode) onSaveThemeMode;
  final Future<void> Function(bool) onSaveDynamicAccentColor;
  final Future<void> Function(Color?) onSaveCustomAccentColor;
  final Future<void> Function(domain.UiDensity) onSaveUiDensity;

  const _ThemeDialogWrapper({
    required this.currentThemeMode,
    required this.currentDynamicAccentColor,
    required this.currentCustomAccentColor,
    required this.currentCustomAccentColorValue,
    required this.currentUiDensity,
    required this.onThemeChanged,
    required this.onSaveThemeMode,
    required this.onSaveDynamicAccentColor,
    required this.onSaveCustomAccentColor,
    required this.onSaveUiDensity,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = container.resolve<IThemeService>();

    return StreamBuilder<void>(
      stream: themeService.themeChanges,
      builder: (context, snapshot) {
        return Theme(
          data: themeService.themeData,
          child: Builder(
            builder: (themedContext) {
              return _ThemeDialog(
                currentThemeMode: currentThemeMode,
                currentDynamicAccentColor: currentDynamicAccentColor,
                currentCustomAccentColor: currentCustomAccentColor,
                currentCustomAccentColorValue: currentCustomAccentColorValue,
                currentUiDensity: currentUiDensity,
                onThemeChanged: onThemeChanged,
                onSaveThemeMode: onSaveThemeMode,
                onSaveDynamicAccentColor: onSaveDynamicAccentColor,
                onSaveCustomAccentColor: onSaveCustomAccentColor,
                onSaveUiDensity: onSaveUiDensity,
              );
            },
          ),
        );
      },
    );
  }
}

class _ThemeDialog extends StatefulWidget {
  final AppThemeMode currentThemeMode;
  final bool currentDynamicAccentColor;
  final bool currentCustomAccentColor;
  final Color? currentCustomAccentColorValue;
  final domain.UiDensity currentUiDensity;
  final Function(AppThemeMode, bool, bool, Color?, domain.UiDensity) onThemeChanged;
  final Future<void> Function(AppThemeMode) onSaveThemeMode;
  final Future<void> Function(bool) onSaveDynamicAccentColor;
  final Future<void> Function(Color?) onSaveCustomAccentColor;
  final Future<void> Function(domain.UiDensity) onSaveUiDensity;

  const _ThemeDialog({
    required this.currentThemeMode,
    required this.currentDynamicAccentColor,
    required this.currentCustomAccentColor,
    required this.currentCustomAccentColorValue,
    required this.currentUiDensity,
    required this.onThemeChanged,
    required this.onSaveThemeMode,
    required this.onSaveDynamicAccentColor,
    required this.onSaveCustomAccentColor,
    required this.onSaveUiDensity,
  });

  @override
  State<_ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends State<_ThemeDialog> {
  final _translationService = container.resolve<ITranslationService>();
  final _themeService = container.resolve<IThemeService>();

  late AppThemeMode _themeMode;
  late bool _dynamicAccentColor;
  late bool _customAccentColor;
  late Color? _customAccentColorValue;
  late domain.UiDensity _uiDensity;

  @override
  void initState() {
    super.initState();
    _updateFromService();
  }

  @override
  void didUpdateWidget(_ThemeDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateFromService();
  }

  void _updateFromService() {
    _themeMode = _themeService.currentThemeMode;
    _dynamicAccentColor = _themeService.isDynamicAccentColorEnabled;
    _customAccentColor = _themeService.isCustomAccentColorEnabled;
    _customAccentColorValue = _themeService.customAccentColor;
    _uiDensity = _themeService.currentUiDensity;
  }

  void _updateTheme() {
    widget.onThemeChanged(_themeMode, _dynamicAccentColor, _customAccentColor, _customAccentColorValue, _uiDensity);
  }

  Widget _buildDensityOption(domain.UiDensity value, String titleKey, String subtitle) {
    final theme = Theme.of(context);
    return RadioListTile<domain.UiDensity>(
      title: Text(
        _translationService.translate(titleKey),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      value: value,
      groupValue: _uiDensity,
      activeColor: theme.colorScheme.primary,
      onChanged: (newValue) async {
        if (newValue != null) {
          setState(() {
            _uiDensity = newValue;
          });
          _updateTheme();
          await widget.onSaveUiDensity(newValue);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        title: Text(
          _translationService.translate(SettingsTranslationKeys.themeTitle),
        ),
        elevation: 0,
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeMedium),
          child: ListView(
            children: [
              // Description
              Text(
                _translationService.translate(SettingsTranslationKeys.themeDescription),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppTheme.sizeLarge),

              // Theme Mode Selection
              Text(
                _translationService.translate(SettingsTranslationKeys.themeModeTitle),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.sizeSmall),

              Card(
                color: theme.cardTheme.color,
                child: Column(
                  children: [
                    RadioListTile<AppThemeMode>(
                      title: Text(
                        _translationService.translate(SettingsTranslationKeys.themeModeLight),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      value: AppThemeMode.light,
                      groupValue: _themeMode,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            _themeMode = value;
                          });
                          _updateTheme();
                          await widget.onSaveThemeMode(value);
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      color: theme.dividerColor,
                    ),
                    RadioListTile<AppThemeMode>(
                      title: Text(
                        _translationService.translate(SettingsTranslationKeys.themeModeDark),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      value: AppThemeMode.dark,
                      groupValue: _themeMode,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            _themeMode = value;
                          });
                          _updateTheme();
                          await widget.onSaveThemeMode(value);
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      color: theme.dividerColor,
                    ),
                    RadioListTile<AppThemeMode>(
                      title: Text(
                        _translationService.translate(SettingsTranslationKeys.themeModeAuto),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        _translationService.translate(SettingsTranslationKeys.themeModeAutoDescription),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      value: AppThemeMode.auto,
                      groupValue: _themeMode,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            _themeMode = value;
                          });
                          _updateTheme();
                          await widget.onSaveThemeMode(value);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.sizeLarge),

              // Dynamic Accent Color
              Text(
                _translationService.translate(SettingsTranslationKeys.dynamicAccentColorTitle),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.sizeSmall),

              Card(
                color: theme.cardTheme.color,
                child: SwitchListTile(
                  title: Text(
                    _translationService.translate(SettingsTranslationKeys.dynamicAccentColorTitle),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    _translationService.translate(SettingsTranslationKeys.dynamicAccentColorDescription),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  value: _dynamicAccentColor,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) async {
                    setState(() {
                      _dynamicAccentColor = value;
                      if (value) {
                        _customAccentColor = false;
                        _customAccentColorValue = null;
                      }
                    });
                    _updateTheme();
                    await widget.onSaveDynamicAccentColor(value);
                  },
                ),
              ),

              const SizedBox(height: AppTheme.sizeLarge),

              // Custom Accent Color
              Text(
                _translationService.translate(SettingsTranslationKeys.customAccentColorTitle),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.sizeSmall),

              Card(
                color: theme.cardTheme.color,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        _translationService.translate(SettingsTranslationKeys.customAccentColorTitle),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        _translationService.translate(SettingsTranslationKeys.customAccentColorDescription),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      value: _customAccentColor,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (value) async {
                        setState(() {
                          _customAccentColor = value;
                          if (!value) {
                            _customAccentColorValue = null;
                          } else {
                            _dynamicAccentColor = false;
                            // Set default color if none selected
                            _customAccentColorValue ??= theme.colorScheme.primary;
                          }
                        });
                        _updateTheme();
                        await widget.onSaveCustomAccentColor(value ? _customAccentColorValue : null);
                      },
                    ),
                    if (_customAccentColor) ...[
                      Divider(height: 1, color: theme.dividerColor),
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.sizeMedium),
                        child: SizedBox(
                          height: 300,
                          child: ColorPicker(
                            pickerColor: _customAccentColorValue ?? theme.colorScheme.primary,
                            onChangeColor: (color) async {
                              setState(() {
                                _customAccentColorValue = color;
                              });
                              _updateTheme();
                              await widget.onSaveCustomAccentColor(color);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.sizeLarge),

              // UI Density
              Text(
                _translationService.translate(SettingsTranslationKeys.uiDensityTitle),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppTheme.sizeSmall),

              Card(
                color: theme.cardTheme.color,
                child: Column(
                  children: [
                    _buildDensityOption(domain.UiDensity.compact, SettingsTranslationKeys.uiDensityCompact, '0.8x'),
                    Divider(height: 1, color: theme.dividerColor),
                    _buildDensityOption(
                        domain.UiDensity.normal, SettingsTranslationKeys.uiDensityNormal, '1.0x (Default)'),
                    Divider(height: 1, color: theme.dividerColor),
                    _buildDensityOption(domain.UiDensity.large, SettingsTranslationKeys.uiDensityLarge, '1.2x'),
                    Divider(height: 1, color: theme.dividerColor),
                    _buildDensityOption(domain.UiDensity.larger, SettingsTranslationKeys.uiDensityLarger, '1.4x'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
