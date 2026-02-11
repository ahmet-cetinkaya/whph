import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';
import 'package:acore/acore.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_tag.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_time_record_repository.dart';
import 'package:whph/core/domain/shared/constants/app_theme.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'i_app_usage_service.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_rule_repository.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_tag_repository.dart';
import 'package:whph/presentation/ui/shared/utils/device_info_helper.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_filter_service.dart';

abstract class BaseAppUsageService implements IAppUsageService {
  @protected
  Timer? periodicTimer;

  final IAppUsageRepository _appUsageRepository;
  final IAppUsageTimeRecordRepository _appUsageTimeRecordRepository;
  final IAppUsageTagRuleRepository _appUsageTagRuleRepository;
  final IAppUsageTagRepository _appUsageTagRepository;
  final IAppUsageFilterService _appUsageFilterService;

  // Protected getter for subclasses
  @protected
  IAppUsageTimeRecordRepository get appUsageTimeRecordRepository => _appUsageTimeRecordRepository;

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
    this._appUsageFilterService,
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

  @override
  @protected
  Future<void> saveTimeRecord(String appName, int duration, {bool overwrite = false, DateTime? customDateTime}) async {
    final bool shouldExcludeApp = await _appUsageFilterService.shouldExcludeApp(appName);
    if (shouldExcludeApp) return;

    final recordDateTime = customDateTime ?? DateTime.now().toUtc();
    final appUsage = await _getOrCreateAppUsage(appName, createdDate: recordDateTime);
    await _applyTagRules(appUsage);

    final recordHourStart =
        DateTime(recordDateTime.year, recordDateTime.month, recordDateTime.day, recordDateTime.hour);
    final recordHourEnd = recordHourStart.add(const Duration(hours: 1));

    AppUsageTimeRecord? timeRecord = await _appUsageTimeRecordRepository.getFirst(
      CustomWhereFilter(
        'app_usage_id = ? AND usage_date >= ? AND usage_date < ? AND deleted_date IS NULL',
        [appUsage.id, recordHourStart, recordHourEnd],
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
        usageDate: recordHourStart,
        createdDate: DateTime.now().toUtc(),
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
        Logger.error('Invalid pattern in rule ${rule.id}: ${e.toString()}');
      }
    }
  }

  Future<AppUsage> _getOrCreateAppUsage(String appName, {DateTime? createdDate}) async {
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
        createdDate: DateTimeHelper.toUtcDateTime(createdDate ?? DateTime.now()),
      );
      await _appUsageRepository.add(appUsage);
    }

    return appUsage;
  }
}
