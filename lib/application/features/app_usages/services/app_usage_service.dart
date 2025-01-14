import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/domain/features/shared/constants/app_theme.dart';
import 'abstraction/i_app_usage_service.dart';
import 'package:app_usage/app_usage.dart' as app_usage_package;

class AppUsageService implements IAppUsageService {
  String _activeDesktopWindowOutput = '';
  int _activeDesktopWindowTime = 0;
  Timer? _intervalTimer;
  Timer? _periodicTimer;

  final IAppUsageRepository _appUsageRepository;

  AppUsageService(this._appUsageRepository);

  @override
  void startTracking() {
    if (Platform.isWindows || Platform.isLinux) {
      _startDesktopTracking();
    } else if (Platform.isAndroid) {
      _startMobileTracking();
    }
  }

  void _startDesktopTracking() {
    _intervalTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      String? currentWindow = await _getDesktopActiveWindow();
      if (currentWindow == null) return;

      if (currentWindow != _activeDesktopWindowOutput) {
        if (_activeDesktopWindowOutput.isNotEmpty) {
          if (kDebugMode) {
            print('$_activeDesktopWindowOutput: $_activeDesktopWindowTime seconds');
          }

          List<String> activeWindowOutputSections = _activeDesktopWindowOutput.split(',');
          String appName = activeWindowOutputSections[1].isNotEmpty
              ? activeWindowOutputSections[1]
              : activeWindowOutputSections[0].isNotEmpty
                  ? activeWindowOutputSections[0]
                  : 'Unknown';

          _saveAppUsage(appName, _activeDesktopWindowTime);
        }

        _activeDesktopWindowOutput = currentWindow;
        _activeDesktopWindowTime = 0;
      }

      _activeDesktopWindowTime += 1;
    });
  }

  Future<String?> _getDesktopActiveWindow() async {
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

  void _startMobileTracking() {
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (Platform.isAndroid) {
        DateTime endDate = DateTime.now();
        DateTime startDate = endDate.subtract(Duration(hours: 1));
        List<app_usage_package.AppUsageInfo> usageStats =
            await app_usage_package.AppUsage().getAppUsage(startDate, endDate);

        if (usageStats.isEmpty) return;

        for (app_usage_package.AppUsageInfo usage in usageStats) {
          _saveAppUsage(usage.appName, usage.usage.inSeconds, overwrite: true);
        }
      }
    });
  }

  static final List<Color> _chartColors = [
    AppTheme.chartColor1,
    AppTheme.chartColor2,
    AppTheme.chartColor3,
    AppTheme.chartColor4,
    AppTheme.chartColor5,
    AppTheme.chartColor6,
    AppTheme.chartColor7,
    AppTheme.chartColor8,
    AppTheme.chartColor9,
    AppTheme.chartColor10,
  ];
  Future<void> _saveAppUsage(String appName, int duration, {bool overwrite = false}) async {
    AppUsage? appUsage = await _appUsageRepository.getByDateAndHour(
      name: appName,
      year: DateTime.now().toUtc().year,
      month: DateTime.now().toUtc().month,
      day: DateTime.now().toUtc().day,
      hour: DateTime.now().toUtc().hour,
    );

    if (appUsage != null) {
      if (overwrite) {
        appUsage.duration = duration;
      } else {
        appUsage.duration += duration;
      }

      await _appUsageRepository.update(appUsage);
    } else {
      AppUsage? firstAppUsage = await _appUsageRepository.getFirst(
        CustomWhereFilter(
          'name = ? AND deleted_date IS NULL',
          [appName],
        ),
      );

      appUsage = AppUsage(
        id: nanoid(),
        name: appName,
        color: firstAppUsage == null ? _chartColors[Random().nextInt(_chartColors.length)].toHexString() : null,
        duration: duration,
        createdDate: DateTime(0),
      );
      await _appUsageRepository.add(appUsage);
    }
  }

  @override
  void stopTracking() {
    _intervalTimer?.cancel();
    _periodicTimer?.cancel();
  }
}
