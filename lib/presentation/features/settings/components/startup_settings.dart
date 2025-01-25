import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/constants/app_theme.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/main.dart';

class StartupSettings extends StatefulWidget {
  static bool get compatiblePlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux || Platform.isAndroid;

  const StartupSettings({super.key});

  @override
  State<StartupSettings> createState() => _StartupSettingsState();
}

class _StartupSettingsState extends State<StartupSettings> {
  final _startupService = container.resolve<IStartupSettingsService>();
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
            content: Text('Failed to ${value ? 'enable' : 'disable'} startup setting'),
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
        title: const Text('Start at Startup'),
        subtitle: Platform.isAndroid
            ? const Text('Tap to open system settings and enable auto-start permission for the app',
                style: AppTheme.bodySmall)
            : null,
        trailing: Platform.isAndroid
            ? const Icon(Icons.arrow_forward_ios, size: 16)
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
