import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/shared/services/abstraction/i_translation_service.dart';

class StartupSettings extends StatefulWidget {
  static bool get compatiblePlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux || Platform.isAndroid;

  const StartupSettings({super.key});

  @override
  State<StartupSettings> createState() => _StartupSettingsState();
}

class _StartupSettingsState extends State<StartupSettings> {
  final _startupService = container.resolve<IStartupSettingsService>();
  final _translationService = container.resolve<ITranslationService>();
  get _isSystemSettingNeeded => Platform.isAndroid;

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadStartupSetting();
  }

  Future<void> _loadStartupSetting() async {
    if (!StartupSettings.compatiblePlatform) return;

    try {
      final isEnabled = await _startupService.isEnabledAtStartup();
      if (mounted) {
        setState(() {
          _isEnabled = isEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading startup setting: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleStartupSetting(bool value) async {
    if (_isUpdating) return;

    if (!_isSystemSettingNeeded) {
      setState(() {
        _isUpdating = true;
      });
    }

    try {
      if (value) {
        await _startupService.enableStartAtStartup();
      } else {
        await _startupService.disableStartAtStartup();
      }
      await _loadStartupSetting();
    } catch (e) {
      debugPrint('Error toggling startup setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translationService.translate(
                value ? SettingsTranslationKeys.enableStartupError : SettingsTranslationKeys.disableStartupError)),
          ),
        );
      }
    } finally {
      if (mounted && !_isSystemSettingNeeded) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!StartupSettings.compatiblePlatform) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.launch),
        title: Text(
          _translationService.translate(SettingsTranslationKeys.startupTitle),
          style: AppTheme.bodyMedium,
        ),
        subtitle: Platform.isAndroid
            ? Text(
                _translationService.translate(SettingsTranslationKeys.startupSubtitle),
                style: AppTheme.bodySmall,
              )
            : null,
        trailing: Platform.isAndroid
            ? const Icon(Icons.arrow_forward_ios, size: AppTheme.fontSizeLarge)
            : _isLoading || _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: _isEnabled,
                    onChanged: _toggleStartupSetting,
                  ),
        onTap: () => _toggleStartupSetting(!_isEnabled),
      ),
    );
  }
}
