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
    if (PlatformUtils.isDesktop) {
      try {
        final executable = Platform.resolvedExecutable;
        final args = Platform.executableArguments.join(' ');

        if (Platform.isWindows) {
          await Process.start(
            'cmd',
            ['/c', 'timeout /t 1 & start "" "$executable" $args'],
            mode: ProcessStartMode.detached,
          );
        } else if (Platform.isLinux || Platform.isMacOS) {
          await Process.start(
            'sh',
            ['-c', 'sleep 1; "$executable" $args &'],
            mode: ProcessStartMode.detached,
          );
        }
      } catch (e) {
        Logger.error('Failed to restart app: $e');
      }
    }
    exit(0);
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
