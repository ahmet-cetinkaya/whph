import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'abstraction/i_app_usage_service.dart';

class AppUsageService implements IAppUsageService {
  String _activeWindowOutput = '';
  int _activeWindowTime = 0;
  Timer? _timer;

  final IAppUsageRepository _appUsageRepository;

  AppUsageService(this._appUsageRepository);

  @override
  void startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      String? currentWindow = await _getActiveWindow();
      if (currentWindow == null) return;

      if (currentWindow != _activeWindowOutput) {
        if (_activeWindowOutput.isNotEmpty) {
          if (kDebugMode) {
            print('$_activeWindowOutput: $_activeWindowTime seconds');
          }

          List<String> activeWindowOutputSections = _activeWindowOutput.split(',');

          AppUsage? appUsage = await _appUsageRepository.getByDateAndHour(
            title: activeWindowOutputSections.first,
            year: DateTime.now().toUtc().year,
            month: DateTime.now().toUtc().month,
            day: DateTime.now().toUtc().day,
            hour: DateTime.now().toUtc().hour,
          );

          if (appUsage != null) {
            appUsage.duration += _activeWindowTime;
            await _appUsageRepository.update(appUsage);
          } else {
            appUsage = AppUsage(
              id: '',
              title: activeWindowOutputSections.first,
              processName: activeWindowOutputSections[1].isNotEmpty ? activeWindowOutputSections[1] : null,
              duration: _activeWindowTime,
              createdDate: DateTime(0),
            );
            await _appUsageRepository.add(appUsage);
          }
        }

        _activeWindowOutput = currentWindow;
        _activeWindowTime = 0;
      }

      _activeWindowTime++;
    });
  }

  @override
  void stopTracking() {
    _timer?.cancel();
  }

  Future<String?> _getActiveWindow() async {
    if (Platform.isLinux) {
      const scriptPath = 'linux/getActiveWindow.bash';
      final result = await Process.run('bash', ["${Directory.current.path}/$scriptPath"]);

      return result.stdout.trim();
    } else if (Platform.isWindows) {
      const scriptPath = 'windows/getActiveWindow.ps1';
      final result = await Process.run('powershell', ["-File", "${Directory.current.path}/$scriptPath"]);

      return result.stdout.trim();
    }

    return null;
  }
}
