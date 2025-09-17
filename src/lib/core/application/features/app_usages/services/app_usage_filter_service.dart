import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:whph/core/application/features/app_usages/constants/system_app_exclusions.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_filter_service.dart';
import 'package:whph/core/application/features/app_usages/services/abstraction/i_app_usage_ignore_rule_repository.dart';
import 'package:whph/core/shared/utils/logger.dart';

class AppUsageFilterService implements IAppUsageFilterService {
  final IAppUsageIgnoreRuleRepository _appUsageIgnoreRuleRepository;

  AppUsageFilterService(
    this._appUsageIgnoreRuleRepository,
  );

  @override
  Future<bool> shouldExcludeApp(String appName) async {
    if (appName.isEmpty) return true;

    if (await _shouldIgnoreByUserRules(appName)) return true;

    return isSystemApp(appName);
  }

  @override
  bool isSystemApp(String appName) {
    if (appName.isEmpty) return true;

    final exclusionList = getSystemAppExclusions();
    return SystemAppExclusions.isSystemApp(appName, exclusionList);
  }

  @override
  List<String> getSystemAppExclusions() {
    if (kIsWeb) {
      return []; // No system apps to filter on web
    }

    if (Platform.isAndroid) {
      return SystemAppExclusions.android;
    } else if (Platform.isWindows) {
      return SystemAppExclusions.windows;
    } else if (Platform.isLinux) {
      return SystemAppExclusions.linux;
    }

    return [];
  }

  /// Checks if app should be ignored based on user-defined rules
  Future<bool> _shouldIgnoreByUserRules(String appName) async {
    try {
      final rules = await _appUsageIgnoreRuleRepository.getAll();

      for (final rule in rules) {
        try {
          if (RegExp(rule.pattern).hasMatch(appName)) {
            return true;
          }
        } catch (e) {
          Logger.error('Invalid ignore pattern in rule ${rule.id}: ${e.toString()}');
        }
      }

      return false;
    } catch (e) {
      Logger.error('Error checking user ignore rules: $e');
      return false;
    }
  }
}
