import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediatr/mediatr.dart';
import 'package:whph/core/application/features/settings/queries/get_setting_query.dart';
import 'package:whph/infrastructure/shared/features/wakelock/abstractions/i_wakelock_service.dart';
import 'package:whph/presentation/ui/shared/constants/setting_keys.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/constants/shared_ui_constants.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_system_tray_service.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';
import 'package:whph/presentation/ui/shared/utils/app_theme_helper.dart';

class NormalTimer extends StatefulWidget {
  final Function(Duration) onTimeUpdate;
  final VoidCallback? onTimerStart;
  final VoidCallback? onTimerStop;

  const NormalTimer({
    super.key,
    required this.onTimeUpdate,
    this.onTimerStart,
    this.onTimerStop,
  });

  @override
  State<NormalTimer> createState() => _NormalTimerState();
}

class _NormalTimerState extends State<NormalTimer> {
  final _mediator = container.resolve<Mediator>();
  final _systemTrayService = container.resolve<ISystemTrayService>();
  final _translationService = container.resolve<ITranslationService>();
  final _wakelockService = container.resolve<IWakelockService>();

  Timer? _timer;
  Duration _elapsedTime = const Duration();
  bool _isRunning = false;
  bool _keepScreenAwake = false;

  String _getDisplayTime() {
    if (AppThemeHelper.isScreenSmallerThan(context, AppTheme.screenSmall)) {
      final totalMinutes = _elapsedTime.inMinutes;
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      if (hours > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${minutes}m';
    }

    return SharedUiConstants.formatDuration(_elapsedTime);
  }

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wakelockService.disable();
    _resetSystemTrayToDefault();
    super.dispose();
  }

  Future<void> _initializeSettings() async {
    _keepScreenAwake = await _getBoolSetting(SettingKeys.keepScreenAwake, false);
    setState(() {});
  }

  Future<bool> _getBoolSetting(String key, bool defaultValue) async {
    try {
      final response = await _mediator.send(GetSettingQuery(key: key)) as GetSettingQueryResponse?;
      if (response != null && response.value.isNotEmpty) {
        return response.value.toLowerCase() == 'true';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting bool setting $key: $e');
      }
    }
    return defaultValue;
  }

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    if (_keepScreenAwake) {
      _wakelockService.enable();
    }

    _updateSystemTray();

    // Use 1-second intervals for normal timer
    // In debug mode, speed up by 60x (1 second = 1 minute)
    final interval = kDebugMode ? const Duration(seconds: 1) : const Duration(seconds: 1);
    final increment = kDebugMode ? const Duration(minutes: 1) : const Duration(seconds: 1);

    _timer = Timer.periodic(interval, (timer) {
      setState(() {
        _elapsedTime += increment;
      });

      // Report the increment to parent
      widget.onTimeUpdate(increment);
      _updateSystemTray();
    });

    widget.onTimerStart?.call();
  }

  void _pauseTimer() {
    if (!_isRunning) return;

    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    _wakelockService.disable();
    _updateSystemTray();
  }

  void _stopTimer() {
    _timer?.cancel();
    _wakelockService.disable();

    setState(() {
      _isRunning = false;
      _elapsedTime = const Duration();
    });

    _resetSystemTrayToDefault();
    widget.onTimerStop?.call();
  }

  void _updateSystemTray() {
    if (_isRunning) {
      _systemTrayService.setTitle('Timer: ${_getDisplayTime()}');
    } else {
      _systemTrayService.setTitle('Timer Paused: ${_getDisplayTime()}');
    }
  }

  void _resetSystemTrayToDefault() {
    _systemTrayService.setTitle('WHPH');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer Display
          Text(
            _getDisplayTime(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
          ),
          const SizedBox(height: 16.0),

          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRunning) ...[
                ElevatedButton.icon(
                  onPressed: _startTimer,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_translationService.translate('Start')),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _pauseTimer,
                  icon: const Icon(Icons.pause),
                  label: Text(_translationService.translate('Pause')),
                ),
              ],
              const SizedBox(width: 16.0),
              OutlinedButton.icon(
                onPressed: _stopTimer,
                icon: const Icon(Icons.stop),
                label: Text(_translationService.translate('Stop')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
