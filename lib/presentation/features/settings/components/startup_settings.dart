import 'dart:io';
import 'package:flutter/material.dart';
import 'package:whph/presentation/shared/services/abstraction/i_startup_settings_service.dart';
import 'package:whph/main.dart';

class StartupSettings extends StatefulWidget {
  const StartupSettings({super.key});

  @override
  State<StartupSettings> createState() => _StartupSettingsState();
}

class _StartupSettingsState extends State<StartupSettings> {
  final _startupService = container.resolve<IStartupSettingsService>();

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadStartupSetting();
  }

  Future<void> _loadStartupSetting() async {
    if (!_isDesktop) return;

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

    setState(() {
      _isUpdating = true;
    });

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
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.launch),
        title: const Text('Start at Startup'),
        trailing: _isLoading || _isUpdating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value: _isEnabled,
                onChanged: _toggleStartupSetting,
              ),
      ),
    );
  }
}
