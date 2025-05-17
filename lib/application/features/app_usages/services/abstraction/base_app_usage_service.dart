import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:whph/application/shared/utils/key_helper.dart';
import 'package:whph/core/acore/repository/models/custom_where_filter.dart';
import 'package:whph/domain/features/app_usages/app_usage.dart';
import 'package:whph/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/domain/shared/constants/app_theme.dart';
import 'i_app_usage_service.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/presentation/shared/utils/device_info_helper.dart';
import 'package:whph/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';

abstract class BaseAppUsageService implements IAppUsageService {
  @protected
  Timer? periodicTimer;

  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;
  final IAppUsageTagRuleRepository _appUsageTagRuleRepository;
  final IAppUsageTagRepository _appUsageTagRepository;
  final IAppUsageIgnoreRuleRepository _appUsageIgnoreRuleRepository;

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

  BaseAppUsageService(
    this._appUsageRepository,
    this._appUsageTimeRecordRepository,
    this._appUsageTagRuleRepository,
    this._appUsageTagRepository,
    this._appUsageIgnoreRuleRepository,
  );

  @override
  Future<void> startTracking();

  @override
  Future<void> stopTracking() async {
    periodicTimer?.cancel();
  }

  @override
  Future<bool> checkUsageStatsPermission() async {
    // Permission is assumed to be granted by default, platform-specific implementations can override
    return true;
  }

  @override
  Future<void> requestUsageStatsPermission() async {
    // Does nothing by default, platform-specific implementations can override
  }

  Future<bool> _shouldIgnoreApp(String appName) async {
    final rules = await _appUsageIgnoreRuleRepository.getAll();

    for (final rule in rules) {
      try {
        if (RegExp(rule.pattern).hasMatch(appName)) {
          return true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Invalid ignore pattern in rule ${rule.id}: ${e.toString()}');
      }
    }

    return false;
  }

  @override
  @protected
  Future<void> saveTimeRecord(String appName, int duration, {bool overwrite = false}) async {
    if (await _shouldIgnoreApp(appName)) return;

    final appUsage = await _getOrCreateAppUsage(appName);
    await _applyTagRules(appUsage);

    final now = DateTime.now();
    final nowHourStart = DateTime(now.year, now.month, now.day, now.hour);
    AppUsageTimeRecord? timeRecord = await _appUsageTimeRecordRepository.getFirst(
      CustomWhereFilter(
        'app_usage_id = ? AND created_date >= ? AND created_date < ? AND deleted_date IS NULL',
        [appUsage.id, nowHourStart, now],
      ),
    );

    if (timeRecord != null) {
      timeRecord.duration = overwrite ? duration : timeRecord.duration + duration;
      await _appUsageTimeRecordRepository.update(timeRecord);
    } else {
      final newRecord = AppUsageTimeRecord(
        id: KeyHelper.generateStringId(),
        appUsageId: appUsage.id,
        duration: duration,
        createdDate: now,
      );
      await _appUsageTimeRecordRepository.add(newRecord);
    }
  }

  Future<void> _applyTagRules(AppUsage appUsage) async {
    // Get all active rules
    final rules = await _appUsageTagRuleRepository.getAll();

    for (final rule in rules) {
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
              id: KeyHelper.generateStringId(),
              createdDate: DateTime.now().toUtc(),
              appUsageId: appUsage.id,
              tagId: rule.tagId,
            );
            await _appUsageTagRepository.add(appUsageTag);
          }
        }
      } catch (e) {
        // Log or handle invalid regex patterns
        if (kDebugMode) debugPrint('Invalid pattern in rule ${rule.id}: ${e.toString()}');
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
      // Get device name from platform info or settings
      final deviceName = await DeviceInfoHelper.getDeviceName();

      appUsage = AppUsage(
        id: KeyHelper.generateStringId(),
        name: appName,
        color: _chartColors[Random().nextInt(_chartColors.length)].toHexString(),
        deviceName: deviceName,
        createdDate: DateTime.now().toUtc(),
      );
      await _appUsageRepository.add(appUsage);
    }

    return appUsage;
  }
}
