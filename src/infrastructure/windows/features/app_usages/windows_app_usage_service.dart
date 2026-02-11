import 'package:flutter/services.dart';
import 'package:whph/infrastructure/desktop/features/app_usages/abstractions/base_desktop_app_usage_service.dart';
import 'package:whph/core/domain/shared/utils/logger.dart';
import 'package:whph/infrastructure/windows/constants/windows_app_constants.dart';

class WindowsAppUsageService extends BaseDesktopAppUsageService {
  static final MethodChannel _channel = MethodChannel(WindowsAppConstants.channels.appUsage);

  WindowsAppUsageService(
    super.appUsageRepository,
    super.appUsageTimeRecordRepository,
    super.appUsageTagRuleRepository,
    super.appUsageTagRepository,
    super.appUsageFilterService,
  );

  @override
  Future<String?> getActiveWindow() async {
    try {
      // Use native method channel instead of PowerShell script
      final String? result = await _channel.invokeMethod('getActiveWindow');
      return result;
    } on PlatformException catch (e) {
      DomainLogger.error('Platform error: ${e.message}');
      return null;
    } catch (e) {
      DomainLogger.error('Error getting active window: $e');
      return null;
    }
  }
}
