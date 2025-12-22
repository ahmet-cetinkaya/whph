import 'dart:async';
import 'package:flutter/material.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_theme_service.dart';
import 'package:whph/presentation/ui/shared/utils/async_error_handler.dart';
import 'package:whph/presentation/ui/shared/components/color_picker/color_picker.dart';

import 'package:whph/core/domain/shared/constants/app_theme.dart' as domain;
import 'package:whph/main.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/presentation/ui/features/settings/components/settings_menu_tile.dart';
import 'package:whph/presentation/ui/shared/components/styled_icon.dart';
import 'package:whph/presentation/ui/shared/components/information_card.dart';
import 'package:whph/presentation/ui/shared/components/section_header.dart';
import 'package:acore/acore.dart' hide Container;

class ThemeSettings extends StatefulWidget {
  final VoidCallback? onLoaded;

  const ThemeSettings({super.key, this.onLoaded});

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
      onSuccess: (_) {
        widget.onLoaded?.call();
      },
      onError: (e) {
        Logger.error('Error loading theme settings: $e');
        widget.onLoaded?.call();
      },
    );
  }

  void _showThemeModal() {
    if (!mounted) return;

    ResponsiveDialogHelper.showResponsiveDialog(
      context: context,
      size: DialogSize.max,
      isScrollable: false,
      child: _ThemeDialogWrapper(
        currentThemeMode: _themeMode,
        currentDynamicAccentColor: _dynamicAccentColor,
        currentCustomAccentColor: _customAccentColor,
        currentCustomAccentColorValue: _customAccentColorValue,
        currentUiDensity: _uiDensity,
        onThemeChanged: (mode, dynamicAccent, customAccent, customAccentValue, density) {
          if (mounted) {
            setState(() {
              _themeMode = mode;
              _dynamicAccentColor = dynamicAccent;
              _customAccentColor = customAccent;
              _customAccentColorValue = customAccentValue;
              _uiDensity = density;
            });
          }
        },
        onSaveThemeMode: _themeService.setThemeMode,
        onSaveDynamicAccentColor: _themeService.setDynamicAccentColor,
        onSaveCustomAccentColor: _themeService.setCustomAccentColor,
        onSaveUiDensity: _themeService.setUiDensity,
      ),
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
    return SettingsMenuTile(
      icon: Icons.palette,
      title: _translationService.translate(SettingsTranslationKeys.themeTitle),
      subtitle: _isLoading ? null : _getThemeDescription(),
      trailing: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _isLoading ? () {} : _showThemeModal,
      isActive: true,
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

  Widget _buildSelectableContainer({
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTheme.sizeMedium),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : AppTheme.surface1,
          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildThemeModeOption(AppThemeMode mode, String titleKey, IconData icon) {
    final isSelected = _themeMode == mode;
    final theme = Theme.of(context);

    return Expanded(
      child: _buildSelectableContainer(
        isSelected: isSelected,
        onTap: () async {
          setState(() {
            _themeMode = mode;
          });
          _updateTheme();
          await widget.onSaveThemeMode(mode);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : AppTheme.textColor,
              size: 28,
            ),
            const SizedBox(height: AppTheme.sizeSmall),
            Text(
              _translationService.translate(titleKey),
              style: AppTheme.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : AppTheme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDensityOption(domain.UiDensity value, String titleKey, String subtitle) {
    final isSelected = _uiDensity == value;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () async {
        setState(() {
          _uiDensity = value;
        });
        _updateTheme();
        await widget.onSaveUiDensity(value);
      },
      borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.sizeMedium, vertical: AppTheme.sizeSmall),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
        ),
        child: Row(
          children: [
            Radio<domain.UiDensity>(
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
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _translationService.translate(titleKey),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _translationService.translate(SettingsTranslationKeys.themeTitle),
          style: AppTheme.headlineSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              InformationCard.themed(
                context: context,
                icon: Icons.info_outline,
                text: _translationService.translate(SettingsTranslationKeys.themeDescription),
              ),
              const SizedBox(height: AppTheme.sizeXLarge),

              // Theme Mode Selection
              SectionHeader(
                title: _translationService.translate(SettingsTranslationKeys.themeModeTitle),
                titleStyle: AppTheme.labelLarge,
              ),
              Row(
                children: [
                  _buildThemeModeOption(
                    AppThemeMode.light,
                    SettingsTranslationKeys.themeModeLight,
                    Icons.light_mode,
                  ),
                  const SizedBox(width: AppTheme.sizeMedium),
                  _buildThemeModeOption(
                    AppThemeMode.dark,
                    SettingsTranslationKeys.themeModeDark,
                    Icons.dark_mode,
                  ),
                  const SizedBox(width: AppTheme.sizeMedium),
                  _buildThemeModeOption(
                    AppThemeMode.auto,
                    SettingsTranslationKeys.themeModeAuto,
                    Icons.brightness_auto,
                  ),
                ],
              ),
              if (_themeMode == AppThemeMode.auto)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.sizeSmall),
                  child: Text(
                    _translationService.translate(SettingsTranslationKeys.themeModeAutoDescription),
                    style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: AppTheme.sizeXLarge),

              // Accent Color Section
              SectionHeader(
                title: _translationService.translate(SettingsTranslationKeys.customAccentColorTitle),
                titleStyle: AppTheme.labelLarge,
              ),

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface1,
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: Column(
                  children: [
                    // Dynamic Color Switch
                    SwitchListTile.adaptive(
                      title: Text(
                        _translationService.translate(SettingsTranslationKeys.dynamicAccentColorTitle),
                        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _translationService.translate(SettingsTranslationKeys.dynamicAccentColorDescription),
                        style: AppTheme.bodySmall,
                      ),
                      value: _dynamicAccentColor,
                      activeColor: theme.colorScheme.primary,
                      secondary: StyledIcon(Icons.wallpaper, isActive: _dynamicAccentColor),
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

                    Divider(height: 1, color: theme.dividerColor),

                    // Custom Color Switch
                    SwitchListTile.adaptive(
                      title: Text(
                        _translationService.translate(SettingsTranslationKeys.customAccentColorTitle),
                        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _translationService.translate(SettingsTranslationKeys.customAccentColorDescription),
                        style: AppTheme.bodySmall,
                      ),
                      value: _customAccentColor,
                      activeColor: theme.colorScheme.primary,
                      secondary: StyledIcon(Icons.palette, isActive: _customAccentColor),
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

                    // Color Picker (Animated)
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        children: [
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
                                translationService: _translationService,
                              ),
                            ),
                          ),
                        ],
                      ),
                      crossFadeState: _customAccentColor ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.sizeXLarge),

              // UI Density
              SectionHeader(
                title: _translationService.translate(SettingsTranslationKeys.uiDensityTitle),
                titleStyle: AppTheme.labelLarge,
              ),

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface1,
                  borderRadius: BorderRadius.circular(AppTheme.containerBorderRadius),
                ),
                child: Column(
                  children: [
                    _buildDensityOption(domain.UiDensity.compact, SettingsTranslationKeys.uiDensityCompact, '0.8x'),
                    Divider(height: 1, color: theme.dividerColor, indent: 50),
                    _buildDensityOption(
                        domain.UiDensity.normal, SettingsTranslationKeys.uiDensityNormal, '1.0x (Default)'),
                    Divider(height: 1, color: theme.dividerColor, indent: 50),
                    _buildDensityOption(domain.UiDensity.large, SettingsTranslationKeys.uiDensityLarge, '1.2x'),
                    Divider(height: 1, color: theme.dividerColor, indent: 50),
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
