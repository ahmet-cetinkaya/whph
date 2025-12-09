import 'dart:async';
import 'dart:io';

import 'package:acore/acore.dart';
import 'package:flutter/material.dart';
import 'package:whph/core/shared/utils/logger.dart';
import 'package:whph/main.dart';
import 'package:whph/presentation/ui/features/settings/constants/settings_translation_keys.dart';
import 'package:whph/presentation/ui/shared/constants/app_theme.dart';
import 'package:whph/presentation/ui/shared/services/abstraction/i_translation_service.dart';

class RestartScreen extends StatefulWidget {
  const RestartScreen({super.key});

  @override
  State<RestartScreen> createState() => _RestartScreenState();
}

class _RestartScreenState extends State<RestartScreen> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isDesktop) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
        _restartApp();
      }
    });
  }

  Future<void> _restartApp() async {
    if (!PlatformUtils.isDesktop) {
      exit(0);
    }

    try {
      final executable = Platform.resolvedExecutable;
      final args = Platform.executableArguments;

      Logger.info('Restarting application: $executable $args');

      if (Platform.isWindows) {
        await _restartWindows(executable, args);
      } else if (Platform.isLinux) {
        await _restartLinux(executable, args);
      } else if (Platform.isMacOS) {
        await _restartMacOS(executable, args);
      }

      // Give the new process time to start before exiting
      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (e, stackTrace) {
      Logger.error('Unexpected error during restart: $e\nStack trace: $stackTrace');
      _showManualRestartFallback();
      exit(1);
    }
  }

  Future<bool> _restartWindows(String executable, List<String> args) async {
    try {
      // Method 1: Use PowerShell for more reliable restart
      await Process.start(
        'powershell',
        [
          '-Command',
          'Start-Process',
          '-FilePath',
          executable,
          if (args.isNotEmpty) ...['-ArgumentList', ...args],
          '-NoNewWindow'
        ],
        mode: ProcessStartMode.detached,
      );

      // Wait briefly to ensure process starts
      await Future.delayed(const Duration(milliseconds: 1000));
      return true;
    } catch (e) {
      Logger.warning('PowerShell restart failed, trying cmd method: $e');

      try {
        // Fallback to cmd method
        await Process.start(
          'cmd',
          [
            '/c',
            'timeout /t 2 /nobreak > nul 2>&1 && start "" /B "$executable" ${args.map((arg) => '"$arg"').join(' ')}'
          ],
          mode: ProcessStartMode.detached,
        );

        return true; // Assume success if no immediate exception
      } catch (e2) {
        Logger.error('Both restart methods failed: $e2');
        return false;
      }
    }
  }

  Future<bool> _restartLinux(String executable, List<String> args) async {
    try {
      // Method 1: Use nohup for reliable background process
      final command = 'nohup "$executable" ${args.map((arg) => '"$arg"').join(' ')} > /dev/null 2>&1 &';
      await Process.start(
        'bash',
        ['-c', command],
        mode: ProcessStartMode.detached,
      );

      // Wait briefly to ensure process starts
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      Logger.warning('nohup restart failed, trying shell method: $e');

      try {
        // Fallback method
        await Process.start(
          'sh',
          ['-c', 'sleep 1 && "$executable" ${args.map((arg) => '"$arg"').join(' ')} &'],
          mode: ProcessStartMode.detached,
        );

        return true; // Assume success if no immediate exception
      } catch (e2) {
        Logger.error('Both Linux restart methods failed: $e2');
        return false;
      }
    }
  }

  Future<bool> _restartMacOS(String executable, List<String> args) async {
    try {
      // Use open command for macOS apps
      await Process.start(
        'open',
        ['-n', '-a', executable, if (args.isNotEmpty) ...args],
        mode: ProcessStartMode.detached,
      );

      // Wait briefly to ensure process starts
      await Future.delayed(const Duration(milliseconds: 1000));
      return true;
    } catch (e) {
      Logger.warning('open command failed, trying shell method: $e');

      try {
        // Fallback method
        await Process.start(
          'sh',
          ['-c', 'sleep 1 && "$executable" ${args.map((arg) => '"$arg"').join(' ')} &'],
          mode: ProcessStartMode.detached,
        );

        return true; // Assume success if no immediate exception
      } catch (e2) {
        Logger.error('Both macOS restart methods failed: $e2');
        return false;
      }
    }
  }

  void _showManualRestartFallback() {
    // This method would show a manual restart instruction
    // For now, it just logs the instruction since we're in a terminal state
    Logger.warning('Please restart the application manually');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translationService = container.resolve<ITranslationService>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sizeLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppTheme.sizeLarge),
              Text(
                translationService.translate(SettingsTranslationKeys.resetDatabaseRestartScreenCompletedTitle),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sizeMedium),
              Text(
                PlatformUtils.isDesktop
                    ? translationService.translate(
                        SettingsTranslationKeys.resetDatabaseRestartScreenDesktopMessage,
                        namedArgs: {'seconds': _countdown.toString()},
                      )
                    : translationService.translate(SettingsTranslationKeys.resetDatabaseRestartScreenMobileMessage),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (PlatformUtils.isDesktop) ...[
                const SizedBox(height: AppTheme.sizeLarge),
                FilledButton(
                  onPressed: _restartApp,
                  child: Text(
                    translationService.translate(SettingsTranslationKeys.resetDatabaseRestartNowButton),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
