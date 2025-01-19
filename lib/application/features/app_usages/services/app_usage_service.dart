import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/domain/features/shared/constants/app_theme.dart';
import 'abstraction/i_app_usage_service.dart';
import 'package:app_usage/app_usage.dart' as app_usage_package;

class AppUsageService implements IAppUsageService {
  String _activeDesktopWindowOutput = '';
  int _activeDesktopWindowTime = 0;
  Timer? _intervalTimer;
  Timer? _periodicTimer;

  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTimeRecordRepository _timeRecordRepository;

  AppUsageService(this._appUsageRepository, this._timeRecordRepository);

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

          await saveTimeRecord(appName, _activeDesktopWindowTime);
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
        DateTime startDate = endDate.subtract(const Duration(hours: 1));
        List<app_usage_package.AppUsageInfo> usageStats =
            await app_usage_package.AppUsage().getAppUsage(startDate, endDate);

        if (usageStats.isEmpty) return;

        for (app_usage_package.AppUsageInfo usage in usageStats) {
          await saveTimeRecord(usage.appName, usage.usage.inSeconds, overwrite: true);
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

  @override
  Future<void> saveTimeRecord(String appName, int duration, {bool overwrite = false}) async {
    // First, get or create AppUsage
    var appUsage = await _getOrCreateAppUsage(appName);

    // Then, get or create AppUsageTimeRecord
    var now = DateTime.now().toUtc();
    final recordStartTime = DateTime(now.year, now.month, now.day, now.hour);

    var timeRecords = await _timeRecordRepository.getAll(
      customWhereFilter: CustomWhereFilter(
        'app_usage_id = ? AND created_date = ? AND deleted_date IS NULL',
        [appUsage.id, recordStartTime],
      ),
    );

    if (timeRecords.isNotEmpty) {
      var existingRecord = timeRecords.first;
      if (overwrite) {
        existingRecord = AppUsageTimeRecord(
          id: existingRecord.id,
          appUsageId: existingRecord.appUsageId,
          duration: duration,
          createdDate: existingRecord.createdDate,
          modifiedDate: DateTime.now().toUtc(),
        );
      } else {
        existingRecord = AppUsageTimeRecord(
          id: existingRecord.id,
          appUsageId: existingRecord.appUsageId,
          duration: existingRecord.duration + duration,
          createdDate: existingRecord.createdDate,
          modifiedDate: DateTime.now().toUtc(),
        );
      }
      await _timeRecordRepository.update(existingRecord);
    } else {
      var newRecord = AppUsageTimeRecord(
        id: nanoid(),
        appUsageId: appUsage.id,
        duration: duration,
        createdDate: recordStartTime,
      );
      await _timeRecordRepository.add(newRecord);
    }
  }

  Future<AppUsage> _getOrCreateAppUsage(String appName) async {
    var appUsage = await _appUsageRepository.getFirst(
      CustomWhereFilter(
        'name = ? AND deleted_date IS NULL',
        [appName],
      ),
    );

    if (appUsage == null) {
      appUsage = AppUsage(
        id: nanoid(),
        name: appName,
        color: _chartColors[Random().nextInt(_chartColors.length)].toHexString(),
        createdDate: DateTime.now().toUtc(),
      );
      await _appUsageRepository.add(appUsage);
    }

    return appUsage;
  }

  @override
  void stopTracking() {
    _intervalTimer?.cancel();
    _periodicTimer?.cancel();
  }
}
