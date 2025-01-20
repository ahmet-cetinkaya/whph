import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/domain/shared/constants/app_theme.dart';
import 'abstraction/i_app_usage_service.dart';
import 'package:app_usage/app_usage.dart' as app_usage_package;
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';

class AppUsageService implements IAppUsageService {
  String _activeDesktopWindowOutput = '';
  int _activeDesktopWindowTime = 0;
  Timer? _intervalTimer;
  Timer? _periodicTimer;

  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;
  final IAppUsageTagRuleRepository _appUsageTagRuleRepository;
  final IAppUsageTagRepository _appUsageTagRepository;

  AppUsageService(
    this._appUsageRepository,
    this._appUsageTimeRecordRepository,
    this._appUsageTagRuleRepository,
    this._appUsageTagRepository,
  );

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
            print('DEBUG: $_activeDesktopWindowOutput: $_activeDesktopWindowTime seconds');
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

    // Check and apply tag rules
    await _applyTagRules(appUsage);

    // Then, get or create AppUsageTimeRecord
    var now = DateTime.now().toUtc();
    final recordStartTime = DateTime(now.year, now.month, now.day, now.hour);

    var timeRecords = await _appUsageTimeRecordRepository.getAll(
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
      await _appUsageTimeRecordRepository.update(existingRecord);
    } else {
      var newRecord = AppUsageTimeRecord(
        id: nanoid(),
        appUsageId: appUsage.id,
        duration: duration,
        createdDate: recordStartTime,
      );
      await _appUsageTimeRecordRepository.add(newRecord);
    }
  }

  Future<void> _applyTagRules(AppUsage appUsage) async {
    // Get all active rules
    final rules = await _appUsageTagRuleRepository.getAll(
      customWhereFilter: CustomWhereFilter('is_active = ?', [1]),
    );

    for (var rule in rules) {
      try {
        // Check if pattern matches
        final pattern = RegExp(rule.pattern);
        if (pattern.hasMatch(appUsage.displayName ?? appUsage.name)) {
          // Check if tag already exists
          final existingTag = await _appUsageTagRepository.getFirst(
            CustomWhereFilter(
              'app_usage_id = ? AND tag_id = ? AND deleted_date IS NULL',
              [appUsage.id, rule.tagId],
            ),
          );

          // Add tag if it doesn't exist
          if (existingTag == null) {
            final appUsageTag = AppUsageTag(
              id: nanoid(),
              createdDate: DateTime.now(),
              appUsageId: appUsage.id,
              tagId: rule.tagId,
            );
            await _appUsageTagRepository.add(appUsageTag);

            if (kDebugMode) {
              print('DEBUG: Tagged ${appUsage.name} with ${rule.tagId} with rule ${rule.id}');
            }
          }
        }
      } catch (e) {
        // Log or handle invalid regex patterns
        if (kDebugMode) {
          print('Invalid pattern in rule ${rule.id}: ${e.toString()}');
        }
      }
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
