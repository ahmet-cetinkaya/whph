import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:usage_stats_new/usage_stats.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/presentation/features/shared/constants/app_theme.dart';
import 'abstraction/i_app_usage_service.dart';

class AppUsageService implements IAppUsageService {
  String _activeWindowOutput = '';
  int _activeWindowTime = 0;
  Timer? _intervalTimer;
  Timer? _periodicTimer;

  final IAppUsageRepository _appUsageRepository;

  AppUsageService(this._appUsageRepository);

  @override
  void startTracking() {
    _intervalTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      String? currentWindow = await _getActiveWindow();
      if (currentWindow == null) return;

      if (currentWindow != _activeWindowOutput) {
        if (_activeWindowOutput.isNotEmpty) {
          if (kDebugMode) print('$_activeWindowOutput: $_activeWindowTime seconds');

          List<String> activeWindowOutputSections = _activeWindowOutput.split(',');
          String appName = activeWindowOutputSections[1].isNotEmpty
              ? activeWindowOutputSections[1]
              : activeWindowOutputSections[0].isNotEmpty
                  ? activeWindowOutputSections[0]
                  : 'Unknown';

          AppUsage? appUsage = await _appUsageRepository.getByDateAndHour(
            name: appName,
            year: DateTime.now().toUtc().year,
            month: DateTime.now().toUtc().month,
            day: DateTime.now().toUtc().day,
            hour: DateTime.now().toUtc().hour,
          );

          if (appUsage != null) {
            appUsage.duration += _activeWindowTime;
            await _appUsageRepository.update(appUsage);
          } else {
            AppUsage? firstAppUsage = await _appUsageRepository.getFirst(
              CustomWhereFilter(
                'name = ?',
                [appName],
              ),
            );
            appUsage = AppUsage(
              id: nanoid(),
              name: appName,
              color: firstAppUsage == null ? _getRandomColor() : firstAppUsage.color,
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

    _periodicTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      List<AppUsage> usages = await getUsages();
      for (AppUsage usage in usages) {
        AppUsage? appUsage = await _appUsageRepository.getByDateAndHour(
          name: usage.name,
          year: DateTime.now().toUtc().year,
          month: DateTime.now().toUtc().month,
          day: DateTime.now().toUtc().day,
          hour: DateTime.now().toUtc().hour,
        );

        if (appUsage != null) {
          appUsage.duration = usage.duration;
          await _appUsageRepository.update(appUsage);
        } else {
          await _appUsageRepository.add(usage);
        }
      }
    });
  }

  @override
  void stopTracking() {
    _intervalTimer?.cancel();
    _periodicTimer?.cancel();
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

  static const androidPlatformChannel = MethodChannel('com.example.whph/app_info');
  Future<List<AppUsage>> getUsages() async {
    if (Platform.isAndroid) {
      DateTime endDate = DateTime.now();
      DateTime startDate = DateTime(endDate.year, endDate.month, endDate.day, endDate.hour);

      bool? isPermissionGranted = await UsageStats.checkUsagePermission();
      if (isPermissionGranted == false) {
        UsageStats.grantUsagePermission();
        return [];
      }

      List<UsageInfo> usageStats = (await UsageStats.queryUsageStats(startDate, endDate)).where((element) {
        final foregroundTime = int.tryParse(element.totalTimeInForeground ?? '0');
        return foregroundTime != null && foregroundTime > 0;
      }).toList()
        ..sort((a, b) => (b.lastTimeUsed != null ? int.parse(b.lastTimeUsed!) : 0)
            .compareTo(a.lastTimeUsed != null ? int.parse(a.lastTimeUsed!) : 0));

      if (usageStats.isEmpty) return [];

      List<AppUsage> appUsages = [];
      for (UsageInfo usage in usageStats) {
        String packageName = usage.packageName!;

        String? appName;
        try {
          appName = await androidPlatformChannel.invokeMethod('getAppName', {'packageName': packageName});
        } catch (e) {
          continue;
        }

        if (kDebugMode) print('appName: $appName, packageName: $packageName');

        appUsages.add(AppUsage(
          id: nanoid(),
          name: appName ?? 'Unknown',
          duration: int.parse(usage.totalTimeInForeground ?? '0') ~/ 1000,
          color: _getRandomColor(),
          createdDate: DateTime.now(),
        ));
      }

      return appUsages;
    }

    return [];
  }

  String _getRandomColor() {
    List<Color> colors = [
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
    return colors[Random().nextInt(colors.length)].value.toRadixString(16).substring(2);
  }
}
