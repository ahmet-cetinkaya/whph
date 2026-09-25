import 'package:flutter/foundation.dart';
import 'package:whph/core/application/shared/services/abstraction/i_application_transaction_service.dart';

abstract class IAppUsageService {
  Future<void> startTracking({ApplicationMutationGuard? authorizeCommit});
  Future<void> stopTracking();
  Future<void> saveTimeRecord(String appName, int duration, {bool overwrite = false, DateTime? customDateTime});
  Future<bool> checkUsageStatsPermission();
  Future<void> requestUsageStatsPermission();

  ValueNotifier<bool> get isTrackingActiveWindowWorking;
}

final class AppUsagePermissionRequiredException implements Exception {
  const AppUsagePermissionRequiredException();
}
